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

if [[ -z "${AWS_ACCESS_KEY_ID}" || -z "${AWS_SECRET_ACCESS_KEY}" ]]; then
    errcho "AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be set"
    exit 1
fi

if [ -z "${SUSEEULER_VERSION}" ]; then
    errcho "SUSEEULER_VERSION not set"
    exit 1
else
    echo "SUSEEULER_VERSION: ${SUSEEULER_VERSION}"
fi

if [ -z "${AWS_BASE_AMI}" ]; then
    if [ -e "${WORKING_DIR}/tmp/register-image.txt" ]; then
        echo "AWS_BASE_AMI environment not found, read from tmp folder"
        AWS_BASE_AMI=$(cat ${WORKING_DIR}/tmp/register-image.txt | jq -r ".ImageId")
        if [ -z "$AWS_BASE_AMI" ]; then
            echo "Read failed"
            exit 1
        fi
        echo "Found AWS_BASE_AMI: $AWS_BASE_AMI"
    else
        echo "AWS_BASE_AMI environment variable must be specified!"
        exit 1
    fi
else
    echo "AWS_BASE_AMI: ${AWS_BASE_AMI}"
fi

if [ -z "${AWS_BASE_AMI_OWNER_ID}" ]; then
    errcho "AWS_BASE_AMI_OWNER_ID environment variable must be specified!"
    exit 1
fi

if [ -z "${SUSEEULER_ARCH}" ]; then
    echo "SUSEEULER_ARCH not specified, set to x86_64"
    SUSEEULER_ARCH="x86_64"
else
    echo "SUSEEULER_ARCH: ${SUSEEULER_ARCH}"
fi

export SUSEEULER_ARCH=${SUSEEULER_ARCH}
export SUSEEULER_VERSION=${SUSEEULER_VERSION}
export AWS_BASE_AMI=${AWS_BASE_AMI}
export AWS_BASE_AMI_OWNER_ID=${AWS_BASE_AMI_OWNER_ID}
export CURRENT_TIME=$(date +"%Y%m%d")
export WORKING_DIR=${WORKING_DIR}
cd $WORKING_DIR/suseeuler/aws
if [[ "${SUSEEULER_ARCH}" == "x86_64" ]]; then
    packer build ${FILE:-suseeuler-aws-amis-x86_64.json}
elif [[ "${SUSEEULER_ARCH}" == "aarch64" ]]; then
    packer build ${FILE:-suseeuler-aws-amis-arm64.json}
else
    errcho "Unsupported Arch: ${SUSEEULER_ARCH}"
    errcho "Only x86_64 and aarch64 are supported."
    exit 1
fi
