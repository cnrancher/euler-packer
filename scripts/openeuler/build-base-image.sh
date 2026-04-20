#!/bin/bash
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
    echo "      OPENEULER_VERSION=<openEuler_version> OPENEULER_ARCH=<arch> $0"
    echo "Example: "
    echo "      OPENEULER_VERSION=24.03-LTS OPENEULER_ARCH=x86_64 $0"
    exit 0
fi

# Ensure utils are installed
type qemu-img > /dev/null

if [[ -z "${OPENEULER_VERSION}" ]]; then
    errcho "---- environment OPENEULER_VERSION required!"
    exit 1
else
    echo "---- OPENEULER_VERSION: ${OPENEULER_VERSION}"
fi

if [[ -z "${OPENEULER_ARCH}" ]]; then
    echo "---- environment OPENEULER_ARCH not specified, set to default: x86_64"
    OPENEULER_ARCH=x86_64
else
    echo "---- OPENEULER_ARCH: ${OPENEULER_ARCH}"
fi

OPENEULER_MIRROR=${OPENEULER_MIRROR:-"https://repo.openeuler.org"}

OPENEULER_IMG="openEuler-${OPENEULER_VERSION}-${OPENEULER_ARCH}"
OPENEULER_DOWNLOAD_LINK="${OPENEULER_MIRROR%/}/openEuler-${OPENEULER_VERSION}/virtual_machine_img/${OPENEULER_ARCH}/${OPENEULER_IMG}.qcow2.xz"

# Download qcow2 image to tmp folder
mkdir -p $WORKING_DIR/tmp && cd $WORKING_DIR/tmp
if [[ -e "${OPENEULER_IMG}.raw" ]]; then
    echo "---- ${OPENEULER_IMG}.raw already exists, delete and re-create it?"
    if [[ -z ${DRY_RUN:-} ]]; then
        read -p "---- [y/N]: " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 0
    else
        echo "Y"
    fi
    rm ${OPENEULER_IMG}.raw
fi

if [[ -e "${OPENEULER_IMG}.qcow2.backup" ]]; then
    echo "---- ${OPENEULER_IMG}.qcow2.backup already exists, skip uncompress..."
else
    if [[ -e "${OPENEULER_IMG}.qcow2.xz" ]]; then
        echo "---- ${OPENEULER_IMG}.qcow2.xz already exists, skip downloading..."
    else
        echo "---- Downloading image..."
        wget --no-verbose "${OPENEULER_DOWNLOAD_LINK}"
    fi
    echo "---- Uncompressing image ..."
    unxz "${OPENEULER_IMG}.qcow2.xz"
    cp ${OPENEULER_IMG}.qcow2 ${OPENEULER_IMG}.qcow2.backup
fi

if [[ ! -f "${OPENEULER_IMG}.qcow2" ]]; then
    cp ${OPENEULER_IMG}.qcow2.backup ${OPENEULER_IMG}.qcow2
fi

DEV_NUM="/dev/nbd0"
echo "---- modprobe nbd max_part=3..."
sudo modprobe nbd max_part=3
echo "---- qemu-nbd..."
nbd_loaded=$(lsblk | grep ${DEV_NUM#"/dev/"} || true)
if [[ ! -z "${nbd_loaded}" ]]; then
    sudo qemu-nbd -d "${DEV_NUM}"
fi
sudo qemu-nbd -c "${DEV_NUM}" "${OPENEULER_IMG}.qcow2"
sleep 1
echo "---- Disk layout"
echo "fdisk:"
sudo fdisk -l "${DEV_NUM}"
echo "lsblk:"
lsblk -f
echo "---- Finding root disk partition"
PARTITION=$(sudo fdisk -l | grep $DEV_NUM | grep "Linux" | cut -d ' ' -f 1 || true)
if [[ -z $PARTITION ]]; then
    errcho "failed to get partition num"
    exit 1
fi

echo "----- Update kernel parameter to disable multipath & built-in cloud-init"
mkdir -p mnt
sudo mount ${DEV_NUM}p1 mnt
GRUB_CFG_FILE="./mnt/grub2/grub.cfg"
if [[ "${OPENEULER_ARCH}" == "aarch64" ]]; then
    GRUB_CFG_FILE="./mnt/efi/EFI/openEuler/grub.cfg"
fi

sudo sed -i '/root=UUID=/s/$/ loglevel=6 rd.multipath=0 cloud-init=disabled/' $GRUB_CFG_FILE
sudo sed -i 's/quiet//g' $GRUB_CFG_FILE # Enable grub log output.
echo "----- Updated kernel parameter"
sudo cat $GRUB_CFG_FILE | grep rd.multipath
sleep 1
sudo sync
sudo umount mnt

sudo qemu-nbd -d ${DEV_NUM}

mv ${OPENEULER_IMG}.qcow2 SHRINKED-${OPENEULER_IMG}.qcow2
ls -alh SHRINKED-${OPENEULER_IMG}.qcow2

echo "---- $0 Done."
