#!/bin/bash
set -e

###############################################################################
# Configuration
###############################################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"

# Pick a default toolchain location: a repo-local vendored toolchain if present,
# otherwise the internal Linaro install. Either can be overridden by exporting
# TOOLCHAIN_BIN before running this script.
DEFAULT_TOOLCHAIN_BIN=""
if [ -d "$SCRIPT_DIR/gcc-arm/bin" ]; then
    DEFAULT_TOOLCHAIN_BIN="$SCRIPT_DIR/gcc-arm/bin"
elif [ -d "/p/psg/ctools/arm_gnu/linaro/aarch64/14.3/1/bin" ]; then
    DEFAULT_TOOLCHAIN_BIN="/p/psg/ctools/arm_gnu/linaro/aarch64/14.3/1/bin"
fi
TOOLCHAIN_BIN="${TOOLCHAIN_BIN:-$DEFAULT_TOOLCHAIN_BIN}"

###############################################################################
# Build Process
###############################################################################

# Add toolchain to PATH if not already available. Accept either the
# aarch64-none-linux-gnu or aarch64-none-elf GCC, matching the compiler the
# CMakeLists picks up.
if ! command -v aarch64-none-linux-gnu-gcc &>/dev/null && ! command -v aarch64-none-elf-gcc &>/dev/null; then
    if [ -n "$TOOLCHAIN_BIN" ] && [ -d "$TOOLCHAIN_BIN" ]; then
        export PATH="$TOOLCHAIN_BIN:$PATH"
    else
        echo "ERROR: AArch64 GCC toolchain not found (aarch64-none-linux-gnu-gcc or aarch64-none-elf-gcc) and TOOLCHAIN_BIN is not set."
        echo "       Please install an AArch64 cross toolchain and/or export TOOLCHAIN_BIN=/path/to/<toolchain>/bin."
        exit 1
    fi
fi

echo "==========================================================================="
echo " Building: Agilex5 HPS Baremetal (OCRAM)"
echo "==========================================================================="

# Configure the build. The cross-compile setup is defined inline in
# CMakeLists.txt, so a single CMake configure is sufficient. FetchContent
# downloads the baremetal library during this step.
echo ">>> Configuring CMake build system"
cmake -S "$SCRIPT_DIR" -B "$BUILD_DIR" -G "Unix Makefiles" \
    -DPLAT=agilex5 \
    -DBUILD_MODE=OCRAM

# Build
echo ">>> Building hps_baremetal"
cmake --build "$BUILD_DIR" -j"$(nproc)"

echo ""
echo "==========================================================================="
echo " Agilex5 HPS Baremetal (OCRAM) build complete!"
echo "==========================================================================="
