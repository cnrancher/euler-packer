#!/bin/bash

ARCH=${ARCH:-`uname -m`}
ARCH_COMMON=${ARCH_COMMON:-amd64}
VERSION=${VERSION:-22.03-LTS}
OPENEULER_IMG=${OPENEULER_IMG:-"openEuler-${VERSION}-${ARCH}.qcow2"}
RAW_IMAGE_NAME="$(basename ${OPENEULER_IMG} .qcow2).raw"
BACKUP_IMAGE_NAME="${OPENEULER_IMG}.backup"
CHECKSUM_FILE="${OPENEULER_IMG}.xz.sha256sum"
DOWNLOAD_MIRROR=${DOWNLOAD_MIRROR:-"https://repo.openeuler.org"}
DIST=../dist
DEV_NUM="/dev/nbd0"
