#!/bin/bash
#
# SPDX-FileCopyrightText: Copyright (C) 2026 Altera Corporation
# SPDX-License-Identifier: MIT-0
#
# Build OP-TEE OS, Client, and Examples for Agilex 5
#
# One-shot builder for an Agilex 5 OP-TEE enabled GSRD stack:
#   - OP-TEE OS + client + hello_world example
#   - Arm Trusted Firmware (BL31) with OPTEED
#   - U-Boot (patched for OP-TEE FIT + SPL + firewall + kernel addr)
#   - Linux kernel (patched DTS + OP-TEE kernel config)
#   - Optional: create JIC (requires Quartus "quartus_pfg" in PATH)
#   - Create SD image (boot FAT + rootfs ext3) and install OP-TEE userspace
#
# Usage examples:
#   export PATH_TO_CROSS_COMPILER=/usr/bin/aarch64-linux-gnu-
#   ./build_script.sh
#
# Optional environment variables:
#   RELEASE=2026.01
#   BOARD_DIR=agilex5_dk_a5e013bm16aea_gsrd
#   SKIP_JIC=1                 # skip quartus_pfg JIC generation
#   SKIP_SD_IMAGE=1            # skip sdcard image creation
#   JOBS=32                    # override parallelism
#
set -euo pipefail

# ------------------- Step 0: Script Directory and Env Setup -------------------
# Ensure the script is always run from its own directory for predictable relative paths.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Set default environment variables (can be overridden by the user)
#RELEASE="${RELEASE:-2026.01}"
#BOARD_DIR="${BOARD_DIR:-agilex5_dk_a5e013bm16aea_gsrd}"
BASE_URL="https://releases.rocketboards.org/2026.01/gsrd/agilex5_dk_a5e013bm16aea_gsrd/"

JOBS="${JOBS:-$(nproc)}"
SKIP_DEPS="${SKIP_DEPS:-0}"
SKIP_JIC="${SKIP_JIC:-0}"
SKIP_SD_IMAGE="${SKIP_SD_IMAGE:-0}"


# Configuration
GENIMAGE_VERSION="${GENIMAGE_VERSION:-19}"
LIBCONFUSE_VERSION="${LIBCONFUSE_VERSION:-3.3}"
PYTHON_DEPS_DIR="${PYTHON_DEPS_DIR:-$SCRIPT_DIR/pydeps}"
FAKEROOT_VERSION="${FAKEROOT_VERSION:-1.37.2}"
DOSFSTOOLS_VERSION="${DOSFSTOOLS_VERSION:-4.2}"
MTOOLS_VERSION="${MTOOLS_VERSION:-4.0.48}"
E2FSPROGS_VERSION="${E2FSPROGS_VERSION:-1.47.1}"
HOSTDEPS_DIR="${HOSTDEPS_DIR:-$SCRIPT_DIR/hostdeps}"

# ------------------- Step 1: Usage Function & Argument Parsing ----------------
# Display usage/help message to the user if requested
usage() {
  cat <<'USAGE'
Usage: ./ryo_optee_sd.sh [options]

Options:
  -h, --help               Show this help
  --skip-jic               Skip JIC generation (also: SKIP_JIC=1)
  --skip-sd-image          Skip SD image generation (also: SKIP_SD_IMAGE=1)
  --release=YYYY.MM        Release folder (default: 2026.01)
  --board=<board_dir>      Board folder under <release>/gsrd/ (default: agilex5_dk_a5e013bm16aea_gsrd)
  --jobs=N                 Parallelism (default: nproc)

Required env var (if you don't have the distro toolchain installed):
  PATH_TO_CROSS_COMPILER   Cross compiler prefix ending with '-'. Example:
                           export PATH_TO_CROSS_COMPILER=/opt/gcc-linaro/bin/aarch64-linux-gnu-

Typical run:
  ./ryo_optee_sd.sh
USAGE
}

# Parse command line arguments and set corresponding variables.
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      usage
      exit 0
      ;;
    --skip-jic)
      SKIP_JIC=1
      ;;
    --skip-sd-image)
      SKIP_SD_IMAGE=1
      ;;
    --release=*)
      RELEASE="${arg#*=}"
      ;;
    --board=*)
      BOARD_DIR="${arg#*=}"
      ;;
    --jobs=*)
      JOBS="${arg#*=}"
      ;;
    *)
      echo "[X] Unknown option: $arg (use --help)" >&2
      exit 1
      ;;
  esac
done

# ------------------- Step 2: Logging and Utility Functions -------------------
# Helper functions for logging and error handling.
log() { echo -e "[+] $*"; }
warn() { echo -e "[!] $*" >&2; }
die() { echo -e "[X] $*" >&2; exit 1; }

# Check if a command exists in $PATH.
need_cmd() {
  command -v "$1" >/dev/null 2>&1 || return 1
}

download_and_extract_targz() {
  local archive_name="$1"
  shift

  local url
  for url in "$@"; do
    log "Downloading $archive_name from $url"
    if wget \
      --tries=5 \
      --waitretry=5 \
      --retry-connrefused \
      --timeout=60 \
      --show-progress \
      -O- "$url" \
      --no-check-certificate | tar -xz; then
      return 0
    fi
    warn "Download failed from $url; trying next mirror."
  done

  die "Failed to download $archive_name from all mirrors."
}

# ------------------- Step 3: Dependency Installation -------------------------
# Build host-side dependencies without requiring sudo access. These tools run on
# the build host, so keep them isolated from the target AArch64 toolchain.
unset_host_toolchain_env() {
  unset CC CXX CPP LD AR AS NM OBJCOPY OBJDUMP RANLIB STRIP CROSS_COMPILE ARCH
}

export PKG_CONFIG_PATH="$HOSTDEPS_DIR/lib/pkgconfig:$HOSTDEPS_DIR/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"
export LD_LIBRARY_PATH="$HOSTDEPS_DIR/lib:$HOSTDEPS_DIR/lib64:${LD_LIBRARY_PATH:-}"

build_libconfuse_if_needed() {
  if pkg-config --exists "libconfuse >= 2.8"; then
    log "Using host libconfuse from pkg-config: $(pkg-config --modversion libconfuse)"
    return 0
  fi

  if [[ -f "$HOSTDEPS_DIR/lib/pkgconfig/libconfuse.pc" || -f "$HOSTDEPS_DIR/lib64/pkgconfig/libconfuse.pc" ]]; then
    log "Using local libconfuse from $HOSTDEPS_DIR"
    return 0
  fi

  log "Host libconfuse not found; building libconfuse v$LIBCONFUSE_VERSION locally in $HOSTDEPS_DIR"
  rm -rf "confuse-$LIBCONFUSE_VERSION"
  wget --show-progress -O- "https://github.com/libconfuse/libconfuse/releases/download/v$LIBCONFUSE_VERSION/confuse-$LIBCONFUSE_VERSION.tar.xz" --no-check-certificate | tar -xJ

  (
    unset_host_toolchain_env
    cd "confuse-$LIBCONFUSE_VERSION"
    ./configure --prefix="$HOSTDEPS_DIR" --disable-nls
    make -j"${JOBS}"
    make install
  )

  rm -rf "confuse-$LIBCONFUSE_VERSION"
  pkg-config --exists "libconfuse >= 2.8" || die "local libconfuse build failed; pkg-config cannot find libconfuse"
}

build_genimage_if_needed() {
  if need_cmd genimage; then
    log "Using existing genimage: $(command -v genimage)"
    return 0
  fi

  build_libconfuse_if_needed

  log "Building genimage v$GENIMAGE_VERSION locally in $SCRIPT_DIR/genimage"
  rm -rf "genimage-$GENIMAGE_VERSION"
  wget --show-progress -O- "https://github.com/pengutronix/genimage/releases/download/v$GENIMAGE_VERSION/genimage-$GENIMAGE_VERSION.tar.xz" --no-check-certificate | tar -xJ

  (
    unset_host_toolchain_env
    cd "genimage-$GENIMAGE_VERSION"
    ./configure --prefix="$SCRIPT_DIR/genimage"
    make -j"${JOBS}"
    make install
  )

  rm -rf "genimage-$GENIMAGE_VERSION"
}

install_python_deps_if_needed() {
  mkdir -p "$PYTHON_DEPS_DIR"
  export PYTHONPATH="$PYTHON_DEPS_DIR:${PYTHONPATH:-}"

  local python_deps=()

  if ! python3 - <<'PY'
from elftools.elf.elffile import ELFFile
PY
  then
    python_deps+=("pyelftools>=0.29")
  fi

  if ! python3 - <<'PY'
try:
    import importlib.resources
except ModuleNotFoundError:
    import importlib_resources
PY
  then
    python_deps+=("importlib_resources")
  fi

  if ((${#python_deps[@]} == 0)); then
    log "Required Python build modules are available."
    return 0
  fi

  log "Installing missing Python build modules locally in $PYTHON_DEPS_DIR: ${python_deps[*]}"
  python3 -m pip install --no-cache-dir --target "$PYTHON_DEPS_DIR" "${python_deps[@]}" || \
    die "failed to install Python build modules locally; check python3 -m pip availability and proxy settings"

  python3 - <<'PY' || die "pyelftools installed, but Python still cannot import elftools"
from elftools.elf.elffile import ELFFile
PY

  python3 - <<'PY' || die "importlib_resources installed, but Python still cannot import it"
try:
    import importlib.resources
except ModuleNotFoundError:
    import importlib_resources
PY
}

build_fakeroot_if_needed() {
  if need_cmd fakeroot; then
    log "Using existing fakeroot: $(command -v fakeroot)"
    return 0
  fi

  log "fakeroot not found; building fakeroot v$FAKEROOT_VERSION locally in $HOSTDEPS_DIR"
  rm -rf "fakeroot-$FAKEROOT_VERSION"
  wget --show-progress -O- "https://deb.debian.org/debian/pool/main/f/fakeroot/fakeroot_$FAKEROOT_VERSION.orig.tar.gz" --no-check-certificate | tar -xz

  (
    unset_host_toolchain_env
    cd "fakeroot-$FAKEROOT_VERSION"
    ac_cv_func_capset=no ./configure --prefix="$HOSTDEPS_DIR" --libdir="$HOSTDEPS_DIR/lib"
    make -j"${JOBS}"
    make install
  )

  export PATH="$HOSTDEPS_DIR/bin:$PATH"
  export LD_LIBRARY_PATH="$HOSTDEPS_DIR/lib:$HOSTDEPS_DIR/lib64:${LD_LIBRARY_PATH:-}"
  hash -r
  rm -rf "fakeroot-$FAKEROOT_VERSION"
}

build_dosfstools_if_needed() {
  if need_cmd mkdosfs; then
    log "Using existing mkdosfs: $(command -v mkdosfs)"
    return 0
  fi

  if need_cmd mkfs.fat; then
    log "Using existing mkfs.fat as mkdosfs fallback: $(command -v mkfs.fat)"
    ln -sf "$(command -v mkfs.fat)" "$HOSTDEPS_DIR/bin/mkdosfs"
    hash -r
    return 0
  fi

  log "mkdosfs not found; building dosfstools v$DOSFSTOOLS_VERSION locally in $HOSTDEPS_DIR"
  rm -rf "dosfstools-$DOSFSTOOLS_VERSION"
  wget --show-progress -O- "https://github.com/dosfstools/dosfstools/releases/download/v$DOSFSTOOLS_VERSION/dosfstools-$DOSFSTOOLS_VERSION.tar.gz" --no-check-certificate | tar -xz

  (
    unset_host_toolchain_env
    cd "dosfstools-$DOSFSTOOLS_VERSION"
    ./configure --prefix="$HOSTDEPS_DIR" --sbindir="$HOSTDEPS_DIR/bin"
    make -j"${JOBS}"
    make install
  )

  if [[ ! -x "$HOSTDEPS_DIR/bin/mkdosfs" && -x "$HOSTDEPS_DIR/bin/mkfs.fat" ]]; then
    ln -sf "$HOSTDEPS_DIR/bin/mkfs.fat" "$HOSTDEPS_DIR/bin/mkdosfs"
  fi

  export PATH="$HOSTDEPS_DIR/bin:$HOSTDEPS_DIR/sbin:$PATH"
  hash -r
  rm -rf "dosfstools-$DOSFSTOOLS_VERSION"
}

build_mtools_if_needed() {
  if need_cmd mcopy; then
    log "Using existing mcopy: $(command -v mcopy)"
    return 0
  fi

  log "mcopy not found; building mtools v$MTOOLS_VERSION locally in $HOSTDEPS_DIR"
  rm -rf "mtools-$MTOOLS_VERSION"

  download_and_extract_targz "mtools-$MTOOLS_VERSION.tar.gz" \
    "https://ftpmirror.gnu.org/mtools/mtools-$MTOOLS_VERSION.tar.gz" \
    "https://mirrors.kernel.org/gnu/mtools/mtools-$MTOOLS_VERSION.tar.gz" \
    "https://ftp.gnu.org/gnu/mtools/mtools-$MTOOLS_VERSION.tar.gz"

  (
    unset_host_toolchain_env
    cd "mtools-$MTOOLS_VERSION"
    ./configure --prefix="$HOSTDEPS_DIR"
    make -j"${JOBS}"
    make install
  )

  export PATH="$HOSTDEPS_DIR/bin:$HOSTDEPS_DIR/sbin:$PATH"
  hash -r
  rm -rf "mtools-$MTOOLS_VERSION"
}

build_e2fsprogs_if_needed() {
  if need_cmd mke2fs; then
    log "Using existing mke2fs: $(command -v mke2fs)"
    return 0
  fi

  log "mke2fs not found; building e2fsprogs v$E2FSPROGS_VERSION locally in $HOSTDEPS_DIR"
  rm -rf "e2fsprogs-$E2FSPROGS_VERSION"
  download_and_extract_targz "e2fsprogs-$E2FSPROGS_VERSION.tar.xz" \
    "https://www.kernel.org/pub/linux/kernel/people/tytso/e2fsprogs/v$E2FSPROGS_VERSION/e2fsprogs-$E2FSPROGS_VERSION.tar.xz"

  (
    unset_host_toolchain_env
    cd "e2fsprogs-$E2FSPROGS_VERSION"
    ./configure \
      --prefix="$HOSTDEPS_DIR" \
      --sbindir="$HOSTDEPS_DIR/bin" \
      --libdir="$HOSTDEPS_DIR/lib" \
      --disable-nls
    make -j"${JOBS}"
    make install-libs
    make -C misc install
  )

  export PATH="$HOSTDEPS_DIR/bin:$HOSTDEPS_DIR/sbin:$PATH"
  export LD_LIBRARY_PATH="$HOSTDEPS_DIR/lib:$HOSTDEPS_DIR/lib64:${LD_LIBRARY_PATH:-}"
  hash -r
  rm -rf "e2fsprogs-$E2FSPROGS_VERSION"
}

mkdir -p "$HOSTDEPS_DIR"
export PATH="$SCRIPT_DIR/genimage/bin:$PATH"
build_genimage_if_needed
install_python_deps_if_needed
build_fakeroot_if_needed
build_dosfstools_if_needed
build_mtools_if_needed
build_e2fsprogs_if_needed 

need_cmd genimage || die "genimage install failed (fallback build did not put genimage in PATH)."

# ------------------- Step 4: Cross-Compiler Setup ----------------------------
# Set up environment for cross-compiling to ARM64 (AArch64).
CROSS_COMPILE_VERSION_NUM=15.2.rel1
CROSS_COMPILE_FILENAME=arm-gnu-toolchain-$CROSS_COMPILE_VERSION_NUM-x86_64-aarch64-none-linux-gnu

if [ ! -d "gcc-arm" ]; then
    # Download the ARM Toolchain
    wget https://developer.arm.com/-/media/Files/downloads/gnu/$CROSS_COMPILE_VERSION_NUM/binrel/$CROSS_COMPILE_FILENAME.tar.xz

    # Unpack the ARM Toolchain
    tar xf $CROSS_COMPILE_FILENAME.tar.xz
    rm -f $CROSS_COMPILE_FILENAME.tar.xz
    mv $CROSS_COMPILE_FILENAME gcc-arm
fi

# Set required environment variables
export PATH=$SCRIPT_DIR/gcc-arm/bin:$PATH
export ARCH=arm64
export CROSS_COMPILE=aarch64-none-linux-gnu-

# Quick compiler check to ensure cross toolchain is available
"${CROSS_COMPILE}gcc" --version >/dev/null 2>&1 || die "Cross compiler not usable: ${CROSS_COMPILE}gcc"
log "Using CROSS_COMPILE prefix: ${CROSS_COMPILE}"

# ------------------- Step 5: OP-TEE Build Steps ------------------------------
# Clone, patch, and build OP-TEE OS, Client, and Hello World example.
build_optee() {
  log "Step 1: Build OP-TEE OS"
  # Clone OP-TEE OS if not present
  if [[ ! -d optee_os ]]; then
    git clone https://github.com/BenjaminLimJL/optee_os.git
    (cd optee_os && git checkout socfpga_agilex5_optee)
  fi
  # Apply platform patches, the OS build below uses PLATFORM=agilex5.
  local plat_patch="$SCRIPT_DIR/patches/0001-optee_platform_agilex5.patch"
  echo "Applying Agilex5 platform patch..."
  (cd optee_os && git apply -p1 --numstat "$plat_patch" | awk '{print $3}' | xargs -r rm -f)
  (cd optee_os && git apply -p1 "$plat_patch")
  # Apply SDM Services PTA patch (skip if already applied)
  (cd optee_os && git apply -p2 --reverse --check $SCRIPT_DIR/patches/0001-svc-pta-Add-OP-TEE-OS_sdm_svc_pta.patch 2>/dev/null \
    || git apply -p2 $SCRIPT_DIR/patches/0001-svc-pta-Add-OP-TEE-OS_sdm_svc_pta.patch)
  # Build OP-TEE OS for Agilex5
  (cd optee_os && \
    make PLATFORM=agilex5 \
      ARCH=arm \
      CROSS_COMPILE64="${CROSS_COMPILE}" \
      CFG_SDM_SVC_PTA=y \
      CFG_WITH_PAGER=n \
      CFG_CORE_DYN_SHM=y \
      CFG_SHMEM_START=0x80000000 \
      CFG_SHMEM_SIZE=0x02000000 \
      CFG_TA_ASLR=n \
      CFG_CORE_ASLR=n \
      CFG_TEE_CORE_LOG_LEVEL=2 \
      CFG_TA_DEBUG=n \
      DEBUG=0 \
      ta-targets=ta_arm64 \
      O=out/agilex5 \
      -j"${JOBS}")
  [[ -f optee_os/out/agilex5/core/tee-pager_v2.bin ]] || die "OP-TEE OS build failed: tee-pager_v2.bin not found"
  log "OP-TEE OS OK: optee_os/out/agilex5/core/tee-pager_v2.bin"
  log "Step 2: Build OP-TEE Client"
  # Clone and build OP-TEE client
  if [[ ! -d optee_client ]]; then
    git clone https://github.com/OP-TEE/optee_client.git
    (cd optee_client && git checkout -b 4.5.0_br 4.5.0)
  fi
  rm -rf optee_client/build
  mkdir -p optee_client/build
  (cd optee_client/build && \
    cmake -DCMAKE_C_COMPILER="${CROSS_COMPILE}gcc" \
      -DCMAKE_INSTALL_LIBDIR=lib64 \
      -DCMAKE_INSTALL_PREFIX=../install \
      -DCMAKE_BUILD_TYPE=Release \
      .. && \
    make -j"${JOBS}" && \
    make install)
  [[ -f optee_client/install/lib64/libteec.a ]] || die "OP-TEE client build failed: libteec.a missing"
  [[ -f optee_client/install/sbin/tee-supplicant ]] || die "OP-TEE client build failed: tee-supplicant missing"
  log "Step 3: Build OP-TEE hello_world example"
  # Clone and build the hello_world example
  if [[ ! -d optee_examples ]]; then
    git clone https://github.com/BenjaminLimJL/optee_examples.git
    (cd optee_examples && git checkout -b master_br master)
  fi
  # Symlink to match expected lib path
  ln -sf lib64 optee_client/install/lib 2>/dev/null || true
  # Build host application
  (cd optee_examples/hello_world/host && \
    TEEC_EXPORT="$(realpath ../../../optee_client/install)" && \
    "${CROSS_COMPILE}gcc" -Wall -I../ta/include -I"${TEEC_EXPORT}/include" -I./include -c main.c -o main.o && \
    "${CROSS_COMPILE}gcc" -o optee_example_hello_world main.o -lteec -L"${TEEC_EXPORT}/lib64")
  # Build Trusted Application (TA)
  (cd optee_examples/hello_world/ta && \
    export TA_DEV_KIT_DIR="$(realpath ../../../optee_os/out/agilex5/export-ta_arm64)" && \
    make)
  [[ -f optee_examples/hello_world/host/optee_example_hello_world ]] || die "hello_world host binary missing"
  [[ -f optee_examples/hello_world/ta/8aaaf200-2450-11e4-abe2-0002a5d5c51b.ta ]] || die "hello_world TA missing"

  # Apply Agilex5 SDM example patches
  local ex_patches="$SCRIPT_DIR/patches/optee_examples_agilex5"
  apply_ex_patch() {
    local name; name="$(basename "$1")"
    # Always overwrite: drop the patch's target files (from the clone or a prior run),
    # then apply so the patched version is what lands.
    (cd optee_examples && git apply -p2 --numstat "$1" | awk '{print $3}' | xargs -r rm -f)
    (cd optee_examples && git apply -p2 "$1")
    log "Applied example patch (overwrite): $name"
  }
  apply_ex_patch "$ex_patches/optee_sdm_cert_auth_example.patch"
  apply_ex_patch "$ex_patches/optee_sdm_chip_id_example.patch"
  apply_ex_patch "$ex_patches/optee_sdm_crypt_example.patch"
  apply_ex_patch "$ex_patches/optee_sdm_disable_owned_entry_example.patch"
  apply_ex_patch "$ex_patches/optee_sdm_efuse_reload_cache_example.patch"
  apply_ex_patch "$ex_patches/optee_sdm_efuse_write_disable_example.patch"
  apply_ex_patch "$ex_patches/optee_sdm_fuse_prog_example.patch"
  apply_ex_patch "$ex_patches/optee_sdm_fuse_read_example.patch"
  apply_ex_patch "$ex_patches/optee_sdm_get_idcode_example.patch"
  apply_ex_patch "$ex_patches/optee_sdm_get_prov_data_example.patch"
  apply_ex_patch "$ex_patches/optee_sdm_get_random_example.patch"
  apply_ex_patch "$ex_patches/optee_sdm_ns_allowed_list_deactivate_example.patch"
  apply_ex_patch "$ex_patches/optee_sdm_ns_allowed_list_remove_example.patch"
  apply_ex_patch "$ex_patches/optee_sdm_prog_pubkey_example.patch"
  apply_ex_patch "$ex_patches/optee_sdm_security_op_example.patch"
  apply_ex_patch "$ex_patches/optee_sdm_send_cert_example.patch"

  # Build the SDM examples (host binary + TA). Non-fatal per example so one bad
  # example does not abort the whole build; missing outputs are flagged at install time.
  local TEEC_EXPORT_DIR TA_DEV_KIT
  TEEC_EXPORT_DIR="$(realpath optee_client/install)"
  TA_DEV_KIT="$(realpath optee_os/out/agilex5/export-ta_arm64)"
  build_sdm_example() {
    local ex="$1"
    # Build host application explicitly with the cross compiler (same as hello_world).
    # The example Makefile uses "CC ?= $(CROSS_COMPILE)gcc", but make pre-defines CC=cc,
    # so ?= never overrides it and it would otherwise build with the host cc.
    (cd "optee_examples/$ex/host" && \
      "${CROSS_COMPILE}gcc" -Wall -I../ta/include -I"${TEEC_EXPORT_DIR}/include" -c main.c -o main.o && \
      "${CROSS_COMPILE}gcc" -o "$ex" main.o -lteec -L"${TEEC_EXPORT_DIR}/lib64") \
      || warn "SDM example host build failed: $ex"
    # Build Trusted Application (TA) via the OP-TEE dev kit
    (cd "optee_examples/$ex/ta" && \
      make CROSS_COMPILE="${CROSS_COMPILE}" TA_DEV_KIT_DIR="$TA_DEV_KIT") \
      || warn "SDM example TA build failed: $ex"
  }
  build_sdm_example sdm_cert_auth
  build_sdm_example sdm_chip_id
  build_sdm_example sdm_crypt
  build_sdm_example sdm_disable_owned_entry
  build_sdm_example sdm_efuse_reload_cache
  build_sdm_example sdm_efuse_write_disable
  build_sdm_example sdm_fuse_prog
  build_sdm_example sdm_fuse_read
  build_sdm_example sdm_get_idcode
  build_sdm_example sdm_get_prov_data
  build_sdm_example sdm_get_random
  build_sdm_example sdm_ns_allowed_list_deactivate
  build_sdm_example sdm_ns_allowed_list_remove
  build_sdm_example sdm_prog_pubkey
  build_sdm_example sdm_security_op
  build_sdm_example sdm_send_cert

  log "OP-TEE build complete"
}

# ------------------- Step 6: ATF (BL31) Build Step ---------------------------
# Download and build Arm Trusted Firmware with OPTEE dispatcher.
build_atf_bl31() {
  log "Step 4: Build Arm Trusted Firmware (BL31) with OPTEED"
  cd $SCRIPT_DIR
  log "Step 4: Build Arm Trusted Firmware (BL31) with OPTEED"
  if [[ ! -d arm-trusted-firmware ]]; then
    git clone https://github.com/altera-fpga/arm-trusted-firmware
    cd arm-trusted-firmware
    # git am $SCRIPT_DIR/patches/0001-feat-intel-initial-optee-enablement_atf.patch
    git am $SCRIPT_DIR/patches/0002-feat-altera-intel-NJP-support-for-ATF.patch
    cd $SCRIPT_DIR
  fi


  (cd $SCRIPT_DIR/arm-trusted-firmware && make -j"${JOBS}" PLAT=agilex5 SPD=opteed bl2 bl31)

  local bl31="arm-trusted-firmware/build/agilex5/release/bl31.bin"
  [[ -f "$bl31" ]] || die "BL31 not found at $bl31"

  if strings "$bl31" | grep -qi "optee"; then
    log "ATF OK: built with OPTEED"
  else
    die "ATF appears to be missing OPTEED support (expected 'optee' string in bl31.bin)"
  fi
}

# ------------------- Step 7: U-Boot Build Step -------------------------------
# Download, patch, and build U-Boot with OP-TEE support for Agilex5.
build_uboot() {
  cd $SCRIPT_DIR
  log "Step 5: Build U-Boot (OP-TEE enabled)"
  [[ -f $SCRIPT_DIR/arm-trusted-firmware/build/agilex5/release/bl31.bin ]] || die "Missing BL31. Run ATF step first."
  [[ -f $SCRIPT_DIR/optee_os/out/agilex5/core/tee-pager_v2.bin ]] || die "Missing OP-TEE tee-pager_v2.bin. Run OP-TEE step first."
  if [[ ! -d u-boot-socfpga ]]; then
    git clone https://github.com/altera-fpga/u-boot-socfpga.git
    cd u-boot-socfpga
    git am $SCRIPT_DIR/patches/0001-arm-socfpga-Add-OP-TEE-memory-to-SDRAM-firewall_uboot.patch
    git am $SCRIPT_DIR/patches/0002-arm-socfpga-Add-OP-TEE-OS-as-a-loadable-firmware-in-_uboot.patch
    cd $SCRIPT_DIR
  fi
  cp arm-trusted-firmware/build/agilex5/release/bl31.bin u-boot-socfpga/
  cp optee_os/out/agilex5/core/tee-pager_v2.bin u-boot-socfpga/

  # Configure for SD boot only
  sed -i 's/u-boot,spl-boot-order.*/u-boot\,spl-boot-order = \&mmc;/g' \
    $SCRIPT_DIR/u-boot-socfpga/arch/arm/dts/socfpga_agilex5_socdk_013b-u-boot.dtsi

  # Append extra configuration for U-Boot
  cat > u-boot-socfpga/config-fragment <<'CFGEOF'
CONFIG_BOOTFILE="Image"
CONFIG_NAND_BOOT=n
CONFIG_SPL_NAND_SUPPORT=n
CONFIG_CMD_NAND_TRIMFFS=n
CONFIG_CMD_NAND_LOCK_UNLOCK=n
CONFIG_NAND_DENALI_DT=n
CONFIG_SYS_NAND_U_BOOT_LOCATIONS=n
CONFIG_SPL_NAND_FRAMEWORK=n
CONFIG_CMD_NAND=n
CONFIG_MTD_RAW_NAND=n
CONFIG_CMD_UBI=n
CONFIG_CMD_UBIFS=n
CONFIG_MTD_UBI=n
CONFIG_ENV_IS_IN_UBI=n
CONFIG_UBI_SILENCE_MSG=n
CONFIG_UBIFS_SILENCE_MSG=n
CONFIG_DISTRO_DEFAULTS=n
CONFIG_HUSH_PARSER=y
CONFIG_SYS_PROMPT_HUSH_PS2="> "
CONFIG_USE_BOOTCOMMAND=y
CONFIG_BOOTCOMMAND="load mmc 0:1 \${loadaddr} ghrd.core.rbf; fpga load 0 \${loadaddr} \${filesize};bridge enable; mmc rescan; fatload mmc 0:1 0x85000000 Image;fatload mmc 0:1 0x88000000 socfpga_agilex5_socdk_013b.dtb;setenv bootargs console=ttyS0,115200 root=\${mmcroot} rw rootwait;booti 0x85000000 - 0x88000000"
CONFIG_CMD_FAT=y
CONFIG_CMD_FS_GENERIC=y
CONFIG_DOS_PARTITION=y
CONFIG_SPL_DOS_PARTITION=y
CONFIG_CMD_PART=y
CONFIG_SPL_CRC32=y
CONFIG_LZO=y
CONFIG_CMD_DHCP=y
CONFIG_SPI_FLASH_MACRONIX=y
CONFIG_SPI_FLASH_GIGADEVICE=y
CONFIG_SPI_FLASH_WINBOND=y
CONFIG_SPI_FLASH_ISSI=y
CFGEOF

  (cd u-boot-socfpga && \
    make clean && make mrproper && \
    make socfpga_agilex5_013b_defconfig && \
    ./scripts/kconfig/merge_config.sh -O . -m .config config-fragment && \
    make -j"${JOBS}")

  [[ -f u-boot-socfpga/u-boot.itb ]] || die "U-Boot build failed: u-boot.itb missing"
  log "U-Boot OK: u-boot-socfpga/u-boot.itb"
}

# ------------------- Step 8: Linux Kernel Build Step -------------------------
# Download, patch, and build the Linux kernel, DTB, and modules for Agilex5.
build_linux_kernel() {
  cd $SCRIPT_DIR
  log "Step 6: Build Linux kernel + DTB + modules (OP-TEE enabled)"
  if [[ ! -d linux-socfpga ]]; then
    mkdir -p /netbatch/$USER/git_tmp
    export TMPDIR=/netbatch/$USER/git_tmp
    export GIT_TMPDIR=/netbatch/$USER/git_tmp

    git -c pack.threads=1 clone --depth 1 --single-branch https://github.com/altera-fpga/linux-socfpga.git linux-socfpga
    cd linux-socfpga
    git am --reject $SCRIPT_DIR/patches/0001-arm64-agilex5-enable-optee-support-for-agilex5_linux.patch
    git am --reject $SCRIPT_DIR/patches/0002-arm64-agilex5-enable-optee-support-for-agilex5_013b-_linux.patch
  fi

  # Minimal OP-TEE config fragment
  cat > $SCRIPT_DIR/linux-socfpga/config-fragment-agilex5 <<'KCFGEOF'
CONFIG_MARVELL_PHY=y
CONFIG_TEE=y
CONFIG_OPTEE=y
KCFGEOF

  (cd $SCRIPT_DIR/linux-socfpga && \
    make defconfig && \
    ./scripts/kconfig/merge_config.sh -O ./ ./.config ./config-fragment-agilex5 && \
    make -j"${JOBS}" Image && \
    make intel/socfpga_agilex5_socdk_013b.dtb && \
    make -j"${JOBS}" modules && \
    make -j"${JOBS}" modules_install INSTALL_MOD_PATH=modules_install INSTALL_MOD_STRIP=1)

  # Clean up unneeded symlinks in modules
  rm -f linux-socfpga/modules_install/lib/modules/*/build || true
  rm -f linux-socfpga/modules_install/lib/modules/*/source || true

  [[ -f "$SCRIPT_DIR/linux-socfpga/arch/arm64/boot/Image" ]] || die "Kernel Image missing"
  [[ -f "$SCRIPT_DIR/linux-socfpga/arch/arm64/boot/dts/intel/socfpga_agilex5_socdk_013b.dtb" ]] || die "DTB missing"
  log "Linux OK: Image + DTB + modules_install"
  cd $SCRIPT_DIR
}

# ------------------- Step 9: Fetch FPGA (GHRD) Artifacts ---------------------
# Download required FPGA files (SOF and core.rbf).
fetch_ghrd_artifacts() {
  log "Step 7: Fetch GHRD artifacts (SOF + core.rbf)"

  local sof="ghrd_a5ed013bm16ae4scs.sof"
  local rbf="ghrd.core.rbf"

  if [[ ! -f "$sof" ]]; then
    wget -O "$sof" "${BASE_URL}/${sof}" --no-check-certificate
  fi

  if [[ ! -f "$rbf" ]]; then
    wget -O "$rbf" "${BASE_URL}/${rbf}" --no-check-certificate
  fi

  # Backward-compat name expected by older scripts
  if [[ ! -f ghrd_sd.core.rbf ]]; then
    ln -sf "$rbf" ghrd_sd.core.rbf
  fi
}

# ------------------- Step 10: JIC Generation (Optional) ----------------------
# Optionally build JIC file using Quartus tool (if enabled and available).
build_jic_optional() {
  if [[ "$SKIP_JIC" == "1" ]]; then
    warn "SKIP_JIC=1 set; skipping JIC generation."
    return 0
  fi

  log "Step 8 (optional): Build JIC (requires quartus_pfg)"

  if ! need_cmd quartus_pfg; then
    warn "quartus_pfg not found in PATH; skipping JIC generation."
    warn "If you want JIC: source your Quartus environment (e.g. quartus/bin in PATH) then re-run."
    return 0
  fi

  fetch_ghrd_artifacts

  local hex="$SCRIPT_DIR/u-boot-socfpga/spl/u-boot-spl-dtb.hex"
  [[ -f "$hex" ]] || die "Missing $hex (build U-Boot first)"

  quartus_pfg -c ghrd_a5ed013bm16ae4scs.sof ghrd_sd.jic \
    -o device=QSPI512 \
    -o flash_loader=A5ED013BM16AE4SCS \
    -o hps_path="$hex" \
    -o mode=ASX4 \
    -o hps=1

  [[ -f ghrd_sd.hps.jic ]] || die "JIC generation failed (ghrd_sd.hps.jic missing)"
  log "JIC OK: ghrd_sd.hps.jic"
}

# ------------------- Step 11: SD Card Image Generation -----------------------
# Generate bootable SD card image with FAT boot and ext3 rootfs partitions.
build_sd_image() {
  if [[ "$SKIP_SD_IMAGE" == "1" ]]; then
    warn "SKIP_SD_IMAGE=1 set; skipping SD image generation."
    return 0
  fi

  log "Step 9: Build SD card image (FAT boot + ext3 rootfs)"

  local rootfs_tar="gsrd-console-image-agilex5.tar.gz"
  if [[ ! -f "$rootfs_tar" ]]; then
    wget -O "$rootfs_tar" "${BASE_URL}/rootfs/${rootfs_tar}" --no-check-certificate
  fi

  fetch_ghrd_artifacts

  # create the SD image
    if [ -d "files_fat" ]; then
        fakeroot rm -rf files_fat
    fi

    if [ -d "files_ext3" ]; then
        fakeroot rm -rf files_ext3
    fi

    if [ -d "sd_image" ]; then
        fakeroot rm -rf sd_image
    fi

    mkdir files_fat
    mkdir files_ext3
    mkdir sd_image

  # Copy kernel modules, OP-TEE userspace, and example binaries into rootfs
  fakeroot tar -xpf gsrd-console-image-agilex5.tar.gz -C files_ext3
  fakeroot cp -a $SCRIPT_DIR/linux-socfpga/modules_install/lib/modules files_ext3/lib/


  # OP-TEE userspace components
  log "Installing OP-TEE userspace components into rootfs…"


# Install OP-TEE client library
    if [ -f "$SCRIPT_DIR/optee_client/install/lib64/libteec.a" ]; then
        fakeroot cp $SCRIPT_DIR/optee_client/install/lib64/libteec.a files_ext3/usr/lib/
        echo "Installed libteec.a (static library)"
    else
        echo "WARNING: libteec.a not found - OP-TEE client may not have been built"
    fi

    # Install tee-supplicant daemon
    if [ -f "$SCRIPT_DIR/optee_client/install/sbin/tee-supplicant" ]; then
        fakeroot cp $SCRIPT_DIR/optee_client/install/sbin/tee-supplicant files_ext3/usr/sbin/
        fakeroot chmod +x files_ext3/usr/sbin/tee-supplicant
        echo "Installed tee-supplicant"
    else
        echo "WARNING: tee-supplicant not found - OP-TEE client may not have been built"
    fi

    # Install hello_world example
    if [ -f "$SCRIPT_DIR/optee_examples/hello_world/host/optee_example_hello_world" ]; then
        fakeroot cp $SCRIPT_DIR/optee_examples/hello_world/host/optee_example_hello_world files_ext3/usr/bin/
        fakeroot chmod +x files_ext3/usr/bin/optee_example_hello_world
        echo "Installed optee_example_hello_world"
    else
        echo "WARNING: optee_example_hello_world not found - OP-TEE examples may not have been built"
    fi

    # Install hello_world TA
    if [ -f "$SCRIPT_DIR/optee_examples/hello_world/ta/8aaaf200-2450-11e4-abe2-0002a5d5c51b.ta" ]; then
        fakeroot mkdir -p files_ext3/lib/optee_armtz
        fakeroot cp $SCRIPT_DIR/optee_examples/hello_world/ta/*.ta files_ext3/lib/optee_armtz/
        echo "Installed hello_world TA to /lib/optee_armtz/"
    else
        echo "WARNING: hello_world TA not found - OP-TEE examples may not have been built"
    fi

    # Install Agilex5 SDM examples (host binary + TA); warn if not built
    install_sdm_example() {
        local ex="$1"
        # Install host application
        if [ -f "$SCRIPT_DIR/optee_examples/$ex/host/$ex" ]; then
            fakeroot cp "$SCRIPT_DIR/optee_examples/$ex/host/$ex" files_ext3/usr/bin/
            fakeroot chmod +x "files_ext3/usr/bin/$ex"
            echo "Installed $ex"
        else
            echo "WARNING: $ex host binary not found - OP-TEE examples may not have been built"
        fi
        # Install Trusted Application (TA)
        if ls "$SCRIPT_DIR/optee_examples/$ex/ta/"*.ta >/dev/null 2>&1; then
            fakeroot mkdir -p files_ext3/lib/optee_armtz
            fakeroot cp "$SCRIPT_DIR/optee_examples/$ex/ta/"*.ta files_ext3/lib/optee_armtz/
            echo "Installed $ex TA to /lib/optee_armtz/"
        else
            echo "WARNING: $ex TA not found - OP-TEE examples may not have been built"
        fi
    }
    install_sdm_example sdm_cert_auth
    install_sdm_example sdm_chip_id
    install_sdm_example sdm_crypt
    install_sdm_example sdm_disable_owned_entry
    install_sdm_example sdm_efuse_reload_cache
    install_sdm_example sdm_efuse_write_disable
    install_sdm_example sdm_fuse_prog
    install_sdm_example sdm_fuse_read
    install_sdm_example sdm_get_idcode
    install_sdm_example sdm_get_prov_data
    install_sdm_example sdm_get_random
    install_sdm_example sdm_ns_allowed_list_deactivate
    install_sdm_example sdm_ns_allowed_list_remove
    install_sdm_example sdm_prog_pubkey
    install_sdm_example sdm_security_op
    install_sdm_example sdm_send_cert

  # Add init script for tee-supplicant (sysvinit)
  fakeroot mkdir -p files_ext3/etc/init.d
  cat << 'INITEOF' | fakeroot tee files_ext3/etc/init.d/tee-supplicant > /dev/null
#!/bin/sh
### BEGIN INIT INFO
# Provides:          tee-supplicant
# Required-Start:    $local_fs
# Required-Stop:     $local_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: OP-TEE supplicant daemon
# Description:       Starts the OP-TEE supplicant daemon for trusted application support
### END INIT INFO

case "$1" in
  start)
    echo "Starting tee-supplicant..."
    /usr/sbin/tee-supplicant -d
    ;;
  stop)
    echo "Stopping tee-supplicant..."
    killall tee-supplicant
    ;;
  *)
    echo "Usage: /etc/init.d/tee-supplicant {start|stop}"
    exit 1
    ;;
esac

exit 0
INITEOF

  fakeroot chmod +x files_ext3/etc/init.d/tee-supplicant

  if [[ -d files_ext3/etc/rc5.d ]]; then
    fakeroot ln -sf ../init.d/tee-supplicant files_ext3/etc/rc5.d/S99tee-supplicant
  fi

  # Optionally add systemd service
  if [[ -d files_ext3/etc/systemd/system || -d files_ext3/lib/systemd/system ]]; then
    local systemd_dir
    if [[ -d files_ext3/lib/systemd/system ]]; then
      systemd_dir="files_ext3/lib/systemd/system"
    else
      systemd_dir="files_ext3/etc/systemd/system"
    fi

    cat << 'SERVICEEOF' | fakeroot tee "${systemd_dir}/tee-supplicant.service" > /dev/null
[Unit]
[Unit]
Description=OP-TEE Supplicant Daemon
After=local-fs.target

[Service]
Type=forking
ExecStart=/usr/sbin/tee-supplicant -d
Restart=on-failure

[Install]
WantedBy=multi-user.target
SERVICEEOF
    fakeroot chmod 644 "${systemd_dir}/tee-supplicant.service"

    fakeroot mkdir -p files_ext3/etc/systemd/system/multi-user.target.wants
    fakeroot ln -sf "${systemd_dir#files_ext3/}/tee-supplicant.service" \
      files_ext3/etc/systemd/system/multi-user.target.wants/tee-supplicant.service
  fi

  # Copy boot files to FAT partition content
  cp $SCRIPT_DIR/linux-socfpga/arch/arm64/boot/Image files_fat/
  cp $SCRIPT_DIR/linux-socfpga/arch/arm64/boot/dts/intel/socfpga_agilex5_socdk_013b.dtb files_fat/
  cp $SCRIPT_DIR/u-boot-socfpga/u-boot.itb files_fat/
  cp $SCRIPT_DIR/ghrd_sd.core.rbf files_fat/ghrd.core.rbf

  # Create genimage configuration for SD card
  cat > genimage.cfg <<'GENEOF'
# Partition 1: FAT
image boot.vfat {
    vfat {
        extraargs = "-n BOOT"
    }
    size = 128M
    # Only use files from the 'files_fat' directory
    srcpath = "files_fat"
}

# Partition 2: ext3
image rootfs.ext3 {
    ext3 {
        label = "rootfs"
    }
    size = 2048M
    # Only use files from the 'files_ext3' directory
    srcpath = "files_ext3"
}

# SD card image (remain unchanged)
image sdcard.img {
    hdimage {}
    partition boot {
        partition-type = 0xC
        bootable = "true"
        image = "boot.vfat"
    }
    partition rootfs {
        partition-type = 0x83
        image = "rootfs.ext3"
    }
}
GENEOF

  # Generate the SD card image
  fakeroot genimage \
    --config genimage.cfg \
    --tmppath /tmp/genimage-build \
    --inputpath . \
    --outputpath sd_image \
    --rootpath .

  [[ -f sd_image/sdcard.img ]] || die "SD image generation failed: sd_image/sdcard.img missing"
  log "SD image OK: sd_image/sdcard.img"
}

# ------------------- Main Entrypoint -----------------------------------------
main() {
  echo "========================================"
  echo "Agilex 5 OP-TEE Full Build (one script)"
  echo "========================================"
  echo "Board:    SM43"
  echo "Base URL: ${BASE_URL}"
  echo "JOBS:     ${JOBS}"
  echo ""

  # 1. Check and install dependencies
  # 2. Set up cross-compiler environment
  # 3. Build OP-TEE (OS, Client, Examples)
  build_optee
  # 4. Build Arm Trusted Firmware (BL31)
  build_atf_bl31
  # 5. Build U-Boot (with OP-TEE support)
  build_uboot
  # 6. Build Linux Kernel (with OP-TEE support)
  build_linux_kernel
  # 7. (Optional) Build JIC file
  build_jic_optional
  # 8. (Optional) Build SD card image
  build_sd_image

  echo ""
  echo "========================================"
  echo "DONE"
  echo "========================================"
  echo "Key outputs:"
  echo "  OP-TEE OS : optee_os/out/agilex5/core/tee-pager_v2.bin"
  echo "  BL31      : arm-trusted-firmware/build/agilex5/release/bl31.bin"
  echo "  U-Boot ITB : uboot-socfpga/u-boot.itb"
  echo "  Kernel    : linux-socfpga/arch/arm64/boot/Image"
  echo "  DTB       : linux-socfpga/arch/arm64/boot/dts/intel/socfpga_agilex5_socdk_013b.dtb"
  echo "  SD image  : sd_image/sdcard.img"
  if [[ -f ghrd_sd.hps.jic ]]; then
    echo "  JIC       : ghrd_sd.hps.jic"
  fi
}

main "$@"
