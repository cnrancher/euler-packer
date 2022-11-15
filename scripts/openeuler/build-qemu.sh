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
    errcho "MacOS is not supported"
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
    OPENEULER_VERSION="22.03-LTS"
    echo "OPENEULER_VERSION not found, set to default: 22.03-LTS"
else
    echo "OPENEULER_VERSION: ${OPENEULER_VERSION}"
fi

export OPENEULER_VERSION=${OPENEULER_VERSION}
export OPENEULER_ARCH=${OPENEULER_ARCH}
export CURRENT_TIME=$(date +"%Y%m%d-%H%M")
export WORKING_DIR=${WORKING_DIR}
cd $WORKING_DIR/openeuler/qemu/

if [[ "${OPENEULER_ARCH}" == "x86_64" ]]; then
    packer init ${FILE:-openeuler-qeum-x86_64.pkr.hcl}
    packer build ${FILE:-openeuler-qeum-x86_64.pkr.hcl}
elif [[ "${OPENEULER_ARCH}" == "aarch64" ]]; then
    # TODO: Add aarch64 support
    # packer init ${FILE:-openeuler-qeum-arm64.pkr.hcln}
    # packer build ${FILE:-openeuler-qeum-arm64.pkr.hcln}
    errcho "aarch64 is not supported yet"
else
    errcho "Unsupported Arch: ${OPENEULER_ARCH}"
    errcho "Only x86_64 and aarch64 are supported."
    exit 1
fi
