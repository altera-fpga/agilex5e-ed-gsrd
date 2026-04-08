#! /bin/bash

set -e

RBF_FILE=$1
BOOT_SOURCE=$2

echo "Yocto Linux Build Script"
echo "RBF File: $RBF_FILE"
echo "Boot Source: $BOOT_SOURCE"

if [ ! -f "$RBF_FILE" ]; then
    echo "Error: RBF file not found at $RBF_FILE"
    echo "Please build the design first to generate the RBF file."
    exit 1
fi

if [ "$BOOT_SOURCE" != "sd" ] && [ "$BOOT_SOURCE" != "qspi" ] && [ "$BOOT_SOURCE" != "emmc" ] && [ "$BOOT_SOURCE" != "nand" ]; then
    echo "Error: Boot source must be 'sd', 'qspi', 'emmc', or 'nand'"
    echo "Usage: $0 <RBF_FILE> <BOOT_SOURCE>"
    echo "  BOOT_SOURCE: 'sd', 'qspi', 'emmc', or 'nand'"
    exit 1
fi

# Read REVISION_NAMES from project_config.mk
PROJECT_CONFIG="../../project_config.mk"
if [ ! -f "$PROJECT_CONFIG" ]; then
    echo "Error: project_config.mk not found at $PROJECT_CONFIG"
    exit 1
fi

# Extract REVISION_NAMES - look for the line after REVISION_NAMES := \
REVISION_NAME=$(awk '
    /^REVISION_NAMES[[:space:]]*:?=[[:space:]]*\\?/ { in_block=1; next }
    in_block && /^[[:space:]]+[a-zA-Z0-9_-]+/ {
        gsub(/^[[:space:]]+/, "");
        gsub(/[[:space:]]*\\[[:space:]]*$/, "");
        print $1;
        exit
    }
' "$PROJECT_CONFIG")

if [ -z "$REVISION_NAME" ]; then
    echo "Error: Could not extract REVISION_NAME from $PROJECT_CONFIG"
    exit 1
fi

echo "Using revision name: $REVISION_NAME"

# Copy the RBF to the meta-custom/recipes-fpga/fpga-bitstream/files directory
cp -f "$RBF_FILE" "meta-custom/recipes-fpga/fpga-bitstream/files/${REVISION_NAME}_hps_debug.core.rbf"

# Create a variable for the PIP proxy if http_proxy is set
if [ -n "$http_proxy" ]; then
    PIP_PROXY="--proxy $http_proxy"
else
    PIP_PROXY=""
fi

if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv --system-site-packages venv
    venv/bin/pip install $PIP_PROXY --no-cache-dir --timeout 90 --trusted-host pypi.org --trusted-host files.pythonhosted.org --upgrade pip
    venv/bin/pip install $PIP_PROXY --no-cache-dir --timeout 90 --trusted-host pypi.org --trusted-host files.pythonhosted.org kas
    venv/bin/pip install $PIP_PROXY --no-cache-dir --timeout 90 --trusted-host pypi.org --trusted-host files.pythonhosted.org kconfiglib
fi

echo "Activating virtual environment..."
source venv/bin/activate

# Set the umask to ensure files are created with the correct permissions
umask 022

if [ "$BOOT_SOURCE" = "sd" ] || [ "$BOOT_SOURCE" = "emmc" ]; then
    echo "Preparing to sync layers and parse recipes"
    kas shell kas.yml -c "bitbake -p"

    echo "Preparing to build"
    kas shell kas.yml -c "bitbake console-image-minimal gsrd-console-image"
elif [ "$BOOT_SOURCE" = "nand" ]; then
    echo "Preparing to sync layers and parse recipes"
    kas shell kas.yml -c "bitbake -p"

    echo "Preparing to build"
    kas shell kas.yml -c "bitbake console-image-minimal"
elif [ "$BOOT_SOURCE" = "qspi" ]; then
    echo "Preparing to sync layers and parse recipes"
    kas shell kas.yml:qspi_boot_src.yml -c "bitbake -p"

    echo "Preparing to build"
    kas shell kas.yml:qspi_boot_src.yml -c "bitbake console-image-minimal"
fi

echo "Build completed successfully."

