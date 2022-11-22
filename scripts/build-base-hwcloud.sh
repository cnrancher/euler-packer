#!/bin/bash
set -e

if [[ "$SKIP_BASE_HWCLOUD" == "1" ]]; then
    echo "Skipping build base hwcloud image"
    exit 0
fi

# openEuler arch, can be x86_64 or aarch64
export OPENEULER_ARCH="${OPENEULER_ARCH:=aarch64}"
# suseEuler arch, reserved
export SUSEEULER_ARCH=""
# openEuler version, e.g. 22.03-LTS
export OPENEULER_VERSION="${OPENEULER_VERSION:=22.03-LTS}"
# suseEuler version, reserved
export SUSEEULER_VERSION=""
# hwcloud OBS bucket name
export OBS_BUCKET_NAME="${OBS_BUCKET_NAME}"
# Set working dir
cd $(dirname $0)/../
export WORKING_DIR=$(pwd)

if [[ -z "${OBS_BUCKET_NAME}" ]]; then
    echo "OBS_BUCKET_NAME environment required!"
    exit 1
fi

if [[ $(uname) == "Darwin" ]]; then
    echo "MacOS is not supported"
    exit 1
fi

# Ensure current dir is `scripts`
cd $WORKING_DIR/scripts/

# Upload shrinked qcow2 image to hwcloud OBS bucket
VERSION="${OPENEULER_VERSION}" ARCH="${OPENEULER_ARCH}" BUCKET_NAME="${OBS_BUCKET_NAME}" ./openeuler/build-hwcloud-base-image.sh
# VERSION="${SUSEEULER_VERSION}" ARCH="${SUSEEULER_ARCH}" BUCKET_NAME="${OBS_BUCKET_NAME}" ./suseeuler/build-hwcloud-base-image.sh
