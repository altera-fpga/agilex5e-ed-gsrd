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
#   ./ryo_optee_sd.sh
#   GHRD_SOF=/path/to/current.sof GHRD_RBF=/path/to/ghrd.core.rbf ./ryo_optee_sd.sh
#
# Optional environment variables:
#   SKIP_JIC=1                 # skip quartus_pfg JIC generation
#   SKIP_SD_IMAGE=1            # skip sdcard image creation
#   JOBS=32                    # override parallelism
#   GHRD_SOF=/path/to.sof      # SOF from current Quartus design (required unless present locally)
#   GHRD_RBF=/path/to.core.rbf # optional; otherwise generated from SOF via quartus_pfg
#   *_REPO / *_REF             # override pinned git URLs and tags/commits (see below)
#
set -euo pipefail

# ------------------- Step 0: Script Directory and Env Setup -------------------
# Ensure the script is always run from its own directory for predictable relative paths.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Rootfs only (not SOF/RBF). SOF/RBF must come from the current design / Quartus build.
BASE_URL="https://releases.rocketboards.org/2026.01/gsrd/agilex5_dk_a5e013bm16aea_gsrd/"

JOBS="${JOBS:-$(nproc)}"
SKIP_DEPS="${SKIP_DEPS:-0}"
SKIP_JIC="${SKIP_JIC:-0}"
SKIP_SD_IMAGE="${SKIP_SD_IMAGE:-0}"

# ------------------- Pinned source revisions (reproducible builds) ------------
# Prefer tags. Until altera-fpga OP-TEE mirrors publish tags, REF may be a commit SHA.
# ATF / U-Boot / Linux pins match dk-a5e013bm16aea/baseline-a55/software/yocto_linux/kas/bsp.yml
# for QPDS26.1.1_REL_GSRD_PR.
OPTEE_OS_REPO="${OPTEE_OS_REPO:-https://github.com/altera-fpga/optee_os.git}"
OPTEE_OS_REF="${OPTEE_OS_REF:-socfpga_v26.1.1_optee}"
OPTEE_CLIENT_REPO="${OPTEE_CLIENT_REPO:-https://github.com/OP-TEE/optee_client.git}"
OPTEE_CLIENT_REF="${OPTEE_CLIENT_REF:-4.5.0}"
OPTEE_EXAMPLES_REPO="${OPTEE_EXAMPLES_REPO:-https://github.com/altera-fpga/optee_examples.git}"
OPTEE_EXAMPLES_REF="${OPTEE_EXAMPLES_REF:-socfpga_v26.1.1_optee}"
ATF_REPO="${ATF_REPO:-https://github.com/altera-fpga/arm-trusted-firmware.git}"
ATF_REF="${ATF_REF:-2ea5afda7f34774ddcc677fb3a728fa57f780a1e}"   # socfpga_v2.14.1 tip used by GSRD
UBOOT_REPO="${UBOOT_REPO:-https://github.com/altera-fpga/u-boot-socfpga.git}"
UBOOT_REF="${UBOOT_REF:-e09d6fcc95f33b8a60377103f6e37e635660a3ee}" # socfpga_v2026.04 tip used by GSRD
LINUX_REPO="${LINUX_REPO:-https://github.com/altera-fpga/linux-socfpga.git}"
LINUX_REF="${LINUX_REF:-d8e46bd82a1e1dbbc641db7f0f57d7ddeb2621b1}" # socfpga-6.18.20-lts tip used by GSRD

# Local FPGA artifacts (preferred over any remote download)
GHRD_SOF_NAME="${GHRD_SOF_NAME:-ghrd_a5ed013bm16ae4scs.sof}"
GHRD_RBF_NAME="${GHRD_RBF_NAME:-ghrd.core.rbf}"
# Default SOF search path: Quartus output next to this software/ tree in the GSRD package
GHRD_SOF_DEFAULT_CANDIDATES=(
  "$SCRIPT_DIR/$GHRD_SOF_NAME"
  "$SCRIPT_DIR/../../output_files/$GHRD_SOF_NAME"
  "$SCRIPT_DIR/../../$GHRD_SOF_NAME"
)

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
  --jobs=N                 Parallelism (default: nproc)

FPGA artifacts (do not download old rocketboards SOF/RBF):
  GHRD_SOF=/path/to.sof    SOF built with the current design + Quartus
  GHRD_RBF=/path/to.rbf    Optional core.rbf; else generated from SOF

Typical run:
  GHRD_SOF=/path/to/ghrd_a5ed013bm16ae4scs.sof ./ryo_optee_sd.sh
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

# Clone a git repo and check out an exact tag or commit (never leave on floating default branch).
clone_pinned() {
  local dest="$1"
  local url="$2"
  local ref="$3"

  if [[ -d "$dest/.git" ]]; then
    log "Using existing $dest (expected ref: $ref)"
    (
      cd "$dest"
      git fetch --tags --force origin 2>/dev/null || true
      git checkout --force "$ref"
    )
    return 0
  fi

  log "Cloning $url @ $ref -> $dest"
  git clone "$url" "$dest"
  (
    cd "$dest"
    git checkout --force "$ref"
  )
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
  clone_pinned optee_os "$OPTEE_OS_REPO" "$OPTEE_OS_REF"
  # Build OP-TEE OS for Agilex5
  (cd optee_os && \
    make PLATFORM=altera \
      ARCH=arm \
      CROSS_COMPILE64="${CROSS_COMPILE}" \
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
  clone_pinned optee_client "$OPTEE_CLIENT_REPO" "$OPTEE_CLIENT_REF"
  rm -rf optee_client/build
  mkdir -p optee_client/build
  (cd optee_client/build && \
    cmake -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
      -DCMAKE_C_COMPILER="${CROSS_COMPILE}gcc" \
      -DCMAKE_INSTALL_LIBDIR=lib64 \
      -DCMAKE_INSTALL_PREFIX=../install \
      -DCMAKE_BUILD_TYPE=Release \
      .. && \
    make -j"${JOBS}" && \
    make install)
  [[ -f optee_client/install/lib64/libteec.a ]] || die "OP-TEE client build failed: libteec.a missing"
  [[ -f optee_client/install/sbin/tee-supplicant ]] || die "OP-TEE client build failed: tee-supplicant missing"
  log "Step 3: Build OP-TEE hello_world example"
  clone_pinned optee_examples "$OPTEE_EXAMPLES_REPO" "$OPTEE_EXAMPLES_REF"
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
  log "OP-TEE build complete"
}

# ------------------- Step 6: ATF (BL31) Build Step ---------------------------
# Download and build Arm Trusted Firmware with OPTEE dispatcher.
# Agilex5 OP-TEE platform enablement is NOT in altera-fpga ATF yet (checked
# socfpga_v2.14.x and latest socfpga_v2.15.0). Keep applying the local patch
# until that commit is merged; then drop the patch and this git am.
build_atf_bl31() {
  log "Step 4: Build Arm Trusted Firmware (BL31) with OPTEED"
  cd "$SCRIPT_DIR"
  local atf_patch="$SCRIPT_DIR/patches/0001-feat-intel-initial-optee-enablement_atf.patch"
  [[ -f "$atf_patch" ]] || die "Missing ATF OP-TEE patch: $atf_patch"

  if [[ ! -d arm-trusted-firmware/.git ]]; then
    clone_pinned arm-trusted-firmware "$ATF_REPO" "$ATF_REF"
    (
      cd arm-trusted-firmware
      git am "$atf_patch"
    )
  else
    log "Using existing arm-trusted-firmware (OP-TEE patch assumed already applied)"
  fi

  (cd "$SCRIPT_DIR/arm-trusted-firmware" && make -j"${JOBS}" PLAT=agilex5 SPD=opteed bl2 bl31)

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
  cd "$SCRIPT_DIR"
  log "Step 5: Build U-Boot (OP-TEE enabled)"
  [[ -f $SCRIPT_DIR/arm-trusted-firmware/build/agilex5/release/bl31.bin ]] || die "Missing BL31. Run ATF step first."
  [[ -f $SCRIPT_DIR/optee_os/out/agilex5/core/tee-pager_v2.bin ]] || die "Missing OP-TEE tee-pager_v2.bin. Run OP-TEE step first."
  if [[ ! -d u-boot-socfpga/.git ]]; then
    clone_pinned u-boot-socfpga "$UBOOT_REPO" "$UBOOT_REF"
    (
      cd u-boot-socfpga
      git am "$SCRIPT_DIR/patches/0001-arm-socfpga-Add-OP-TEE-memory-to-SDRAM-firewall_uboot.patch"
      git am "$SCRIPT_DIR/patches/0002-arm-socfpga-Add-OP-TEE-OS-as-a-loadable-firmware-in-_uboot.patch"
    )
  else
    log "Using existing u-boot-socfpga (patches assumed already applied)"
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
  cd "$SCRIPT_DIR"
  log "Step 6: Build Linux kernel + DTB + modules (OP-TEE enabled)"
  if [[ ! -d linux-socfpga/.git ]]; then
    mkdir -p "/tmp/${USER:-user}/git_tmp"
    export TMPDIR="/tmp/${USER:-user}/git_tmp"
    export GIT_TMPDIR="/tmp/${USER:-user}/git_tmp"

    clone_pinned linux-socfpga "$LINUX_REPO" "$LINUX_REF"
    (
      cd linux-socfpga
      git am --reject "$SCRIPT_DIR/patches/0001-arm64-agilex5-enable-optee-support-for-agilex5_linux.patch"
      git am --reject "$SCRIPT_DIR/patches/0002-arm64-agilex5-enable-optee-support-for-agilex5_013b-_linux.patch"
    )
  else
    log "Using existing linux-socfpga (patches assumed already applied)"
  fi

  # Minimal OP-TEE config fragment
  cat > "$SCRIPT_DIR/linux-socfpga/config-fragment-agilex5" <<'KCFGEOF'
CONFIG_MARVELL_PHY=y
CONFIG_TEE=y
CONFIG_OPTEE=y
KCFGEOF

  (cd "$SCRIPT_DIR/linux-socfpga" && \
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
  cd "$SCRIPT_DIR"
}

# ------------------- Step 9: Resolve FPGA (GHRD) Artifacts --------------------
# Use SOF/RBF from the current design + current Quartus. Do NOT download old
# rocketboards 25.3.1 / 2026.01 prebuilt SOF or core.rbf.
resolve_ghrd_sof() {
  local cand
  if [[ -n "${GHRD_SOF:-}" ]]; then
    [[ -f "$GHRD_SOF" ]] || die "GHRD_SOF not found: $GHRD_SOF"
    echo "$GHRD_SOF"
    return 0
  fi
  for cand in "${GHRD_SOF_DEFAULT_CANDIDATES[@]}"; do
    if [[ -f "$cand" ]]; then
      echo "$cand"
      return 0
    fi
  done
  return 1
}

generate_core_rbf_from_sof() {
  local sof="$1"
  local rbf_out="$2"

  need_cmd quartus_pfg || die "quartus_pfg required to generate $rbf_out from SOF (or set GHRD_RBF)"

  log "Generating core.rbf from SOF via quartus_pfg: $sof"
  # HPS designs: -o hps=1 emits a *.core.rbf used by U-Boot fpga load
  local tmp_base="$SCRIPT_DIR/ghrd_from_sof"
  rm -f "${tmp_base}".* "${tmp_base}"*.rbf 2>/dev/null || true
  quartus_pfg -c "$sof" "${tmp_base}.rbf" -o hps=1

  local generated=""
  if [[ -f "${tmp_base}.core.rbf" ]]; then
    generated="${tmp_base}.core.rbf"
  elif [[ -f "${tmp_base}.rbf" ]]; then
    generated="${tmp_base}.rbf"
  else
    generated="$(ls -1 "$SCRIPT_DIR"/*.core.rbf 2>/dev/null | head -n1 || true)"
  fi
  [[ -n "$generated" && -f "$generated" ]] || die "quartus_pfg did not produce a core.rbf from $sof"
  cp -f "$generated" "$rbf_out"
  log "Wrote $rbf_out (from $generated)"
}

fetch_ghrd_artifacts() {
  log "Step 7: Resolve GHRD artifacts (current SOF + core.rbf)"

  local sof_src rbf_src
  local sof_dst="$SCRIPT_DIR/$GHRD_SOF_NAME"
  local rbf_dst="$SCRIPT_DIR/$GHRD_RBF_NAME"

  sof_src="$(resolve_ghrd_sof)" || die \
    "Current-design SOF not found. Build the Quartus GHRD with the matching Quartus version, then either:
  - copy ${GHRD_SOF_NAME} into $SCRIPT_DIR, or
  - set GHRD_SOF=/path/to/${GHRD_SOF_NAME}
Do not use the older rocketboards prebuilt SOF."

  if [[ "$(readlink -f "$sof_src")" != "$(readlink -f "$sof_dst")" ]]; then
    log "Using SOF: $sof_src"
    cp -f "$sof_src" "$sof_dst"
  else
    log "Using local SOF: $sof_dst"
  fi

  if [[ -n "${GHRD_RBF:-}" ]]; then
    [[ -f "$GHRD_RBF" ]] || die "GHRD_RBF not found: $GHRD_RBF"
    rbf_src="$GHRD_RBF"
    if [[ "$(readlink -f "$rbf_src")" != "$(readlink -f "$rbf_dst")" ]]; then
      log "Using RBF: $rbf_src"
      cp -f "$rbf_src" "$rbf_dst"
    fi
  elif [[ -f "$rbf_dst" ]]; then
    log "Using local RBF: $rbf_dst"
  else
    # Also accept RBF sitting next to the SOF in Quartus output_files/
    local sibling
    sibling="$(dirname "$sof_src")/$GHRD_RBF_NAME"
    if [[ -f "$sibling" ]]; then
      log "Using RBF next to SOF: $sibling"
      cp -f "$sibling" "$rbf_dst"
    else
      generate_core_rbf_from_sof "$sof_dst" "$rbf_dst"
    fi
  fi

  [[ -f "$sof_dst" ]] || die "Missing $sof_dst"
  [[ -f "$rbf_dst" ]] || die "Missing $rbf_dst"

  # Backward-compat name expected by later steps
  ln -sfn "$GHRD_RBF_NAME" "$SCRIPT_DIR/ghrd_sd.core.rbf"
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
  echo "Board:           DK-A5E013BM16AEA"
  echo "Rootfs base URL: ${BASE_URL}"
  echo "JOBS:            ${JOBS}"
  echo "OP-TEE OS:       ${OPTEE_OS_REPO} @ ${OPTEE_OS_REF}"
  echo "OP-TEE client:   ${OPTEE_CLIENT_REPO} @ ${OPTEE_CLIENT_REF}"
  echo "OP-TEE examples: ${OPTEE_EXAMPLES_REPO} @ ${OPTEE_EXAMPLES_REF}"
  echo "ATF:             ${ATF_REPO} @ ${ATF_REF}"
  echo "U-Boot:          ${UBOOT_REPO} @ ${UBOOT_REF}"
  echo "Linux:           ${LINUX_REPO} @ ${LINUX_REF}"
  echo ""

  build_optee
  build_atf_bl31
  build_uboot
  build_linux_kernel
  build_jic_optional
  build_sd_image

  echo ""
  echo "========================================"
  echo "DONE"
  echo "========================================"
  echo "Key outputs:"
  echo "  OP-TEE OS : optee_os/out/agilex5/core/tee-pager_v2.bin"
  echo "  BL31      : arm-trusted-firmware/build/agilex5/release/bl31.bin"
  echo "  U-Boot ITB: u-boot-socfpga/u-boot.itb"
  echo "  Kernel    : linux-socfpga/arch/arm64/boot/Image"
  echo "  DTB       : linux-socfpga/arch/arm64/boot/dts/intel/socfpga_agilex5_socdk_013b.dtb"
  echo "  SOF       : ${GHRD_SOF_NAME}"
  echo "  core.rbf  : ${GHRD_RBF_NAME}"
  echo "  SD image  : sd_image/sdcard.img"
  if [[ -f ghrd_sd.hps.jic ]]; then
    echo "  JIC       : ghrd_sd.hps.jic"
  fi
}

main "$@"
