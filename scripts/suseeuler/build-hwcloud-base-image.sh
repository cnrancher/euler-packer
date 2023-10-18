#!/bin/bash

# Configure and install obsutil before running this script:
# FYI: https://support.huaweicloud.com/utiltg-obs/obs_11_0005.html
# obsutil config -i=<ak> -k=<sk> -e=<endpoint>

set -e

function errcho() {
   >&2 echo $@;
}

# Set working dir to root dir of this project
cd $(dirname $0)/../../
export WORKING_DIR=$(pwd)

if [[ $(uname) == "Darwin" ]]; then
    errcho "macOS is not supported"
    exit 1
fi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: "
    echo "      SUSEEULER_VERSION=<suseEuler_version> SUSEEULER_ARCH=<arch> BUCKET_NAME=<bucket-name> BUCKET_LOCATION=<region> $0"
    echo "Example: "
    echo "      SUSEEULER_VERSION=2.1 SUSEEULER_ARCH=x86_64 BUCKET_NAME=suseeuler-packer BUCKET_LOCATION=cn-east-3 $0"
    exit 0
fi

if [[ -z "${SUSEEULER_VERSION}" ]]; then
    errcho "---- Environment variable SUSEEULER_VERSION required!"
    exit 1
else
    echo "---- SUSEEULER_VERSION: ${SUSEEULER_VERSION}"
fi

if [[ -z "${SUSEEULER_ARCH}" ]]; then
    echo "---- Environment variabe SUSEEULER_ARCH not specified, set to default: aarch64"
    SUSEEULER_ARCH=aarch64
else
    echo "---- SUSEEULER_ARCH: ${SUSEEULER_ARCH}"
fi

if [[ -z "${BUCKET_NAME}" ]]; then
    echo "---- BUCKET_NAME environment variable not specified, set to default: suseeuler-packer"
    BUCKET_NAME="suseeuler-packer"
else
    echo "---- Bucket name: ${BUCKET_NAME}"
fi

if [[ -z "${BUCKET_LOCATION}" ]]; then
    echo "---- BUCKET_LOCATION not found, set to default: cn-east-3"
    BUCKET_LOCATION="cn-east-3"
else
    echo "---- BUCKET_LOCATION: ${BUCKET_LOCATION}"
fi

# Check obsutil is installed or not
type obsutil

# Check obsutil is configured or not
echo "---- Check obsutil is configured or not..."
obsutil ls -s
echo "---- obsutil is configured!"

echo "---- Check bucket is created or not"
if obsutil ls -s obs://${BUCKET_NAME} &> /dev/null ; then
    echo "---- Bucket ${BUCKET_NAME} already created."
else
    echo "---- Creating bucket ${BUCKET_NAME}"
    obsutil mb --location=${BUCKET_LOCATION} obs://${BUCKET_NAME}
    echo "---- Create finished"
fi

# Upload shrinked 8G qcow2 image to bucket
SUSEEULER_IMG="SEL-${SUSEEULER_VERSION}.${SUSEEULER_ARCH}-1.1.0-normal-Build"
echo "---- Upload SHRINKED-${SUSEEULER_IMG}.qcow2 to hwcloud OBS bucket ${BUCKET_NAME} ..."
cd ${WORKING_DIR}/tmp
if [[ ! -e "SHRINKED-${SUSEEULER_IMG}.qcow2" ]]; then
    errcho "SHRINKED-${SUSEEULER_IMG}.qcow2 not found in $(pwd)"
    exit 1
fi
obsutil cp SHRINKED-${SUSEEULER_IMG}.qcow2 obs://${BUCKET_NAME}/SHRINKED-${SUSEEULER_IMG}.qcow2

echo "---- Image upload successfully, please create cloud image for hwcloud manually."
echo "--------- $0 Done. -----------"
