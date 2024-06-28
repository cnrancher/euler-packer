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
type qemu-nbd > /dev/null
type partprobe > /dev/null
type resizepart > /dev/null
type fdisk > /dev/null
type e2fsck > /dev/null
type resize2fs > /dev/null

if [[ -z "${OPENEULER_VERSION}" ]]; then
    errcho "---- Failed to shrink disk size: environment OPENEULER_VERSION required!"
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
echo "---- Running e2fsck"
sudo e2fsck -fy ${PARTITION} || true # Ignore error
echo "---- Resizing ext4 file system size..."
sudo resize2fs ${PARTITION} 4G
sudo sync

# Install ENA kernel module for openEuler aarch64
if [[ "${OPENEULER_ARCH}" == "aarch64" && "${OPENEULER_VERSION}" == "24.03-LTS" ]]; then
    echo "----- Installing ENA kernel module for aarch64"
    # Create a mountpoint folder
    mkdir -p mnt
    # Mount root and boot partition to mountpoint
    sudo mount ${PARTITION} mnt
    sudo mount ${DEV_NUM}p1 mnt/boot

    # Download pre-compiled ENA kernel module from GitHub Release.
    wget "https://github.com/STARRY-S/amzn-drivers/releases/download/${OPENEULER_VERSION}/ena.ko" || echo "----- Download failed"
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
echo yes | sudo parted ${DEV_NUM} ---pretend-input-tty resizepart ${PARTITION#"${DEV_NUM}p"} 7.5GB
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

sudo qemu-nbd -d ${DEV_NUM}

echo "---- Shrinking qcow2 image size..."
qemu-img resize ${OPENEULER_IMG}.qcow2 --shrink 8G
qemu-img info ${OPENEULER_IMG}.qcow2
echo "---- Finished"
echo ""

sudo qemu-nbd -c "${DEV_NUM}" "${OPENEULER_IMG}.qcow2"

# Use sfdisk to restore GPT partition table.
echo "---- Restore the partition table"
sleep 1
sudo sfdisk ${DEV_NUM} < partition.dump
echo "---- Restored partition table"
sudo fdisk -l ${DEV_NUM}

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
