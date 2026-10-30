SUMMARY = "Place Docker images in RFS and generate first-boot launch script"
DESCRIPTION = "Downloads target-arch (currently fixed to AArch64) images for the RFS and generates a first-boot script to launch Docker containers at boot. Docker Hub and GCR images are supported. AWS and others have a complex Token handshake. The build host does not require the docker CLI; images are fetched with python3 and a derived rewrite of download-frozen-image script from Docker.io"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SRC_URI = " \
        file://download-frozen-image.py \
        file://expand-root-partition \
"

RDEPENDS:${PN} = "docker bash coreutils"

# Build host: python3 runs download-frozen-image.py (stdlib json/urllib only)
DOCKER_DOWNLOAD_SCRIPT ??= "${UNPACKDIR}/download-frozen-image.py"
DOCKER_DOWNLOAD_PYTHON ??= "python3"
DOCKER_TARGET_ARCH ??= "arm64"

# Injected from docker_enable.yml, (if set there)
DOCKER_STATE_START_DAEMON ??= "1"
# Default: single hello-world. Multi-image example (up to 4): kas/virtualization/docker-images*.cfg*
DOCKER_LIST_IMAGES ??= "docker.io/library/hello-world:latest"
DOCKER_LIST_RUN_ARGS ??= "--name=hello|no"
# The following 2 lines are an example of how to pack upto 4 DOCKER images into the Root-Filesystem:
##DOCKER_LIST_IMAGES ??= "docker.io/library/alpine:3.19,docker.io/library/busybox:1.36,docker.io/library/hello-world:latest,file:///tmp/example-image.tar"
##DOCKER_LIST_RUN_ARGS ??= "--name=alpine --network=host --restart=unless-stopped alpine:3.19#sleep infinity|yes,--name=busyhttp -d -v /www/pages:/www -p 8084:80 --restart=unless-stopped busybox:1.36#httpd -f -p 80 -h /www|yes,--name=hello|no,--name=localapp -v /data:/data myapp:latest|no"

# Optional build-host override (if file exists, replaces kconfig fragment values)
DOCKER_IMAGES_OVERRIDE_FILE ??= "/tmp/docker-images-override.cfg"
# Optional Docker or other Registry Credentials in file on build host
DOCKER_CREDENTIALS_FILE ??= "/tmp/docker-credentials"
DOCKER_USERNAME ??= ""
DOCKER_PASSWORD ??= ""
DOCKER_MARKER_DIR ??= "/var/lib/docker"
# Iterations to check if the docker system is now functional. Each iteration is a 2 sec sleep
DOCKER_BOOT_WAIT_ITER ??= "60"
DOCKER_IMAGE_SUBDIR ??= "images"
http_proxy ??= ""
https_proxy ??= ""

S = "${UNPACKDIR}"

SYSTEMD_SERVICE:${PN} = "docker-boot.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"
DOCKER_FIRST_BOOT_SCRIPT = "docker-boot.sh"

DOCKER_SLOT_MAX = "4"
DOCKER_LIBDIR = "${libdir}/docker"
DOCKER_DATADIR = "${datadir}/docker"

def docker_parse_lists (d):
    def split_slots(raw, max_slots):
        parts = [p.strip() for p in (raw or "").split(",")]
        while len(parts) < max_slots:
            parts.append("")
        return parts[:max_slots]

    max_slots = int(d.getVar("DOCKER_SLOT_MAX"))
    images = split_slots(d.getVar("DOCKER_LIST_IMAGES"), max_slots)
    run_args = split_slots(d.getVar("DOCKER_LIST_RUN_ARGS"), max_slots)

    slots = []
    for idx, image in enumerate(images):
        entry = {
            "index": idx,
            "image": image,
            "run_args": "",
            "enabled": "no",
            "tar_name": "image%d.tar" % idx,
        }
        if run_args[idx]:
            if "|" in run_args[idx]:
                args, enabled = run_args[idx].rsplit("|", 1)
                entry["run_args"] = args.strip()
                entry["enabled"] = enabled.strip().lower()
            else:
                entry["run_args"] = run_args[idx].strip()
                entry["enabled"] = "yes"
        slots.append(entry)

    return slots

python do_fetch_images () {
    import os
    import re
    import shutil
    import subprocess

    def docker_local_tar_path (d):
        from urllib.parse import unquote, urlparse

        uri = d.getVar("DOCKER_FILE_URI")
        if not uri.startswith("file://"):
            bb.warn("Not a file:// URI: %s" % uri)
            return None
        path = unquote(urlparse(uri).path)
        # file:///tmp/foo.tar → /tmp/foo.tar
        if len(path) > 2 and path[0] == "/" and path[2] == ":":
            path = path[1:]
        return path

    def docker_read_tar_repo_tag ():
        import json
        import tarfile

        def tar_member(names, basename):
            for name in names:
                if name.lstrip("./") == basename:
                    return name
            return None

        tar_path = d.getVar("DOCKER_TAR_PATH")
        tags = []

        with tarfile.open(tar_path, "r:*") as tf:
            names = tf.getnames()
            manifest = tar_member(names, "manifest.json")
            if manifest:
                raw = tf.extractfile(manifest).read().decode("utf-8")
                for entry in json.loads(raw):
                    for tag in entry.get("RepoTags") or []:
                        if tag:
                            tags.append(tag)
            else:
                repos = tar_member(names, "repositories")
                if repos:
                    raw = tf.extractfile(repos).read().decode("utf-8")
                    for repo, tag_map in json.loads(raw).items():
                        for tag in tag_map:
                            tags.append("%s:%s" % (repo, tag))

        if not tags:
            bb.note("No RepoTags in %s; unable to infer image reference from tarball" % tar_path)
            return ""
        if len(tags) > 1:
            bb.note("Multiple RepoTags in %s, using %s" % (tar_path, tags[0]))
        return tags[0]

    def normalize_ref(image):
        if image.startswith("docker://"):
            return image[9:]
        if image.startswith("file://"):
            return image
        if "://" in image:
            bb.warn(
                "Unsupported image reference '%s'; use Docker Hub, GCR "
                "(e.g. gcr.io/project/image:1.0), or file:///path/image.tar" % image
            )
            return None
        return image

    def is_supported_remote_registry(registry):
        if registry in ("registry-1.docker.io", "index.docker.io", "docker.io"):
            return True
        if registry == "gcr.io" or registry.endswith(".gcr.io"):
            return True
        return False

    def parse_registry_ref(image):
        ref = normalize_ref(image)
        if ref is None:
            return None, None, None
        registry = "registry-1.docker.io"
        repository = ref

        if repository.startswith("docker.io/"):
            repository = repository[len("docker.io/"):]

        if "/" in repository:
            first = repository.split("/")[0]
            if "." in first or ":" in first or first == "localhost":
                registry = first
                repository = repository[len(first) + 1:]

        if "/" not in repository and registry == "registry-1.docker.io":
            repository = "library/" + repository

        tag = "latest"
        if "@" in repository:
            repository, _ = repository.split("@", 1)
        if ":" in repository:
            repository, tag = repository.rsplit(":", 1)

        return registry, repository, tag

    def frozen_image_spec(image):
        registry, repository, tag = parse_registry_ref(image)
        if registry is None:
            return None
        if registry == "registry-1.docker.io":
            return "%s:%s" % (repository, tag)
        return "%s/%s:%s" % (registry, repository, tag)

    def run_image_ref(image):
        registry, repository, tag = parse_registry_ref(image)
        if registry is None:
            return None
        if registry == "registry-1.docker.io":
            return "%s:%s" % (repository.replace("library/", "", 1), tag)
        return "%s/%s:%s" % (registry, repository, tag)

    def load_credentials_from_file(path):
        creds = {}
        if not path or not os.path.isfile(path):
            return creds
        allowed = {
                "DOCKER_USERNAME",
                "DOCKER_PASSWORD",
                "REGISTRY_USERNAME",
                "REGISTRY_PASSWORD",
        }
        with open(path, encoding="utf-8") as fh:
            for lineno, line in enumerate(fh, 1):
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                match = re.match(r'^([A-Z0-9_]+)\s*=\s*(.*)$', line)
                if not match:
                    bb.warn("Ignoring invalid credentials line %d in %s" % (lineno, path))
                    continue
                key, value = match.group(1), match.group(2).strip()
                if key not in allowed:
                    bb.warn("Ignoring unknown credentials key %s in %s" % (key, path))
                    continue
                if len(value) >= 2 and value[0] == value[-1] and value[0] in ('"', "'"):
                    value = value[1:-1]
                creds[key] = value
        return creds

    def build_download_env():
        # the download python script does not have access to bitbake datastore 'd'
        # the script relies on the environment. So we pollute the env by stuffing stuff
        env = os.environ.copy()
        env["TARGETARCH"] = target_arch

        for key in (
                "DOCKER_USERNAME",
                "DOCKER_PASSWORD",
                "REGISTRY_USERNAME",
                "REGISTRY_PASSWORD",
                "http_proxy",
                "https_proxy",
                "DOCKER_LIST_IMAGES",
                ):
            val = d.getVar(key)
            if val:
                env[key] = val

        # We have setup the environment for callee script using what
        # bitbake provided in sanitized Env as well as Orig-Env.
        # Now override key/val, if they exist in Credentials Override file
        cred_path = d.getVar("DOCKER_CREDENTIALS_FILE")
        for key, value in load_credentials_from_file(cred_path).items():
            env[key] = value

        return env

    def require_host_tool(name):
        if not shutil.which(name):
            bb.fatal("%s not found on build host PATH; required by docker-container-support" % name)

    def docker_dl_cache_path(image_spec, target_arch):
        # Stable name under DL_DIR so rebuilds reuse prior registry downloads
        safe = image_spec.replace("/", "_").replace(":", "_").replace("@", "_")
        dl_dir = d.getVar("DL_DIR")
        return os.path.join(dl_dir, "docker-images", "%s_%s.tar" % (safe, target_arch))

    python_bin = d.getVar("DOCKER_DOWNLOAD_PYTHON") or "python3"
    require_host_tool(python_bin)
    require_host_tool("tar")

    script = d.getVar("DOCKER_DOWNLOAD_SCRIPT")
    target_arch = d.getVar("DOCKER_TARGET_ARCH")
    slots = docker_parse_lists(d)
    fetchdir = os.path.join(d.getVar("WORKDIR"), d.getVar("DOCKER_IMAGE_SUBDIR"))
    os.makedirs(fetchdir, exist_ok=True)

    if not os.path.isfile(script):
        bb.fatal("download script not found: %s" % script)

    max_slots = int(d.getVar('DOCKER_SLOT_MAX') or '4')
    run_refs = [""] * max_slots
    fetched_count = 0
    local_count = 0
    cache_count = 0
    registry_count = 0
    fetch_failures = []
    specified_count = sum(1 for slot in slots if slot["image"])
    bb.note("DOCKER_CONTAINER_BUILD_REPORT: Total %d/%d images specified" % (specified_count, max_slots))

    def record_fetch_failure(slot, image, reason):
        fetch_failures.append({
            "slot": slot["index"],
            "image": image,
            "reason": reason,
        })
        bb.warn("Slot %d (%s): %s" % (slot["index"], image, reason))

    for slot in slots:
        image = slot["image"]
        if not image:
            continue

        dest = os.path.join(fetchdir, slot["tar_name"])
        slotdir = os.path.join(d.getVar("WORKDIR"), "frozen-slot%d" % slot["index"])
        bb.note("Fetching linux/%s image for slot %d: %s" % (target_arch, slot["index"], image))

        if image.startswith("file://"):
            d.setVar("DOCKER_FILE_URI", image)
            src = docker_local_tar_path(d)
            if src is None or not os.path.isfile(src):
                record_fetch_failure(
                    slot,
                    image,
                    "local image not found at %s" % (src or image),
                )
                continue
            try:
                shutil.copy2(src, dest)
            except OSError as exc:
                record_fetch_failure(
                    slot,
                    image,
                    "failed to copy local image from %s: %s" % (src, exc),
                )
                continue
            d.setVar("DOCKER_TAR_PATH", dest)
            repoTag = docker_read_tar_repo_tag()
            if not repoTag:
                record_fetch_failure(
                    slot,
                    image,
                    "could not read RepoTags from local tarball %s" % src,
                )
                continue
            run_refs[slot["index"]] = repoTag
            fetched_count += 1
            local_count += 1
            bb.note(
                "Local tarball slot %d: %s → run ref '%s'"
                % (slot["index"], src, run_refs[slot["index"]])
            )
            continue

        ref = normalize_ref(image)
        if ref is None:
            record_fetch_failure(
                slot,
                image,
                "unsupported image reference (use Docker Hub, GCR, or file:///path/image.tar)",
            )
            continue
        registry, _, _ = parse_registry_ref(image)
        if registry is None:
            record_fetch_failure(slot, image, "could not parse image reference")
            continue
        if not is_supported_remote_registry(registry):
            record_fetch_failure(
                slot,
                image,
                "unsupported registry '%s' (only Docker Hub and GCR are supported; "
                "use file:///path/image.tar for other registries)" % registry,
            )
            continue

        image_spec = frozen_image_spec(image)
        if not image_spec:
            record_fetch_failure(slot, image, "could not build image spec")
            continue

        cache_path = docker_dl_cache_path(image_spec, target_arch)
        if os.path.isfile(cache_path):
            try:
                shutil.copy2(cache_path, dest)
            except OSError as exc:
                record_fetch_failure(
                    slot,
                    image,
                    "failed to copy cached image from %s: %s" % (cache_path, exc),
                )
                continue
            run_refs[slot["index"]] = run_image_ref(image)
            fetched_count += 1
            cache_count += 1
            bb.note(
                "Slot %d: using cached image from DL_DIR %s (skipping registry fetch)"
                % (slot["index"], cache_path)
            )
            continue

        env = build_download_env()

        if os.path.isdir(slotdir):
            shutil.rmtree(slotdir)

        cmd = [python_bin, script, slotdir, image_spec]
        bb.note("Launching: TARGETARCH=%s %s" % (target_arch, " ".join(cmd)))
        try:
            subprocess.check_call(cmd, env=env)
            tar_cmd = ["tar", "-cC", slotdir, "-f", dest, "."]
            bb.note("Running: %s" % " ".join(tar_cmd))
            subprocess.check_call(tar_cmd)
        except subprocess.CalledProcessError as exc:
            record_fetch_failure(
                slot,
                image,
                "download-frozen-image.py failed for %s (exit %s)"
                % (image_spec, exc.returncode),
            )
            if os.path.isfile(dest):
                os.remove(dest)
            continue
        except OSError as exc:
            record_fetch_failure(
                slot,
                image,
                "failed to package downloaded image %s: %s" % (image_spec, exc),
            )
            if os.path.isfile(dest):
                os.remove(dest)
            continue
        finally:
            if os.path.isdir(slotdir):
                shutil.rmtree(slotdir)

        if not os.path.isfile(dest):
            record_fetch_failure(
                slot,
                image,
                "no tarball produced after download of %s" % image_spec,
            )
            continue

        try:
            os.makedirs(os.path.dirname(cache_path), exist_ok=True)
            shutil.copy2(dest, cache_path)
            bb.note("Slot %d: cached image to DL_DIR %s" % (slot["index"], cache_path))
        except OSError as exc:
            bb.warn(
                "Slot %d: fetched %s but failed to cache under DL_DIR (%s): %s"
                % (slot["index"], image_spec, cache_path, exc)
            )

        run_refs[slot["index"]] = run_image_ref(image)
        fetched_count += 1
        registry_count += 1

    bb.note(
        "DOCKER_CONTAINER_BUILD_REPORT: Total %d/%d images obtained "
        "(%d from registry, %d from DL_DIR cache, %d from local tar-ball)"
        % (fetched_count, specified_count, registry_count, cache_count, local_count)
    )
    bb.note("DOCKER_CONTAINER_BUILD_REPORT: Fetch Failures: %d" % len(fetch_failures))

    if fetch_failures:
        msg_lines = [
            "Docker image fetch failed: %d of %d specified image(s) could not be fetched "
            "after trying all slots." % (len(fetch_failures), specified_count),
            "",
            "Failed images:",
        ]
        for entry in fetch_failures:
            msg_lines.append("  slot %d: %s" % (entry["slot"], entry["image"]))
            msg_lines.append("    %s" % entry["reason"])
        if fetched_count:
            msg_lines.append("")
            msg_lines.append(
                "Successfully fetched %d image(s); fix the failures above and rebuild."
                % fetched_count
            )
        else:
            msg_lines.append("")
            msg_lines.append("No images were fetched successfully.")
        bb.fatal("\n".join(msg_lines))

    for idx, ref in enumerate(run_refs):
        d.setVar("DOCKER_RUN_REF_%d" % idx, ref or "")
}

do_fetch_images[dirs] = "${WORKDIR}/${DOCKER_IMAGE_SUBDIR} ${WORKDIR}/frozen-slot0 ${WORKDIR}/frozen-slot1 ${WORKDIR}/frozen-slot2 ${WORKDIR}/frozen-slot3"
# frozen slot paths must match DOCKER_SLOT_MAX (currently 4)
do_fetch_images[network] = '1'
do_fetch_images[vardepsexclude] = "BB_ORIGENV"
addtask fetch_images after do_apply_override before do_write_boot_script

# Log override application before image fetch / boot-script generation
python do_apply_override () {
    import os
    import re

    # Start with initial Defaults, already filled in by bitbake
    # The weak assignments above get overridden by environment-exported values.
    # And now the override file values take priority.
    path = d.getVar("DOCKER_IMAGES_OVERRIDE_FILE")
    if not path or not os.path.isfile(path):
        bb.note("No Docker override file at %s" % path)
        return

    allowed = {
        "DOCKER_LIST_IMAGES",
        "DOCKER_LIST_RUN_ARGS",
        "DOCKER_STATE_START_DAEMON",
    }

    with open(path, encoding="utf-8") as fh:
        for lineno, line in enumerate(fh, 1):
            line = line.strip()
            if not line or line.startswith("#"):
                continue

            match = re.match(r'^([A-Z0-9_]+)\s*=\s*(.*)$', line)
            if not match:
                bb.warn("Ignoring invalid override line %d in %s" % (lineno, path))
                continue

            key, value = match.group(1), match.group(2).strip()
            if key not in allowed:
                bb.warn("Ignoring unknown override key '%s' in %s" % (key, path))
                continue

            if len(value) >= 2 and value[0] == value[-1] and value[0] in ('"', "'"):
                value = value[1:-1]

            d.setVar(key, value)
            bb.note("Override %s from %s" % (key, path))
}
addtask do_apply_override after do_unpack before do_fetch_images

python do_write_boot_script () {
    import os
    import textwrap
    import subprocess
    import shutil

    def docker_args_has_image_ref ():
        args = (d.getVar("DOCKER_RUN_FLAGS") or "").strip()
        run_ref = (d.getVar("DOCKER_RUN_REF") or "").strip()
        if not args or not run_ref:
            return "0"
        parts = args.split()
        if not parts:
            return "0"
        last = parts[-1]
        if last == run_ref:
            return "1"
        if ":" not in last or last.startswith("/") or last.startswith("-"):
            return "0"
        host, _, port = last.partition(":")
        if host.isdigit() and port.isdigit():
            return "0"
        if "/" in host or (port and "/" in port):
            return "0"
        return "1"

    slots = docker_parse_lists(d)
    libdir = d.getVar("DOCKER_LIBDIR", True)
    datadir = d.getVar("DOCKER_DATADIR", True)
    systemd_unitdir = d.getVar("systemd_system_unitdir", True)
    marker_dir = d.getVar("DOCKER_MARKER_DIR")
    wait_iter = d.getVar("DOCKER_BOOT_WAIT_ITER")
    image_subdir = d.getVar("DOCKER_IMAGE_SUBDIR")
    workdir = d.getVar("WORKDIR")
    first_boot_script = d.getVar("DOCKER_FIRST_BOOT_SCRIPT")
    run_lines = []
    load_lines = []

    for slot in slots:
        image = slot["image"]
        if not image:
            continue

        fetched_tar = os.path.join(workdir, image_subdir, slot["tar_name"])
        bb.note("Writing boot script: image_tar_name: %s fetched_tar: %s" % (slot["tar_name"], fetched_tar))
        if not os.path.isfile(fetched_tar):
            bb.warn(
                "No fetched image for slot %d (%s) in %s; omitting from boot script"
                % (slot["index"], image, fetched_tar)
            )
            continue

        tar_path = os.path.join(datadir, image_subdir, slot["tar_name"])
        tarcmdPath = shutil.which("tar")
        sedcmdPath = shutil.which("sed")
        if not tarcmdPath or not sedcmdPath:
            bb.warn("tar or sed not found in PATH; skipping image")
            continue

        sed_expression = "'s/.*RepoTags\":.*\[.*\"(.*)\".*\],.*/\\1/g'"
        imagenameIdCmd = "%s xf %s ./manifest.json -O | %s -zE %s" % (tarcmdPath, fetched_tar, sedcmdPath, sed_expression)

        returnResult = subprocess.run(imagenameIdCmd, shell=True, capture_output=True, text=True)
        imagenameId = returnResult.stdout.strip() if returnResult.returncode == 0 else ""
        if not imagenameId:
            # Fallback for archives without manifest.json (e.g. schemaVersion=1 frozen images)
            imagenameId = (d.getVar("DOCKER_RUN_REF_%d" % slot["index"]) or "").strip()
            if not imagenameId:
                bb.warn(
                    "Unable to determine image name/id for slot %d (%s) in %s (manifest rc=%d); skipping"
                    % (slot["index"], image, fetched_tar, returnResult.returncode)
                )
                continue

        bb.note("Image in slot %d (%s) at %s imagenameId: %s" % (slot["index"], image, fetched_tar, imagenameId))
        load_lines.append('if [ -f "%s" ]; then' % tar_path)
        load_lines.append('  echo "Loading image from %s"' % tar_path)
        load_lines.append('  docker load -i "%s" || echo "WARN: failed to load %s"' % (tar_path, tar_path))
        load_lines.append('else')
        load_lines.append('  echo "WARN: missing image tarball %s (slot %d)"' % (tar_path, slot["index"]))
        load_lines.append('fi')

        if slot["enabled"] not in ("yes", "y", "1", "true", "on"):
            continue

        args = slot["run_args"] or ""
        run_ref = (d.getVar("DOCKER_RUN_REF_%d" % slot["index"]) or "").strip()
        run_lines.append('echo "Starting container for slot %d"' % slot["index"])
        image_arg = run_ref or imagenameId

        if "#" in args:
            flags, cmd = args.split("#", 1)
            flags = flags.strip()
            cmd = cmd.strip()
            d.setVar("DOCKER_RUN_FLAGS", flags)
            d.setVar("DOCKER_RUN_REF", run_ref)
            has_ref = docker_args_has_image_ref() == "1"
            if run_ref and not has_ref:
                run_lines.append(
                    'docker run %s%s %s %s || echo "WARN: failed to start slot %d"'
                     % (("" if ("-d" in flags.split() or "--detach" in flags.split()) else "-d "), flags, run_ref, cmd, slot["index"])
                )
            elif cmd:
                run_lines.append(
                    'docker run %s%s %s || echo "WARN: failed to start slot %d"'
                    % (("" if ("-d" in flags.split() or "--detach" in flags.split()) else "-d "), flags, cmd, slot["index"])
                )
            else:
                bb.warn("Slot %d: run args need image ref or #command; skipping container start" % slot["index"])
        elif run_ref:
            d.setVar("DOCKER_RUN_FLAGS", args)
            d.setVar("DOCKER_RUN_REF", run_ref)
            if docker_args_has_image_ref() == "1":
                # Image ref is already the last token in args; do not append another
                run_lines.append(
                    'docker run %s%s || echo "WARN: failed to start slot %d"'
                    % (("" if ("-d" in args.split() or "--detach" in args.split()) else "-d "), args, slot["index"])
                )
            else:
                # Flags only (e.g. default alpine slot): append one image ref
                run_lines.append(
                    'docker run %s%s %s || echo "WARN: failed to start slot %d"'
                    % (("" if ("-d" in args.split() or "--detach" in args.split()) else "-d "), args, image_arg, slot["index"])
                )
        elif args:
            run_lines.append(
                'docker run %s%s %s || echo "WARN: failed to start slot %d"'
                % (("" if ("-d" in args.split() or "--detach" in args.split()) else "-d "),
                   args, imagenameId, slot["index"])
            )
        else:
            bb.warn(
                "Slot %d enabled for boot but no image reference available; "
                "skipping container start" % slot["index"]
            )

    script = textwrap.dedent("""\
        #!/bin/bash
        set -euo pipefail

        MARKER_DIR="%s"
        MARKER_FILE="${MARKER_DIR}/first-boot-done"
        SCRIPT_NAME="%s"
        SCRIPT_PATH="%s/${SCRIPT_NAME}"
        UNIT_PATH="%s/docker-boot.service"
        WANT_PATH="/etc/systemd/system/multi-user.target.wants/docker-boot.service"

        mkdir -p "${MARKER_DIR}"

        if [ -f "${MARKER_FILE}" ]; then
            echo "Docker boot script already ran; exiting."
            exit 0
        fi

        echo "Ensuring Docker daemon is running..."
        systemctl start docker 2>/dev/null || true

        echo "Waiting for Docker daemon..."
        for i in $(seq 1 %s); do
            if docker info >/dev/null 2>&1; then
                break
            fi
            sleep 2
        done

        if ! docker info >/dev/null 2>&1; then
            echo "ERROR: Docker daemon not available; aborting first-boot container launch."
            exit 1
        fi

        echo "Loading managed Docker images..."
    """ % (marker_dir, first_boot_script, libdir, systemd_unitdir, wait_iter))

    for line in load_lines:
        script += "        " + line + "\n"

    script += "\n        echo \"Starting enabled containers...\"\n"
    for line in run_lines:
        script += "        " + line + "\n"

    script += textwrap.dedent("""\

        touch "${MARKER_FILE}"

        echo "Disabling and removing one-shot Docker boot script..."
        systemctl disable docker-boot.service 2>/dev/null || true
        cp -f "${SCRIPT_PATH}" /tmp/"${SCRIPT_NAME}".archive
        rm -f "${SCRIPT_PATH}" "${UNIT_PATH}" "${WANT_PATH}"
        systemctl daemon-reload 2>/dev/null || true

        echo "Docker first-boot complete."
        exit 0
    """)

    script_path = os.path.join(d.getVar("WORKDIR"), "docker-boot.sh")
    with open(script_path, "w", encoding="utf-8") as fh:
        fh.write(script)
    os.chmod(script_path, 0o755)

    service = textwrap.dedent("""\
        [Unit]
        Description=one-shot Docker image load and container launch
        After=docker.service network-online.target
        Wants=network-online.target
        ConditionPathExists=!%s/first-boot-done

        [Service]
        Type=oneshot
        ExecStart=%s/%s
        RemainAfterExit=no
        StandardOutput=append:/tmp/docker-first-boot.log
        StandardError=append:/tmp/docker-first-boot.log

        [Install]
        WantedBy=multi-user.target
    """ % (marker_dir, libdir, first_boot_script))

    service_path = os.path.join(d.getVar("WORKDIR"), "docker-boot.service")
    with open(service_path, "w", encoding="utf-8") as fh:
        fh.write(service)
}

do_write_boot_script[dirs] = "${WORKDIR}"
do_write_boot_script[deptask] += "do_fetch_images"
addtask do_write_boot_script after do_fetch_images before do_install

do_install() {
    install -d ${D}${DOCKER_LIBDIR}
    install -d ${D}${DOCKER_DATADIR}/${DOCKER_IMAGE_SUBDIR}
    install -d ${D}${systemd_system_unitdir}
    install -d ${D}${ROOT_HOME}

    install -m 0755 ${WORKDIR}/docker-boot.sh ${D}${DOCKER_LIBDIR}/docker-boot.sh
    install -m 0700 ${UNPACKDIR}/expand-root-partition ${D}${ROOT_HOME}/expand-root-partition
    install -m 0644 ${WORKDIR}/docker-boot.service ${D}${systemd_system_unitdir}/

    rfs_tar_count=0
    for tar in ${WORKDIR}/images/*.tar; do
        if [ -f "$tar" ]; then
            install -m 0644 "$tar" ${D}${DOCKER_DATADIR}/${DOCKER_IMAGE_SUBDIR}/
            rfs_tar_count=$(expr $rfs_tar_count + 1)
        fi
    done
    bbnote "DOCKER_CONTAINER_BUILD_REPORT: Total $rfs_tar_count image tarballs laid out in root filesystem"

    case "${DOCKER_STATE_START_DAEMON}" in
        1|y|yes|true|on)
            start_daemon=1
            ;;
        *)
            start_daemon=0
            ;;
    esac

    if [ "$start_daemon" = "1" ]; then
        install -d ${D}${sysconfdir}/systemd/system/multi-user.target.wants
        ln -sf ../docker.service ${D}${sysconfdir}/systemd/system/multi-user.target.wants/docker.service
    fi
}

FILES:${PN} += " \
    ${DOCKER_LIBDIR}/docker-boot.sh \
    ${DOCKER_DATADIR}/${DOCKER_IMAGE_SUBDIR} \
    ${ROOT_HOME}/expand-root-partition \
    ${systemd_system_unitdir}/docker-boot.service \
"
