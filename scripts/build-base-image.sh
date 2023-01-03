#!/bin/bash
set -e

if [[ "$SKIP_BASE_IMAGE" == "1" ]]; then
    echo "Skipping build base image"
    exit 0
fi

# openEuler arch, can be x86_64 or aarch64
OPENEULER_ARCH="${OPENEULER_ARCH:-x86_64}"
# suseEuler arch, reserved
SUSEEULER_ARCH=""
# openEuler version, e.g. 22.03-LTS
OPENEULER_VERSION="${OPENEULER_VERSION:-22.03-LTS}"
# suseEuler version, reserved
SUSEEULER_VERSION=""
# openEuler mirror
OPENEULER_MIRROR="${OPENEULER_MIRROR:-"https://repo.openeuler.org"}"
# suseEuler mirror, reserved
SUSEEULER_MIRROR=""
# Set working dir
cd $(dirname $0)/../
WORKING_DIR=$(pwd)

if [[ $(uname) == "Darwin" ]]; then
    echo "MacOS is not supported"
    exit 1
fi

# Ensure current dir is `scripts`
cd $WORKING_DIR/scripts/

# Shrink qcow2 image disk size to 8GB and generate base image
VERSION="${OPENEULER_VERSION}" ARCH="${OPENEULER_ARCH}" MIRROR="${OPENEULER_MIRROR}" ./openeuler/build-base-image.sh
# VERSION="${SUSEEULER_VERSION}" ARCH="${SUSEEULER_ARCH}" MIRROR="${SUSE_MIRROR}" ./suseeuler/build-base-image.sh
