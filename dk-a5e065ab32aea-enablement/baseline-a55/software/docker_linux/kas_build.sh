#! /bin/bash

set -e

RBF_FILE=$1
BOOT_SOURCE=$2
export DOCKER_BUILD=1

echo "Script for Docker support in Yocto Linux Builds"

if [ "$BOOT_SOURCE" != "sd" ]; then
    echo "Error: Docker Framework is only supported with SD boot source"
    echo "Cannot use DOCKER_BUILD=1 with boot source: $BOOT_SOURCE"
    exit 1
fi

echo "RBF File: $RBF_FILE"
echo "Boot Source: $BOOT_SOURCE"
echo "Docker Framework: ${DOCKER_BUILD}"

if [ ! -f "$RBF_FILE" ]; then
    echo "Error: RBF file not found at $RBF_FILE"
    echo "Please build the design first to generate the RBF file."
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
cp -f "$RBF_FILE" "meta-custom/recipes-fpga/fpga-bitstream/files/${REVISION_NAME}.core.rbf"

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

KAS_YML_FILE="kas.yml"
# Extend the YML_FILE as we are building with Docker Framework
KAS_YML_FILE+=":docker_enable.yml"
echo "YML file spec for this kas build is: ${KAS_YML_FILE}"
echo "Preparing to sync layers and parse recipes"
kas shell ${KAS_YML_FILE} -c "bitbake -p"

echo "Starting build"
set +e
kas shell ${KAS_YML_FILE} -c "bitbake console-image-minimal gsrd-console-image"
retcode=$?
set -e
if [ ${retcode} -eq 0 ]; then
    DOCKER_CONTAINER_BUILD_LOGS_PATH=$(ls -d build/tmp/work/*/docker-container-support/*/temp 2>/dev/null | head -n 1)
    if [ -n "${DOCKER_CONTAINER_BUILD_LOGS_PATH}" ]; then
         FETCH_LOG=${DOCKER_CONTAINER_BUILD_LOGS_PATH}/log.do_fetch_images
         WRITE_BOOT_SCRIPT_LOG=${DOCKER_CONTAINER_BUILD_LOGS_PATH}/log.do_write_boot_script
         INSTALL_LOG=${DOCKER_CONTAINER_BUILD_LOGS_PATH}/log.do_install
         grep -h DOCKER_CONTAINER_BUILD_REPORT ${FETCH_LOG} ${WRITE_BOOT_SCRIPT_LOG} ${INSTALL_LOG} || true
    fi
    echo "Build completed."
fi
exit ${retcode}
