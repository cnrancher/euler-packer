#!/bin/bash
set -e

cd `dirname $0`
CLOUD_INIT_SCRIPT=$(realpath `dirname $0`)/install-cloud-init.sh
echo ${CLOUD_INIT_SCRIPT}
source ./vars.sh
cd ${DIST}

echo "---- modprobe nbd max_part=3..."
modprobe nbd max_part=3
echo "---- qemu-nbd..."
nbd_loaded=$(lsblk | grep nbd0 || echo -n "")
if [[ ! -z "${nbd_loaded}" ]]; then
    qemu-nbd -d "${DEV_NUM}"
fi
qemu-nbd -c "${DEV_NUM}" "${OPENEULER_IMG}"
echo "---- Disk layout..."
echo "fdisk:"
fdisk -l "${DEV_NUM}"
echo "lsblk:"
lsblk -f "${DEV_NUM}"

echo "---- Going to do init script to image..."

mount "${DEV_NUM}p2" /mnt
mount "${DEV_NUM}p1" /mnt/boot
mount -o rbind /dev /mnt/dev
mount -t proc none /mnt/proc
mount -t sysfs none /mnt/sys

cat /etc/resolv.conf > /mnt/etc/resolv.conf
cp ${CLOUD_INIT_SCRIPT} /mnt/install-cloud-init.sh

chroot /mnt /install-cloud-init.sh

echo "cleaning up image..."
rm /mnt/etc/resolv.conf
rm /mnt/install-cloud-init.sh

umount $(mount |grep /mnt | awk '{print $3}' | sort -r)

echo "---- Done init image"
# echo "---- Running e2fsck..."
e2fsck -fn ${DEV_NUM}p2
echo "---- Resizing ext4 file system size..."
resize2fs -f ${DEV_NUM}p2 6G
sync

# # Install ENA kernel module for openEuler aarch64
# if [[ "${ARCH}" == "aarch64" && "${VERSION}" == "22.03-LTS" ]]; then
#     echo "----- Installing ENA kernel module for aarch64"
#     # Create a mountpoint folder
#     mkdir -p mnt
#     # Mount root and boot partition to mountpoint
#     mount /dev/nbd0p2 mnt
#     mount /dev/nbd0p1 mnt/boot

#     # Download pre-compiled ENA kernel module from AWS S3 bucket
#     wget "https://starry-ena-driver-openeuler.s3.ap-northeast-1.amazonaws.com/${VERSION}/ena.ko" || echo "----- Download failed"
#     if [[ -e "ena.ko" ]]; then
#         # Move kernel module to root home dir
#         mkdir -p mnt/opt/ena-driver/
#         mv ./ena.ko mnt/opt/ena-driver/
#         # Create configuration for modprobe
#         bash -c ' echo "install ena insmod /opt/ena-driver/ena.ko" >> mnt/etc/modprobe.d/ena.conf '
#         # Auto load module when startup
#         bash -c ' echo "ena" >> mnt/etc/modules-load.d/ena.conf '
#         sync
#         umount -R mnt
#         echo "----- Install finished"
#     else
#         echo "----- Failed to download ena.ko from S3 bucket"
#     fi
# fi

# Add some timeout to avoid device busy error
sleep 3
# Reload partition table to avoid device or resource busy
echo "---- Reloading partition table..."
partprobe ${DEV_NUM}
sleep 3
echo "---- Resizing partition size..."
# Refer: https://superuser.com/questions/332252/how-to-create-and-format-a-partition-using-a-bash-script
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk ${DEV_NUM}
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

sync
qemu-nbd -d ${DEV_NUM}

echo "---- Shrinking qcow2 image size..."
qemu-img resize ${OPENEULER_IMG} --shrink 8G
qemu-img info ${OPENEULER_IMG}

echo "---- Converting ${OPENEULER_IMG} to RAW image..."
qemu-img convert ${OPENEULER_IMG} ${RAW_IMAGE_NAME}

echo "---- Clean up:"
rm ${OPENEULER_IMG}
ls -alh

echo "---- $0 Done."
