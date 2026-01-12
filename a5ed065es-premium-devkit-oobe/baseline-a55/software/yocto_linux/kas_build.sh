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

if [ "$BOOT_SOURCE" != "sd" ] && [ "$BOOT_SOURCE" != "qspi" ]; then
    echo "Error: Boot source must be 'sd' or 'qspi'"
    echo "Usage: $0 <RBF_FILE> <BOOT_SOURCE>"
    echo "  BOOT_SOURCE: 'sd' or 'qspi'"
    exit 1
fi

# Copy the RBF to the meta-custom/recipes-fpga/fpga-bitstream/files directory
cp -f $RBF_FILE meta-custom/recipes-fpga/fpga-bitstream/files/baseline_a55_hps_debug.core.rbf

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

if [ "$BOOT_SOURCE" = "sd" ]; then
    echo "Preparing to sync layers and parse recipes"
    kas shell kas.yml -c "bitbake -p"

    echo "Preparing to build"
    kas shell kas.yml -c "bitbake console-image-minimal gsrd-console-image"
elif [ "$BOOT_SOURCE" = "qspi" ]; then
    echo "Preparing to sync layers and parse recipes"
    kas shell kas.yml:qspi_boot_src.yml -c "bitbake -p"

    echo "Preparing to build"
    kas shell kas.yml:qspi_boot_src.yml -c "bitbake console-image-minimal"
fi

echo "Build completed successfully."

