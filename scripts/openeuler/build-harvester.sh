#!/bin/bash
set -e

# Set working dir to root dir of this project
cd $(dirname $0)/../../
export WORKING_DIR=$(pwd)

# Ensure packer is installed
type packer

function errcho() {
   >&2 echo $@;
}

if [[ $(uname) == "Darwin" ]]; then
    errcho "macOS is not supported"
    exit 1
fi

if [ -z "${OPENEULER_ARCH}" ]; then
    echo "OPENEULER_ARCH not specified, set to x86_64"
    OPENEULER_ARCH="x86_64"
else
    echo "OPENEULER_ARCH: ${OPENEULER_ARCH}"
fi

if [[ "${OPENEULER_ARCH}" == "x86_64" ]]; then
    type qemu-system-x86_64
elif [[ "${OPENEULER_ARCH}" == "aarch64" ]]; then
    type qemu-system-aarch64
    # TODO: Add aarch64 support
    errcho "aarch64 is not supported yet"
    exit 1
else
    errcho "Unsupported Arch: ${OPENEULER_ARCH}"
    errcho "Only x86_64 and aarch64 are supported."
    exit 1
fi

if [ -z "${OPENEULER_VERSION}" ]; then
    OPENEULER_VERSION="24.03-LTS-SP2"
    echo "OPENEULER_VERSION not found, set to default: 24.03-LTS-SP2"
else
    echo "OPENEULER_VERSION: ${OPENEULER_VERSION}"
fi

export OPENEULER_VERSION=${OPENEULER_VERSION}
export OPENEULER_ARCH=${OPENEULER_ARCH}
export CURRENT_TIME=$(date +"%Y%m%d")
export WORKING_DIR=${WORKING_DIR}
cd $WORKING_DIR/openeuler/harvester/

if [[ "${OPENEULER_ARCH}" == "x86_64" ]]; then
    packer init openeuler-harvester-x86_64.pkr.hcl
    packer build openeuler-harvester-x86_64.pkr.hcl
elif [[ "${OPENEULER_ARCH}" == "aarch64" ]]; then
    # TODO: Add aarch64 support
    # packer init openeuler-harvester-arm64.pkr.hcl
    # packer build openeuler-harvester-arm64.pkr.hcl
    errcho "aarch64 is not supported yet"
else
    errcho "Unsupported Arch: ${OPENEULER_ARCH}"
    errcho "Only x86_64 and aarch64 are supported."
    exit 1
fi
