#!/bin/bash
set -e

# openEuler arch, can be x86_64 or aarch64
export OPENEULER_ARCH="${OPENEULER_ARCH:=x86_64}"
# suseEuler arch, reserved
export SUSEEULER_ARCH=""
# openEuler version, e.g. 22.03-LTS
export OPENEULER_VERSION="${OPENEULER_VERSION:=22.03-LTS}"
# suseEuler version, reserved
export SUSEEULER_VERSION=""
# Set working dir
cd $(dirname $0)/../
export WORKING_DIR=$(pwd)

if [[ $(uname) == "Darwin" ]]; then
    echo "MacOS is not supported"
    exit 1
fi

# Ensure current dir is `scripts`
cd $WORKING_DIR/scripts/

# Shrink openEuler qcow2 image size to 8GB and generate a RAW image from it
VERSION="${OPENEULER_VERSION}" ARCH="${OPENEULER_ARCH}" ./openeuler/build-base-image.sh
# VERSION="${SUSEEULER_VERSION}" ARCH="${SUSEEULER_ARCH}" ./suseeuler/build-base-image.sh
