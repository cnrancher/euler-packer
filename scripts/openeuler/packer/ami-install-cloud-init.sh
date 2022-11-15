#!/bin/bash
set -e

# This script should be running in the VM launched by packer

function errcho() {
   >&2 echo $@;
}

if [ -z "$VERSION" ]; then
    errcho "OPENEULER_VERSION must be set"
    exit 1
fi

echo "----------------------------------------"

# Delete default root password
passwd -d root
passwd -l root

yum -y update
yum -y install cloud-init cloud-utils-growpart gdisk
yum -y install vim tar make zip gzip wget git tmux \
    conntrack-tools socat iptables-services htop open-iscsi
# Add `apparmor=0` in kernel parameter to disable Apparmor
echo "GRUB_CMDLINE_LINUX_DEFAULT=\"apparmor=0\"" >> /etc/default/grub

if [[ "$ARCH" == "x86_64" ]]; then
    grub2-mkconfig -o /boot/grub2/grub.cfg
elif [[ "$ARCH" == "aarch64" ]]; then
    grub2-mkconfig -o /boot/efi/EFI/openEuler/grub.cfg
fi
