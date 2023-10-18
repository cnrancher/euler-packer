#!/bin/bash
set -ex

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

if [ -z "${SUSEEULER_ARCH}" ]; then
    echo "SUSEEULER_ARCH not specified, set to x86_64"
    SUSEEULER_ARCH="x86_64"
else
    echo "SUSEEULER_ARCH: ${SUSEEULER_ARCH}"
fi

if [[ "${SUSEEULER_ARCH}" == "x86_64" ]]; then
    type qemu-system-x86_64
elif [[ "${SUSEEULER_ARCH}" == "aarch64" ]]; then
    type qemu-system-aarch64
    # TODO: Add aarch64 support
    errcho "aarch64 is not supported yet"
    exit 1
else
    errcho "Unsupported Arch: ${SUSEEULER_ARCH}"
    errcho "Only x86_64 and aarch64 are supported."
    exit 1
fi

if [ -z "${SUSEEULER_VERSION}" ]; then
    SUSEEULER_VERSION="2.1"
    echo "SUSEEULER_VERSION not found, set to default: 2.1"
else
    echo "SUSEEULER_VERSION: ${SUSEEULER_VERSION}"
fi

export SUSEEULER_VERSION=${SUSEEULER_VERSION}
export SUSEEULER_ARCH=${SUSEEULER_ARCH}
export CURRENT_TIME=$(date +"%Y%m%d")
export WORKING_DIR=${WORKING_DIR}
cd $WORKING_DIR/suseeuler/harvester/

if [[ "${SUSEEULER_ARCH}" == "x86_64" ]]; then
    packer init ${FILE:-suseeuler-harvester-x86_64.pkr.hcl}
    packer build ${FILE:-suseeuler-harvester-x86_64.pkr.hcl}
elif [[ "${SUSEEULER_ARCH}" == "aarch64" ]]; then
    # TODO: Add aarch64 support
    # packer init ${FILE:-suseeuler-harvester-arm64.pkr.hcln}
    # packer build ${FILE:-suseeuler-harvester-arm64.pkr.hcln}
    errcho "aarch64 is not supported yet"
else
    errcho "Unsupported Arch: ${SUSEEULER_ARCH}"
    errcho "Only x86_64 and aarch64 are supported."
    exit 1
fi
