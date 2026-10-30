#!/usr/bin/env bash
# hps-amp/scripts/toolchains.sh
#
# Idempotent toolchain + host-tool provisioner.
#
# Ensures both Arm GNU 14.3.rel1 toolchains are available on PATH:
#   aarch64-none-elf-        bare-metal (Bao EL2, FreeRTOS guests)
#   aarch64-none-linux-gnu-  Linux ABI  (Linux kernel, ATF, U-Boot)
#
# Also ensures genimage (used by mksdcard.sh) is available:
#   genimage is built from source into .toolchain/hostdeps/ if not on PATH.
#   libconfuse (genimage dependency) is built first if needed.
#
# If a toolchain / tool is already on PATH, it is left alone. Otherwise it is
# downloaded to .toolchain/ under the orchestrator root and extracted/built.
#
# Usage:
#   scripts/toolchains.sh              # ensure both toolchains + genimage
#   scripts/toolchains.sh --bm-only    # only bare-metal
#   scripts/toolchains.sh --linux-only # only linux ABI
#   scripts/toolchains.sh --print-env  # echo PATH addition for eval
#   VERBOSE=1 scripts/toolchains.sh    # show download/extract output

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$SCRIPT_DIR/lib.sh"

TOOLCHAIN_DIR="${TOOLCHAIN_DIR:-$ROOT_DIR/.toolchain}"
HOSTDEPS_DIR="${HOSTDEPS_DIR:-$TOOLCHAIN_DIR/hostdeps}"
ARM_BASE_URL="${ARM_BASE_URL:-https://developer.arm.com/-/media/Files/downloads/gnu/14.3.rel1/binrel}"
LIBCONFUSE_VERSION="${LIBCONFUSE_VERSION:-3.3}"
GENIMAGE_VERSION="${GENIMAGE_VERSION:-19}"
DOSFSTOOLS_VERSION="${DOSFSTOOLS_VERSION:-4.2}"
MTOOLS_VERSION="${MTOOLS_VERSION:-4.0.48}"

TC_ELF_VER="arm-gnu-toolchain-14.3.rel1-x86_64-aarch64-none-elf"
TC_ELF_URL="${ARM_BASE_URL}/${TC_ELF_VER}.tar.xz"
TC_ELF_BIN="$TOOLCHAIN_DIR/$TC_ELF_VER/bin"
TC_ELF_TAR="$TOOLCHAIN_DIR/${TC_ELF_VER}.tar.xz"

TC_LINUX_VER="arm-gnu-toolchain-14.3.rel1-x86_64-aarch64-none-linux-gnu"
TC_LINUX_URL="${ARM_BASE_URL}/${TC_LINUX_VER}.tar.xz"
TC_LINUX_BIN="$TOOLCHAIN_DIR/$TC_LINUX_VER/bin"
TC_LINUX_TAR="$TOOLCHAIN_DIR/${TC_LINUX_VER}.tar.xz"

DO_BM=1
DO_LINUX=1
PRINT_ENV=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bm-only)    DO_LINUX=0 ;;
        --linux-only) DO_BM=0 ;;
        --print-env)  PRINT_ENV=1 ;;
        -v|--verbose) export VERBOSE=1 ;;
        -h|--help)
            sed -n '3,20p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) die "unknown option: $1" ;;
    esac
    shift
done

# Download + extract a single toolchain bundle. Idempotent.
_provision() {
    local label="$1" tar_path="$2" url="$3" gcc_bin="$4"
    local bin_dir; bin_dir="$(dirname "$gcc_bin")"

    if [[ -x "$gcc_bin" ]]; then
        return 0
    fi

    step "$label toolchain not found — downloading (one-time)"
    mkdir -p "$TOOLCHAIN_DIR"

    if [[ ! -f "$tar_path" ]]; then
        echo "  URL: $url"
        if command -v wget >/dev/null 2>&1; then
            wget --progress=bar:force:noscroll --tries=3 -O "$tar_path" "$url"
        elif command -v curl >/dev/null 2>&1; then
            curl -fL --progress-bar --retry 3 -o "$tar_path" "$url"
        else
            die "neither wget nor curl found — please install one"
        fi
        _verify_checksum "$tar_path"
    fi

    echo "  Extracting $(basename "$tar_path") ..."
    tar -xJf "$tar_path" -C "$TOOLCHAIN_DIR"
    [[ -x "$gcc_bin" ]] || die "extraction done but gcc not found: $gcc_bin"
    ok "$label toolchain ready: $bin_dir"
}

ensure_baremetal() {
    if command -v aarch64-none-elf-gcc >/dev/null 2>&1; then
        ok "bare-metal toolchain already on PATH: $(command -v aarch64-none-elf-gcc)"
        return 0
    fi
    _provision \
        "bare-metal (aarch64-none-elf)" \
        "$TC_ELF_TAR" "$TC_ELF_URL" \
        "$TC_ELF_BIN/aarch64-none-elf-gcc"
}

ensure_linux() {
    if command -v aarch64-none-linux-gnu-gcc >/dev/null 2>&1; then
        ok "linux-gnu toolchain already on PATH: $(command -v aarch64-none-linux-gnu-gcc)"
        return 0
    fi
    _provision \
        "linux-gnu (aarch64-none-linux-gnu)" \
        "$TC_LINUX_TAR" "$TC_LINUX_URL" \
        "$TC_LINUX_BIN/aarch64-none-linux-gnu-gcc"
}

# ── Host build helpers ────────────────────────────────────────────────────────
# Unset cross-compilation variables so host tools build for x86, not AArch64.
_unset_cross_env() {
    unset CC CXX CPP LD AR AS NM OBJCOPY OBJDUMP RANLIB STRIP CROSS_COMPILE ARCH \
          2>/dev/null || true
}

_download() {
    local url="$1" dest="$2"
    if command -v wget >/dev/null 2>&1; then
        wget --progress=bar:force:noscroll --tries=3 -O "$dest" "$url"
    elif command -v curl >/dev/null 2>&1; then
        curl -fL --progress-bar --retry 3 -o "$dest" "$url"
    else
        die "neither wget nor curl found"
    fi
    _verify_checksum "$dest"
}

# Verify a downloaded file against a sidecar SHA-256 checksum file if present.
# The sidecar file must be named "<dest>.sha256" and contain a standard
# sha256sum line: "<hash>  <basename>" or "<hash>  -".
# If no sidecar file exists the check is silently skipped.
_verify_checksum() {
    local dest="$1"
    local sha256_file="${dest}.sha256"
    [[ -f "$sha256_file" ]] || return 0
    step "Verifying checksum: $(basename "$dest")"
    (cd "$(dirname "$dest")" \
        && sha256sum --check --status "$(basename "$sha256_file")") \
        || die "checksum verification failed for $(basename "$dest")"
    ok "Checksum OK: $(basename "$dest")"
}

ensure_libconfuse() {
    command -v pkg-config >/dev/null 2>&1 \
        || die "pkg-config not found — install it (e.g. 'apt install pkg-config' / 'dnf install pkgconf-pkg-config')"

    export PKG_CONFIG_PATH="$HOSTDEPS_DIR/lib/pkgconfig:$HOSTDEPS_DIR/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"
    export LD_LIBRARY_PATH="$HOSTDEPS_DIR/lib:$HOSTDEPS_DIR/lib64:${LD_LIBRARY_PATH:-}"

    if pkg-config --exists "libconfuse >= 2.8" 2>/dev/null; then
        ok "libconfuse already available: $(pkg-config --modversion libconfuse)"
        return 0
    fi

    step "libconfuse not found — building v${LIBCONFUSE_VERSION} into ${HOSTDEPS_DIR}"
    local build_dir; build_dir="$(mktemp -d)"
    local tar="$build_dir/confuse-${LIBCONFUSE_VERSION}.tar.xz"
    _download \
        "https://github.com/libconfuse/libconfuse/releases/download/v${LIBCONFUSE_VERSION}/confuse-${LIBCONFUSE_VERSION}.tar.xz" \
        "$tar"
    tar -xJf "$tar" -C "$build_dir"
    (
        _unset_cross_env
        cd "$build_dir/confuse-${LIBCONFUSE_VERSION}"
        ./configure --prefix="$HOSTDEPS_DIR" --disable-nls
        make -j"$(nproc 2>/dev/null || echo 4)"
        make install
    )
    rm -rf "$build_dir"
    pkg-config --exists "libconfuse >= 2.8" \
        || die "libconfuse build completed but pkg-config still cannot find it"
    ok "libconfuse ready"
}

ensure_dosfstools() {
    export PATH="$HOSTDEPS_DIR/bin:$PATH"

    # dosfstools 4.x installs mkfs.fat (the real binary); mkdosfs is a symlink.
    if command -v mkfs.fat >/dev/null 2>&1; then
        ok "mkfs.fat already on PATH: $(command -v mkfs.fat)"
        return 0
    fi

    step "mkfs.fat not found — building dosfstools v${DOSFSTOOLS_VERSION} into ${HOSTDEPS_DIR}"
    local build_dir; build_dir="$(mktemp -d)"
    local tar="$build_dir/dosfstools-${DOSFSTOOLS_VERSION}.tar.gz"
    _download \
        "https://github.com/dosfstools/dosfstools/releases/download/v${DOSFSTOOLS_VERSION}/dosfstools-${DOSFSTOOLS_VERSION}.tar.gz" \
        "$tar"
    tar -xzf "$tar" -C "$build_dir"
    (
        _unset_cross_env
        cd "$build_dir/dosfstools-${DOSFSTOOLS_VERSION}"
        # --sbindir redirects sbin tools (mkfs.fat, fsck.fat) to bin/ so our
        # single $HOSTDEPS_DIR/bin PATH entry covers everything.
        ./configure --prefix="$HOSTDEPS_DIR" --sbindir="$HOSTDEPS_DIR/bin" --without-udev
        make -j"$(nproc 2>/dev/null || echo 4)"
        make install
    )
    rm -rf "$build_dir"
    command -v mkfs.fat >/dev/null 2>&1 \
        || die "dosfstools build completed but mkfs.fat not found in $HOSTDEPS_DIR/bin"
    # genimage calls 'mkdosfs' by name — create the canonical symlink if absent
    [[ -e "$HOSTDEPS_DIR/bin/mkdosfs" ]] \
        || ln -sf mkfs.fat "$HOSTDEPS_DIR/bin/mkdosfs"
    ok "mkfs.fat/mkdosfs ready: $(mkfs.fat --version 2>&1 | head -1)"
}

ensure_mtools() {
    export PATH="$HOSTDEPS_DIR/bin:$PATH"

    if command -v mcopy >/dev/null 2>&1; then
        ok "mtools already on PATH: $(command -v mcopy)"
        return 0
    fi

    step "mtools not found — building v${MTOOLS_VERSION} into ${HOSTDEPS_DIR}"
    local build_dir; build_dir="$(mktemp -d)"
    local tar="$build_dir/mtools-${MTOOLS_VERSION}.tar.gz"
    _download \
        "https://ftp.gnu.org/gnu/mtools/mtools-${MTOOLS_VERSION}.tar.gz" \
        "$tar"
    tar -xzf "$tar" -C "$build_dir"
    (
        _unset_cross_env
        cd "$build_dir/mtools-${MTOOLS_VERSION}"
        ./configure --prefix="$HOSTDEPS_DIR"
        make -j"$(nproc 2>/dev/null || echo 4)"
        make install
    )
    rm -rf "$build_dir"
    command -v mcopy >/dev/null 2>&1 \
        || die "mtools build completed but mcopy not found in $HOSTDEPS_DIR/bin"
    ok "mtools ready: $(mtools --version 2>&1 | head -1)"
}

ensure_genimage() {
    export PATH="$HOSTDEPS_DIR/bin:$PATH"

    # genimage calls mkdosfs and mcopy internally — provision them first
    ensure_dosfstools
    ensure_mtools

    if command -v genimage >/dev/null 2>&1; then
        ok "genimage already on PATH: $(command -v genimage)"
        return 0
    fi

    ensure_libconfuse

    step "genimage not found — building v${GENIMAGE_VERSION} into ${HOSTDEPS_DIR}"
    local build_dir; build_dir="$(mktemp -d)"
    local tar="$build_dir/genimage-${GENIMAGE_VERSION}.tar.xz"
    _download \
        "https://github.com/pengutronix/genimage/releases/download/v${GENIMAGE_VERSION}/genimage-${GENIMAGE_VERSION}.tar.xz" \
        "$tar"
    tar -xJf "$tar" -C "$build_dir"
    (
        _unset_cross_env
        export PKG_CONFIG_PATH="$HOSTDEPS_DIR/lib/pkgconfig:$HOSTDEPS_DIR/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"
        export LD_LIBRARY_PATH="$HOSTDEPS_DIR/lib:$HOSTDEPS_DIR/lib64:${LD_LIBRARY_PATH:-}"
        cd "$build_dir/genimage-${GENIMAGE_VERSION}"
        ./configure --prefix="$HOSTDEPS_DIR"
        make -j"$(nproc 2>/dev/null || echo 4)"
        make install
    )
    rm -rf "$build_dir"
    command -v genimage >/dev/null 2>&1 \
        || die "genimage build completed but binary not found in $HOSTDEPS_DIR/bin"
    ok "genimage ready: $(genimage --version 2>&1 | head -1)"
}

main() {
    [[ $DO_BM    -eq 1 ]] && ensure_baremetal
    [[ $DO_LINUX -eq 1 ]] && ensure_linux
    ensure_genimage

    if [[ $PRINT_ENV -eq 1 ]]; then
        local extra="$HOSTDEPS_DIR/bin:"
        [[ -d "$TC_ELF_BIN"   ]] && extra="$TC_ELF_BIN:$extra"
        [[ -d "$TC_LINUX_BIN" ]] && extra="$TC_LINUX_BIN:$extra"
        echo "export PATH=\"${extra}\$PATH\""
        echo "export LD_LIBRARY_PATH=\"$HOSTDEPS_DIR/lib:$HOSTDEPS_DIR/lib64:\${LD_LIBRARY_PATH:-}\""
        echo "export PKG_CONFIG_PATH=\"$HOSTDEPS_DIR/lib/pkgconfig:$HOSTDEPS_DIR/lib64/pkgconfig:\${PKG_CONFIG_PATH:-}\""
    fi
}

main
