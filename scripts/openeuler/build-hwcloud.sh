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

if [[ ! -z ${DRY_RUN:-} ]]; then
   echo "Dry-run enabled, skip hwcloud"
   exit 0
fi

if [[ $(uname) == "Darwin" ]]; then
    errcho "macOS is not supported"
    exit 1
fi

# EDIT THESE VARIABLES MANUALLY BEFORE RUN THIS SCRIPT!
export OPENEULER_ARCH="${OPENEULER_ARCH:-aarch64}"
export OPENEULER_VERSION="${OPENEULER_VERSION:-24.03-LTS-SP2}"
export SOURCE_IMAGE_ID=${SOURCE_IMAGE_ID}
export VPC_ID=${VPC_ID}
export SUBNET_ID=${SUBNET_ID}

export CURRENT_TIME=$(date +"%Y%m%d")
export WORKING_DIR=${WORKING_DIR}
cd $WORKING_DIR/openeuler/hwcloud
if [[ "${OPENEULER_ARCH}" == "aarch64" ]]; then
    packer build openeuler-hwcloud-kunpeng.pkr.hcl
else
    errcho "Unsupported Arch: ${OPENEULER_ARCH}"
    errcho "Only aarch64 supported."
    exit 1
fi
