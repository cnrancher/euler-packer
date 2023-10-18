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
    echo "      SUSEEULER_VERSION=<SUSE_Euler_version> SUSEEULER_ARCH=<arch> $0"
    echo "Example: "
    echo "      SUSEEULER_VERSION=2.1 SUSEEULER_ARCH=x86_64 $0"
    exit 0
fi

# Ensure utils are installed
type qemu-img > /dev/null
type qemu-nbd > /dev/null
type partprobe > /dev/null
type resizepart > /dev/null
type fdisk > /dev/null
type sfdisk > /dev/null
type e2fsck > /dev/null
type parted > /dev/null
type resize2fs > /dev/null

if [[ -z "${SUSEEULER_VERSION}" ]]; then
    errcho "---- Failed to shrink disk size: environment SUSEEULER_VERSION required!"
    exit 1
else
    echo "---- SUSEEULER_VERSION: ${SUSEEULER_VERSION}"
fi

if [[ -z "${SUSEEULER_ARCH}" ]]; then
    echo "---- environment SUSEEULER_ARCH not specified, set to default: x86_64"
    SUSEEULER_ARCH=x86_64
else
    echo "---- SUSEEULER_ARCH: ${SUSEEULER_ARCH}"
fi

SUSEEULER_MIRROR=${SUSEEULER_MIRROR:-"https://repo.suseeuler.net"}

SUSEEULER_IMG="SEL-${SUSEEULER_VERSION}.${SUSEEULER_ARCH}-1.1.0-normal-Build"
SUSEEULER_DOWNLOAD_LINK="${SUSEEULER_MIRROR%/}/SEL:/${SUSEEULER_VERSION}:/Images/images_update/${SUSEEULER_IMG}.qcow2"

# Download qcow2 image to tmp folder
mkdir -p $WORKING_DIR/tmp && cd $WORKING_DIR/tmp
if [[ -e "SHRINKED-${SUSEEULER_IMG}.qcow2" ]]; then
    echo "---- SHRINKED-${SUSEEULER_IMG}.qcow2 already exists, delete and re-create it?"
    read -p "---- [y/N]: " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 0
    rm SHRINKED-${SUSEEULER_IMG}.qcow2
fi

if [[ -e "${SUSEEULER_IMG}.qcow2.backup" ]]; then
    echo "---- ${SUSEEULER_IMG}.qcow2.backup already exists, skip download..."
else
    if [[ -e "${SUSEEULER_IMG}.qcow2" ]]; then
        echo "---- ${SUSEEULER_IMG}.qcow2 already exists, skip download..."
    else
        echo "---- Downloading image..."
        wget "${SUSEEULER_DOWNLOAD_LINK}"
    fi
    cp ${SUSEEULER_IMG}.qcow2 ${SUSEEULER_IMG}.qcow2.backup
fi

if [[ ! -f "${SUSEEULER_IMG}.qcow2" ]]; then
    cp ${SUSEEULER_IMG}.qcow2.backup ${SUSEEULER_IMG}.qcow2
fi

DEV_NUM="/dev/nbd1"
echo "---- modprobe nbd max_part=8..."
sudo modprobe nbd max_part=8
echo "---- qemu-nbd..."
nbd_loaded=$(lsblk | grep ${DEV_NUM#"/dev/"} || true)
if [[ ! -z "${nbd_loaded}" ]]; then
    sudo qemu-nbd -d "${DEV_NUM}"
fi
sudo qemu-nbd -c "${DEV_NUM}" "${SUSEEULER_IMG}.qcow2"
echo "---- Disk layout"
echo "fdisk:"
sudo fdisk -l "${DEV_NUM}"
echo "---- Finding root disk partition"
PARTITION=$(sudo fdisk -l | grep $DEV_NUM | grep "Linux filesystem" | cut -d ' ' -f 1 || true)
if [[ -z $PARTITION ]]; then
    errcho "failed to get partition num"
    exit 1
fi
echo "---- root partition: $PARTITION"
echo "---- Running e2fsck"
sudo e2fsck -fy ${PARTITION} || true # Ignore error
echo "---- Resizing ext4 file system size..."
sudo resize2fs ${PARTITION} 5G
sudo sync

# Add some timeout to avoid device busy error
sleep 1
# Reload partition table to avoid device or resource busy
echo "---- Reloading partition table..."
sudo partprobe ${DEV_NUM}
sleep 1
echo "---- Resizing partition size..."
echo yes | sudo parted ${DEV_NUM} ---pretend-input-tty resizepart ${PARTITION#"${DEV_NUM}p"} 6GB
sleep 1
echo "---- Resized partition"
sudo fdisk -l ${DEV_NUM}
sudo sync
sleep 1
sudo partprobe ${DEV_NUM}
sleep 1

# Use sfdisk to backup the shrinked partition table.
echo "---- Backup partition table"
sudo sfdisk --dump ${DEV_NUM} > partition-backup.dump
sudo grep -v last-lba partition-backup.dump > partition.dump
echo "---- partition table:"
grep ${DEV_NUM} partition-backup.dump
sleep 1

# Disconnect nbd disk
sudo qemu-nbd -d ${DEV_NUM}
# Shrink qcow2 image size to 8G
echo "---- Shrink qcow2 disk to 8G"
qemu-img resize ${SUSEEULER_IMG}.qcow2 --shrink 8G
sleep 1
# Reconnect nbd disk
sudo qemu-nbd -c "${DEV_NUM}" "${SUSEEULER_IMG}.qcow2"
sleep 1
# Use sfdisk to restore GPT partition table.
echo "---- Restore the partition table"
sudo sfdisk ${DEV_NUM} < partition.dump
echo "---- Restored partition table"
sudo fdisk -l ${DEV_NUM}

# Disconnect nbd disk
sudo qemu-nbd -d ${DEV_NUM}
sleep 1

echo "---- qemu-img info"
qemu-img info ${SUSEEULER_IMG}.qcow2
mv ${SUSEEULER_IMG}.qcow2 SHRINKED-${SUSEEULER_IMG}.qcow2
echo "----"
ls -alh SHRINKED-${SUSEEULER_IMG}.qcow2

echo "---- $0 Done."
