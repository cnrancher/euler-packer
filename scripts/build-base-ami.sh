#!/bin/bash
set -e

if [[ "$SKIP_BASE_AMI" == "1" ]]; then
    echo "Skipping build base AMI image"
    exit 0
fi

# openEuler arch, can be x86_64 or aarch64
OPENEULER_ARCH="${OPENEULER_ARCH:-x86_64}"
# suseEuler arch, reserved
SUSEEULER_ARCH="${SUSEEULER_ARCH:-}"
# openEuler version, e.g. 22.03-LTS
OPENEULER_VERSION="${OPENEULER_VERSION:-22.03-LTS}"
# suseEuler version, reserved
SUSEEULER_VERSION="${SUSEEULER_VERSION:-}"
# AWS s3 bucket name
AWS_BUCKET_NAME="${AWS_BUCKET_NAME:-}"
# Set working dir
cd $(dirname $0)/../
WORKING_DIR=$(pwd)

if [[ -z "${AWS_BUCKET_NAME}" ]]; then
    echo "AWS_BUCKET_NAME environment required!"
    exit 1
fi

if [[ $(uname) == "Darwin" ]]; then
    echo "MacOS is not supported"
    exit 1
fi

# Ensure current dir is `scripts`
cd $WORKING_DIR/scripts/

# Upload RAW image to AWS s3 bucket and create snapshot from it
VERSION="${OPENEULER_VERSION}" \
    ARCH="${OPENEULER_ARCH}" \
    BUCKET_NAME="${AWS_BUCKET_NAME}" \
    ./openeuler/build-base-ami.sh

# VERSION="${SUSEEULER_VERSION}" \
#     ARCH="${SUSEEULER_ARCH}" \
#     BUCKET_NAME="${AWS_BUCKET_NAME}" \
#     ./suseeuler/build-base-ami.sh
