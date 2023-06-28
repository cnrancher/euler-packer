#!/bin/bash
set -e

function errcho() {
   >&2 echo $@;
}

# Set working dir to root dir of this project
cd $(dirname $0)/../../
export WORKING_DIR=$(pwd)

if [[ $(uname) == "Darwin" ]]; then
    errcho "MacOS is not supported"
    exit 1
fi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: "
    echo "      VERSION=<openEuler_version> ARCH=<arch> $0"
    echo "Example: "
    echo "      VERSION=22.03-LTS ARCH=x86_64 $0"
    exit 0
fi

# Ensure qemu-utils installed
type qemu-img
type qemu-nbd
# Ensure partprobe exists
type partprobe

if [[ -z "${VERSION}" ]]; then
    errcho "---- Failed to shrink disk size: environment VERSION required!"
    exit 1
else
    echo "---- VERSION: ${VERSION}"
fi

if [[ -z "${ARCH}" ]]; then
    echo "---- environment ARCH not specified, set to default: x86_64"
    ARCH=x86_64
else
    echo "---- ARCH: ${ARCH}"
fi

MIRROR=${MIRROR:-"https://repo.openeuler.org"}

OPENEULER_IMG="openEuler-${VERSION}-${ARCH}"
OPENEULER_DOWNLOAD_LINK="${MIRROR%/}/openEuler-${VERSION}/virtual_machine_img/${ARCH}/${OPENEULER_IMG}.qcow2.xz"

# Download qcow2 image to tmp folder
mkdir -p $WORKING_DIR/tmp && cd $WORKING_DIR/tmp
if [[ -e "${OPENEULER_IMG}.raw" ]]; then
    echo "---- ${OPENEULER_IMG} already exists, delete and re-create it?"
    read -p "---- [y/N]: " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 0
    rm ${OPENEULER_IMG}.raw
fi

if [[ -e "${OPENEULER_IMG}.qcow2.backup" ]]; then
    echo "---- ${OPENEULER_IMG}.qcow2.backup already exists, skip uncompress..."
else
    if [[ -e "${OPENEULER_IMG}.qcow2.xz" ]]; then
        echo "---- ${OPENEULER_IMG}.qcow2.xz already exists, skip downloading..."
    else
        echo "---- Downloading image..."
        wget "${OPENEULER_DOWNLOAD_LINK}"
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
nbd_loaded=$(lsblk | grep nbd0 || echo -n "")
if [[ ! -z "${nbd_loaded}" ]]; then
    sudo qemu-nbd -d "${DEV_NUM}"
fi
sudo qemu-nbd -c "${DEV_NUM}" "${OPENEULER_IMG}.qcow2"
echo "---- Disk layout..."
echo "fdisk:"
sudo fdisk -l "${DEV_NUM}"
echo "lsblk:"
lsblk -f
echo "---- Running e2fsck..."
sudo e2fsck -fy ${DEV_NUM}p2 || echo "" # Ignore error
echo "---- Resizing ext4 file system size..."
sudo resize2fs ${DEV_NUM}p2 6G
sudo sync

# Install ENA kernel module for openEuler aarch64
if [[ "${ARCH}" == "aarch64" && "${VERSION}" == "22.03-LTS" ]]; then
    echo "----- Installing ENA kernel module for aarch64"
    # Create a mountpoint folder
    mkdir -p mnt
    # Mount root and boot partition to mountpoint
    sudo mount ${DEV_NUM}p2 mnt
    sudo mount ${DEV_NUM}p1 mnt/boot

    # Download pre-compiled ENA kernel module from GitHub Release.
    wget "https://github.com/STARRY-S/amzn-drivers/releases/download/${VERSION}/ena.ko" || echo "----- Download failed"
    if [[ -e "ena.ko" ]]; then
        # Move kernel module to root home dir
        sudo mkdir -p mnt/opt/ena-driver/
        sudo mv ./ena.ko mnt/opt/ena-driver/
        # Create configuration for modprobe
        sudo bash -c ' echo "install ena insmod /opt/ena-driver/ena.ko" >> mnt/etc/modprobe.d/ena.conf '
        # Auto load module when startup
        sudo bash -c ' echo "ena" >> mnt/etc/modules-load.d/ena.conf '
        sudo sync
        sudo umount -R mnt
        echo "----- Install finished"
    else
        echo "----- Failed to download ena.ko"
    fi
fi

# Add some timeout to avoid device busy error
sleep 1
# Reload partition table to avoid device or resource busy
echo "---- Reloading partition table..."
sudo partprobe ${DEV_NUM}
sleep 1
echo "---- Resizing partition size..."
# Reset fdisk error status
echo -n "0" > $WORKING_DIR/tmp/fdisk_failed_ioctl
# Refer: https://superuser.com/questions/332252/how-to-create-and-format-a-partition-using-a-bash-script
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | sudo fdisk ${DEV_NUM} || echo -n "1" > $WORKING_DIR/tmp/fdisk_failed_ioctl
  p # print current partition
  d # delete partition
  2 # partition number 2
  n # create new partition
  p # partition type primary
  2 # partition number 2
    # default start position
  +6G # 6G for root partition
  w # sync changes to disk
  p # print partition
  q # done
EOF

sudo sync
sleep 1
sudo partprobe ${DEV_NUM}
sleep 1

echo "---- Check fdisk command succeed or not"
cd $WORKING_DIR/tmp/
# If fdisk failed with device busy error, check the root partition is resized to 6G or not
if [[ "$(cat fdisk_failed_ioctl)" == "1" ]]; then
    echo "---- fdisk executes failed, check root device is shinked to 6G or not"
    check_root_size=$(lsblk | grep p2 | grep 6G || echo "")
    if [[ -z ${check_root_size} ]]; then
        lsblk
        errcho "---- Failed to shrink root partition size to 6G"
        exit 1
    fi
    echo "---- root partition already shrinked to 6G"
fi

sudo qemu-nbd -d ${DEV_NUM}

echo "---- Shrinking qcow2 image size..."
qemu-img resize ${OPENEULER_IMG}.qcow2 --shrink 8G
qemu-img info ${OPENEULER_IMG}.qcow2
echo "---- Finished"
echo ""

mv ${OPENEULER_IMG}.qcow2 SHRINKED-${OPENEULER_IMG}.qcow2
ls -alh SHRINKED-${OPENEULER_IMG}.qcow2

echo "---- $0 Done."
