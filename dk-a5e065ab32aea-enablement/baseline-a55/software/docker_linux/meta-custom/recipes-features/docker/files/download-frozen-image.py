#!/usr/bin/env python3
"""Download Docker/OCI images for docker load (Docker Hub + GCR).

Python port of download-frozen-image-v2.sh — uses stdlib only (no jq/curl).
"""

import base64
import hashlib
import json
import os
import platform
import sys
import urllib.error
import urllib.parse
import urllib.request

MANIFEST_ACCEPT = ",".join([
    "application/vnd.oci.image.manifest.v1+json",
    "application/vnd.oci.image.index.v1+json",
    "application/vnd.docker.distribution.manifest.v2+json",
    "application/vnd.docker.distribution.manifest.list.v2+json",
    "application/vnd.docker.distribution.manifest.v1+json",
])

LAYER_MEDIA_TYPES = {
    "application/vnd.oci.image.layer.v1.tar+gzip",
    "application/vnd.docker.image.rootfs.diff.tar.gzip",
}

LAYER_JSON_STUB = {
    "created": "0001-01-01T00:00:00Z",
    "container_config": {
        "Hostname": "",
        "Domainname": "",
        "User": "",
        "AttachStdin": False,
        "AttachStdout": False,
        "AttachStderr": False,
        "Tty": False,
        "OpenStdin": False,
        "StdinOnce": False,
        "Env": None,
        "Cmd": None,
        "Image": "",
        "Volumes": None,
        "WorkingDir": "",
        "Entrypoint": None,
        "OnBuild": None,
        "Labels": None,
    },
}

def registry_credentials():
    user = (
        os.environ.get("DOCKER_USERNAME", "").strip()
        or os.environ.get("REGISTRY_USERNAME", "").strip()
    )
    password = (
        os.environ.get("DOCKER_PASSWORD", "").strip()
        or os.environ.get("REGISTRY_PASSWORD", "").strip()
    )
    if user:
        print("Docker Hub / Registry username provided")
    else:
        print("No Docker Hub / Registry username")
    if password:
        print("Docker Hub / Registry password provided")
    else:
        print("No Docker Hub / Registry password")

    return user, password


def parse_www_authenticate(header):
    if not header:
        return {}
    value = header.strip()
    if value.lower().startswith("bearer "):
        value = value[7:].strip()
    params = {}
    for part in value.split(","):
        key, _, raw = part.strip().partition("=")
        params[key.lower()] = raw.strip().strip('"')
    return params


class RegistryClient:
    def __init__(self, registry_host):
        self.registry_host = registry_host
        self.registry_base = "https://%s" % registry_host
        self._tokens = {}

    def is_supported(self):
        if self.registry_host in ("registry-1.docker.io", "index.docker.io", "docker.io"):
            return True
        return self.registry_host == "gcr.io" or self.registry_host.endswith(".gcr.io")

    def default_token_url(self, repository):
        scope = urllib.parse.quote("repository:%s:pull" % repository, safe="")
        if self.registry_host in ("registry-1.docker.io", "index.docker.io", "docker.io"):
            return "https://auth.docker.io/token?service=registry.docker.io&scope=%s" % scope
        if self.registry_host == "gcr.io" or self.registry_host.endswith(".gcr.io"):
            return "%s/v2/token?scope=%s" % (self.registry_base, scope)
        return None

    def token_url_from_challenge(self, repository, www_authenticate):
        params = parse_www_authenticate(www_authenticate)
        realm = params.get("realm")
        if not realm:
            return self.default_token_url(repository)
        query = {}
        if params.get("service"):
            query["service"] = params["service"]
        scope = params.get("scope") or ("repository:%s:pull" % repository)
        query["scope"] = scope
        return "%s?%s" % (realm, urllib.parse.urlencode(query))

    def _fetch_token(self, url):
        user, password = registry_credentials()
        headers = {}
        if user and password:
            creds = ("%s:%s" % (user, password)).encode("utf-8")
            headers["Authorization"] = "Basic %s" % (
                base64.b64encode(creds).decode("ascii")
            )
        request = urllib.request.Request(url, headers=headers)
        try:
            with urllib.request.urlopen(request, timeout=60) as resp:
                data = json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            body = ""
            try:
                body = exc.read().decode("utf-8", errors="replace")[:500]
            except Exception:
                pass
            raise RuntimeError(
                "token fetch failed (%s %s) from %s: %s"
                % (exc.code, exc.reason, url, body or exc)
            ) from exc
        except urllib.error.URLError as exc:
            raise RuntimeError("token fetch failed from %s: %s" % (url, exc)) from exc

        token = data.get("token") or data.get("access_token") or ""
        if not token:
            raise RuntimeError("token endpoint returned no token: %s" % url)
        return token

    def ensure_token(self, repository, www_authenticate=None):
        cached = self._tokens.get(repository)
        if cached:
            return cached
        url = (
            self.token_url_from_challenge(repository, www_authenticate)
            if www_authenticate
            else self.default_token_url(repository)
        )
        if not url:
            return ""
        token = self._fetch_token(url)
        self._tokens[repository] = token
        return token

    def refresh_token(self, repository, www_authenticate=None):
        self._tokens.pop(repository, None)
        return self.ensure_token(repository, www_authenticate)

    def _request(self, url, token=None, headers=None, timeout=120):
        req_headers = dict(headers or {})
        if token:
            req_headers["Authorization"] = "Bearer %s" % token
        request = urllib.request.Request(url, headers=req_headers)
        return urllib.request.urlopen(request, timeout=timeout)

    def fetch_json(self, repository, url, headers=None):
        token = self.ensure_token(repository)
        req_headers = {"Accept": MANIFEST_ACCEPT}
        if headers:
            req_headers.update(headers)
        for attempt in range(2):
            try:
                with self._request(url, token=token, headers=req_headers) as resp:
                    return json.loads(resp.read().decode("utf-8"))
            except urllib.error.HTTPError as exc:
                if exc.code == 401 and attempt == 0:
                    www_auth = exc.headers.get("WWW-Authenticate")
                    token = self.refresh_token(repository, www_auth)
                    continue
                body = ""
                try:
                    body = exc.read().decode("utf-8", errors="replace")[:500]
                except Exception:
                    pass
                raise RuntimeError(
                    "registry request failed (%s %s) for %s: %s"
                    % (exc.code, exc.reason, url, body or exc)
                ) from exc

    def fetch_bytes(self, repository, url):
        token = self.ensure_token(repository)
        for attempt in range(2):
            try:
                with self._request(url, token=token, timeout=300) as resp:
                    return resp.read()
            except urllib.error.HTTPError as exc:
                if exc.code == 401 and attempt == 0:
                    www_auth = exc.headers.get("WWW-Authenticate")
                    token = self.refresh_token(repository, www_auth)
                    continue
                body = ""
                try:
                    body = exc.read().decode("utf-8", errors="replace")[:500]
                except Exception:
                    pass
                raise RuntimeError(
                    "blob download failed (%s %s) for %s: %s"
                    % (exc.code, exc.reason, url, body or exc)
                ) from exc

    def get_manifest(self, repository, ref):
        url = "%s/v2/%s/manifests/%s" % (self.registry_base, repository, ref)
        return self.fetch_json(repository, url)

    def download_blob(self, repository, digest, dest):
        url = "%s/v2/%s/blobs/%s" % (self.registry_base, repository, digest)
        data = self.fetch_bytes(repository, url)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "wb") as fh:
            fh.write(data)


def parse_image_reference(image):
    registry_host = "registry-1.docker.io"
    repository = image
    tag = "latest"
    manifest_ref = "latest"

    if repository.startswith("docker://"):
        repository = repository[9:]
    if repository.startswith("docker.io/"):
        repository = repository[len("docker.io/"):]

    if "/" in repository:
        first = repository.split("/")[0]
        if "." in first or ":" in first or first == "localhost":
            registry_host = first
            repository = repository[len(first) + 1:]

    if "/" not in repository and registry_host == "registry-1.docker.io":
        repository = "library/" + repository

    if "@" in repository:
        manifest_ref = repository.rsplit("@", 1)[1]
        repository = repository.rsplit("@", 1)[0]

    if ":" in repository:
        tag = repository.rsplit(":", 1)[1]
        repository = repository.rsplit(":", 1)[0]
        if manifest_ref == "latest" and "@" not in image:
            manifest_ref = tag

    if registry_host == "registry-1.docker.io":
        repo_tag = "%s:%s" % (repository.replace("library/", "", 1), tag)
    else:
        repo_tag = "%s/%s:%s" % (registry_host, repository, tag)

    return registry_host, repository, tag, manifest_ref, repo_tag


def target_arch():
    arch = os.environ.get("TARGETARCH", "").strip()
    if arch:
        return arch
    machine = platform.machine().lower()
    mapping = {
        "x86_64": "amd64",
        "amd64": "amd64",
        "aarch64": "arm64",
        "arm64": "arm64",
        "armv7l": "arm",
        "armv6l": "arm",
    }
    return mapping.get(machine, machine or "amd64")


def target_variant():
    return os.environ.get("TARGETVARIANT", "").strip()


def fake_layer_id(parent_id, digest):
    payload = (parent_id + "\n" + digest).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def repositories_image_name(registry_host, repository):
    if registry_host == "registry-1.docker.io":
        return repository.replace("library/", "", 1)
    return "%s/%s" % (registry_host, repository)


class ImageDownloader:
    def __init__(self, outdir, target_arch_value, target_variant_value=""):
        self.outdir = outdir
        self.target_arch_value = target_arch_value
        self.target_variant_value = target_variant_value
        self.repositories = {}
        self.manifest_entries = []
        self.skip_manifest_json = False

    def handle_manifest_v2(self, client, repository, repo_tag, image_id, manifest):
        config_digest = manifest["config"]["digest"]
        config_id = config_digest.split(":", 1)[1]
        config_file = "%s.json" % config_id
        client.download_blob(
            repository, config_digest,
            os.path.join(self.outdir, config_file)
        )

        layer_files = []
        layer_id = ""
        print("Downloading '%s' (%d layers) from %s..." % (
            repo_tag, len(manifest.get("layers", [])), client.registry_host))

        for layer in manifest.get("layers", []):
            media_type = layer.get("mediaType", "")
            digest = layer["digest"]
            if media_type not in LAYER_MEDIA_TYPES:
                raise RuntimeError("unsupported layer mediaType %s for %s" % (media_type, repo_tag))

            parent_id = layer_id
            layer_id = fake_layer_id(parent_id, digest)
            layer_dir = os.path.join(self.outdir, layer_id)
            os.makedirs(layer_dir, exist_ok=True)

            version_path = os.path.join(layer_dir, "VERSION")
            if not os.path.isfile(version_path):
                with open(version_path, "w", encoding="utf-8") as fh:
                    fh.write("1.0\n")

            json_path = os.path.join(layer_dir, "json")
            if not os.path.isfile(json_path) or os.path.getsize(json_path) == 0:
                stub = dict(LAYER_JSON_STUB)
                stub["id"] = layer_id
                if parent_id:
                    stub["parent"] = parent_id
                with open(json_path, "w", encoding="utf-8") as fh:
                    json.dump(stub, fh)

            layer_tar = os.path.join(layer_dir, "layer.tar")
            rel_layer = "%s/layer.tar" % layer_id
            layer_files.append(rel_layer)
            if os.path.isfile(layer_tar):
                print("skipping existing %s" % layer_id[:12])
                continue
            client.download_blob(repository, digest, layer_tar)

        image_id = layer_id
        with open(os.path.join(self.outdir, config_file), encoding="utf-8") as fh:
            config_data = json.load(fh)
        with open(os.path.join(self.outdir, image_id, "json"), encoding="utf-8") as fh:
            layer_json = json.load(fh)

        merged = {}
        merged.update({k: layer_json[k] for k in ("id", "parent") if k in layer_json})
        for key, value in config_data.items():
            if key not in ("history", "rootfs"):
                merged[key] = value
        with open(os.path.join(self.outdir, image_id, "json"), "w", encoding="utf-8") as fh:
            json.dump(merged, fh)

        self.manifest_entries.append({
            "Config": config_file,
            "RepoTags": [repo_tag],
            "Layers": layer_files,
        })
        return image_id

    def handle_schema_v1(self, client, repository, repo_tag, manifest):
        self.skip_manifest_json = True
        layers = [x["blobSum"] for x in manifest.get("fsLayers", [])]
        history = [json.loads(x["v1Compatibility"]) for x in manifest.get("history", [])]
        image_id = history[0]["id"] if history else ""
        print("Downloading '%s' (%d layers) from %s..." % (repo_tag, len(layers), client.registry_host))

        for idx, blob in enumerate(layers):
            image_json = history[idx]
            layer_id = image_json["id"]
            layer_dir = os.path.join(self.outdir, layer_id)
            os.makedirs(layer_dir, exist_ok=True)
            with open(os.path.join(layer_dir, "VERSION"), "w", encoding="utf-8") as fh:
                fh.write("1.0\n")
            with open(os.path.join(layer_dir, "json"), "w", encoding="utf-8") as fh:
                json.dump(image_json, fh)
            layer_tar = os.path.join(layer_dir, "layer.tar")
            if os.path.isfile(layer_tar):
                print("skipping existing %s" % layer_id[:12])
                continue
            client.download_blob(repository, blob, layer_tar)
        return image_id

    def download_image(self, image_ref):
        print("download_image: %s" % (image_ref))
        registry_host, repository, tag, manifest_ref, repo_tag = parse_image_reference(image_ref)
        print("registry-host: %s  repo: %s  tag: %s manifest_ref: %s  repo_tag: %s" % (registry_host, repository, tag, manifest_ref, repo_tag))
        client = RegistryClient(registry_host)
        if not client.is_supported():
            raise RuntimeError("unsupported registry '%s' (supported: Docker Hub, GCR)" % registry_host)

        manifest = client.get_manifest(repository, manifest_ref)
        schema = manifest.get("schemaVersion")
        image_id = ""

        if schema == 2:
            media_type = manifest.get("mediaType", "")
            if media_type in (
                "application/vnd.oci.image.manifest.v1+json",
                "application/vnd.docker.distribution.manifest.v2+json",
            ):
                image_id = self.handle_manifest_v2(
                    client, repository, repo_tag, image_id, manifest)
            elif media_type in (
                "application/vnd.oci.image.index.v1+json",
                "application/vnd.docker.distribution.manifest.list.v2+json",
            ):
                found = False
                for entry in manifest.get("manifests", []):
                    plat = entry.get("platform") or {}
                    mani_arch = plat.get("architecture", "")
                    mani_variant = plat.get("variant", "")
                    if mani_arch != self.target_arch_value:
                        continue
                    if self.target_variant_value and mani_variant != self.target_variant_value:
                        continue
                    sub = client.get_manifest(repository, entry["digest"])
                    image_id = self.handle_manifest_v2(
                        client, repository, repo_tag, image_id, sub)
                    found = True
                    break
                if not found:
                    raise RuntimeError(
                        "manifest for %s%s not found in %s"
                        % (self.target_arch_value,
                           "/" + self.target_variant_value if self.target_variant_value else "",
                           repo_tag)
                    )
            else:
                raise RuntimeError("unknown manifest mediaType for %s: %s" % (repo_tag, media_type))
        elif schema == 1:
            image_id = self.handle_schema_v1(client, repository, repo_tag, manifest)
        else:
            raise RuntimeError("unknown schemaVersion for %s: %s" % (repo_tag, schema))

        repo_name = repositories_image_name(registry_host, repository)
        tags = self.repositories.setdefault(repo_name, {})
        tags[tag] = image_id
        print()

    def finalize(self):
        with open(os.path.join(self.outdir, "repositories"), "w", encoding="utf-8") as fh:
            json.dump(self.repositories, fh, indent=2)
            fh.write("\n")

        if not self.skip_manifest_json and self.manifest_entries:
            with open(os.path.join(self.outdir, "manifest.json"), "w", encoding="utf-8") as fh:
                json.dump(self.manifest_entries, fh, indent=2)
                fh.write("\n")
        elif os.path.isfile(os.path.join(self.outdir, "manifest.json")):
            os.remove(os.path.join(self.outdir, "manifest.json"))


def main(argv=None):
    argv = argv if argv is not None else sys.argv[1:]
    if len(argv) < 2:
        print("usage: %s dir image[:tag] [image...]" % sys.argv[0], file=sys.stderr)
        print("       %s /tmp/images alpine:3.19" % sys.argv[0], file=sys.stderr)
        return 1

    print("%s: called with args: %s" % (sys.argv[0], " ".join(argv)))
    outdir = argv[0]
    images = argv[1:]
    os.makedirs(outdir, exist_ok=True)

    dl = ImageDownloader(outdir, target_arch(), target_variant())
    failures = 0
    for image in images:
        try:
            dl.download_image(image)
        except Exception as exc:
            failures += 1
            print("WARN: Failed to get Docker Image: %s -- exc: %s reason: %s" % (image, type(exc).__name__, str(exc)))

    if (failures >= len(images)):
        print("WARN: No Docker Image was downloaded or locally obtained")
        return 1
    else:
        dl.finalize()

    print("Download of images into '%s' complete.  Failures: %d" % (outdir, failures))
    print("Use: tar -cC '%s' . | docker load" % outdir)
    # We return 0, as long as some images were fetched, requiring us to write the boot script
    return 0


if __name__ == "__main__":
    sys.exit(main())
