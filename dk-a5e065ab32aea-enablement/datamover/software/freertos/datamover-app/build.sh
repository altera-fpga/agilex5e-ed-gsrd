#!/bin/bash
set -e

###############################################################################
# Configuration
###############################################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_FOLDER="$(realpath "$SCRIPT_DIR/../../..")"
FREERTOS_TOP_FOLDER="$PROJECT_FOLDER/software/freertos"
DATAMOVER_FOLDER="$FREERTOS_TOP_FOLDER/datamover-app"

CMAKE_COMMAND=cmake
ARM_TOOLCHAIN="arm-gnu-toolchain-14.3.rel1-x86_64-aarch64-none-elf"
ARM_TOOLCHAIN_BIN="$FREERTOS_TOP_FOLDER/$ARM_TOOLCHAIN/bin"
PFG_FILE="$FREERTOS_TOP_FOLDER/qspi_flash_image_agilex5_boot.pfg"
SOF_PATH="$PROJECT_FOLDER/output_files/datamover.sof"

###############################################################################
# Build Process
###############################################################################

VERSION="$1" # single-threaded or multi-threaded
if [ -z "$VERSION" ]; then
    echo "ERROR: Version is required"
    exit 1
fi

if [ "$VERSION" != "single-threaded" ] && [ "$VERSION" != "multi-threaded" ]; then
    echo "ERROR: Unknown version '$VERSION'. Choose 'single-threaded' or 'multi-threaded'."
    exit 1
fi

BUILD_FOLDER="$DATAMOVER_FOLDER/$VERSION/build"
FPGA_BINARIES_DIR="$BUILD_FOLDER/fpga_binaries"

# Download ARM toolchain
GET_ARM_TOOLCHAIN_DONE="$FREERTOS_TOP_FOLDER/get-arm-toolchain.done"

NEEDS_REBUILD=0
if [ ! -f "$GET_ARM_TOOLCHAIN_DONE" ]; then
    NEEDS_REBUILD=1
fi

if [ "$NEEDS_REBUILD" -eq 1 ]; then
    echo ">>> Downloading ARM toolchain $ARM_TOOLCHAIN"
    cd "$FREERTOS_TOP_FOLDER"
    wget "https://developer.arm.com/-/media/Files/downloads/gnu/14.3.rel1/binrel/${ARM_TOOLCHAIN}.tar.xz"
    tar -xvf "${ARM_TOOLCHAIN}.tar.xz"
    rm -f "${ARM_TOOLCHAIN}.tar.xz"
    touch "$GET_ARM_TOOLCHAIN_DONE"
fi

if [ ! -d "$ARM_TOOLCHAIN_BIN" ]; then
    echo "ERROR: ARM toolchain not found at $ARM_TOOLCHAIN_BIN even after download attempt"
    exit 1
fi

echo "==========================================================================="
echo " Building: $VERSION"
echo "==========================================================================="

# Configure cmake build system
echo ">>> Configuring cmake build system for $VERSION"
mkdir -p "$BUILD_FOLDER"
cd "$BUILD_FOLDER"
if [ "$VERSION" == "multi-threaded" ]; then
    SMP=ON
else
    SMP=OFF
fi
PATH="$(realpath "$ARM_TOOLCHAIN_BIN"):$PATH" \
    $CMAKE_COMMAND "$DATAMOVER_FOLDER" -G"Unix Makefiles" \
    -DCMAKE_BUILD_TYPE=Release -DDM_VERSION="$VERSION" -DSMP="$SMP"

# Build ATF (bl2/bl31), bl2.hex, datamover.bin, and fip.bin — all driven by cmake
echo ">>> Building $VERSION (ATF + datamover + FIP)"
cd "$BUILD_FOLDER"
PATH="$(realpath "$ARM_TOOLCHAIN_BIN"):$PATH" $CMAKE_COMMAND --build .

# Copy SOF
echo ">>> Copying SOF for $VERSION"
mkdir -p "$FPGA_BINARIES_DIR"
cp -f "$SOF_PATH" "$FPGA_BINARIES_DIR/datamover.sof"

# Generate FSBL SOF
echo ">>> Generating FSBL SOF for $VERSION"
cd "$FPGA_BINARIES_DIR"
quartus_pfg -c -o hps_path="$FPGA_BINARIES_DIR/bl2.hex" datamover.sof fsbl.sof

# Generate core.rbf
echo ">>> Generating core.rbf for $VERSION"
cd "$FPGA_BINARIES_DIR"
quartus_pfg -c fsbl.sof ghrd.rbf -o hps=ON -o hps_path="$FPGA_BINARIES_DIR/bl2.hex"

# Generate RBF with size header
echo ">>> Generating RBF with size header for $VERSION"
RBF_SIZE=$(stat -c%s "$FPGA_BINARIES_DIR/ghrd.core.rbf")
python3 -c "import sys;sys.stdout.buffer.write(($RBF_SIZE).to_bytes(4, byteorder='little'))" \
    | cat - "$FPGA_BINARIES_DIR/ghrd.core.rbf" > "$FPGA_BINARIES_DIR/ghrd.core_size.rbf"

# Generate JIC
echo ">>> Generating JIC for $VERSION"
cd "$FPGA_BINARIES_DIR"
cp -f "$PFG_FILE" .
quartus_pfg -c qspi_flash_image_agilex5_boot.pfg
case "$VERSION" in
    single-threaded) JIC_PREFIX="st" ;;
    multi-threaded)  JIC_PREFIX="mt" ;;
esac
cp -f "$FPGA_BINARIES_DIR/qspi_image.jic" "$DATAMOVER_FOLDER/${JIC_PREFIX}-datamover.hps.jic"

echo ">>> $VERSION build complete"
echo ""

echo "==========================================================================="
echo " $VERSION build complete!"
echo "==========================================================================="
