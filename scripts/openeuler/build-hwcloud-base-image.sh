#!/bin/bash

# Configure and install obsutil before running this script:
# FYI: https://support.huaweicloud.com/utiltg-obs/obs_11_0005.html
# obsutil config -i=<ak> -k=<sk> -e=<endpoint>

set -e

function errcho() {
   >&2 echo $@;
}

if [[ ! -z ${DRY_RUN:-} ]]; then
   echo "Dry-run enabled, skip hwcloud-base-image"
   exit 0
fi

# Set working dir to root dir of this project
cd $(dirname $0)/../../
export WORKING_DIR=$(pwd)

if [[ $(uname) == "Darwin" ]]; then
    errcho "macOS is not supported"
    exit 1
fi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: "
    echo "      OPENEULER_VERSION=<openEuler_version> OPENEULER_ARCH=<arch> BUCKET_NAME=<bucket-name> BUCKET_LOCATION=<region> $0"
    echo "Example: "
    echo "      OPENEULER_VERSION=24.03-LTS-SP1 OPENEULER_ARCH=x86_64 BUCKET_NAME=openeuler-packer BUCKET_LOCATION=ap-southeast-1 $0"
    exit 0
fi

if [[ -z "${OPENEULER_VERSION}" ]]; then
    errcho "---- Environment variable OPENEULER_VERSION required!"
    exit 1
else
    echo "---- OPENEULER_VERSION: ${OPENEULER_VERSION}"
fi

if [[ -z "${OPENEULER_ARCH}" ]]; then
    echo "---- Environment variabe OPENEULER_ARCH not specified, set to default: aarch64"
    OPENEULER_ARCH=aarch64
else
    echo "---- OPENEULER_ARCH: ${OPENEULER_ARCH}"
fi

if [[ -z "${BUCKET_NAME}" ]]; then
    echo "---- BUCKET_NAME environment variable not specified, set to default: openeuler-packer"
    BUCKET_NAME="openeuler-packer"
else
    echo "---- Bucket name: ${BUCKET_NAME}"
fi

if [[ -z "${BUCKET_LOCATION}" ]]; then
    echo "---- BUCKET_LOCATION not found, set to default: ap-southeast-1"
    BUCKET_LOCATION="ap-southeast-1"
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
OPENEULER_IMG="openEuler-${OPENEULER_VERSION}-${OPENEULER_ARCH}"
echo "---- Upload SHRINKED-${OPENEULER_IMG}.qcow2 to hwcloud OBS bucket ${BUCKET_NAME} ..."
cd ${WORKING_DIR}/tmp
if [[ ! -e "SHRINKED-${OPENEULER_IMG}.qcow2" ]]; then
    errcho "SHRINKED-${OPENEULER_IMG}.qcow2 not found in $(pwd)"
    exit 1
fi
obsutil cp SHRINKED-${OPENEULER_IMG}.qcow2 obs://${BUCKET_NAME}/SHRINKED-${OPENEULER_IMG}.qcow2

echo "---- Image upload successfully, please create cloud image for hwcloud manually."
echo "--------- $0 Done. -----------"
