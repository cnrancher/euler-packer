#!/bin/bash
set -e

cd $(dirname $0)
basedir=${PWD}
source ./vars.sh

mkdir -p ${DIST}

function errcho() {
   >&2 echo $@;
}

echo "---- VERSION: ${VERSION}"
echo "---- ARCH: ${ARCH}"

OPENEULER_DOWNLOAD_BASE="${DOWNLOAD_MIRROR}/openEuler-${VERSION}/virtual_machine_img/${ARCH}"

# Download qcow2 image to tmp folder
cd ${DIST}
if [[ -e "${RAW_IMAGE_NAME}" ]]; then
    echo "---- ${OPENEULER_IMG} already exists, delete and re-create it?"
    read -p "---- [y/N]: " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 0
    rm ${RAW_IMAGE_NAME}
fi

if [[ -e "${BACKUP_IMAGE_NAME}" ]]; then
    echo "---- ${BACKUP_IMAGE_NAME} already exists, skip uncompress..."
    ## restore from backup
    if [[ ! -f "${OPENEULER_IMG}" ]]; then
        cp ${BACKUP_IMAGE_NAME} ${OPENEULER_IMG}
    fi
else
    echo "---- Downloading image..."
    for file in "${OPENEULER_IMG}.xz" "${CHECKSUM_FILE}"; do 
        wget "${OPENEULER_DOWNLOAD_BASE}/${file}";
    done
    sha256sum -c "${CHECKSUM_FILE}"
    xz -d "${OPENEULER_IMG}.xz"
    cp ${OPENEULER_IMG} ${BACKUP_IMAGE_NAME}
fi

