#!/bin/bash
set -euo pipefail

# This script should be running in the VM launched by packer

function errcho() {
   >&2 echo $@;
}

function ensure_user_sudo_configured() {
    cloud_init_cfg="/etc/cloud/cloud.cfg"
    system_info_line=$(grep -n "system_info" ${cloud_init_cfg} | cut -d: -f1)
    openeuler_user_line=$(grep -n "name: openeuler" ${cloud_init_cfg} | cut -d: -f1)
    cfg_total_lines=$(wc -l ${cloud_init_cfg} | cut -d' ' -f1)
    openeuler_sudo=$(sed -n "${system_info_line},${cfg_total_lines}p" ${cloud_init_cfg} | grep "sudo:" || true)
    openeuler_group=$(sed -n "${system_info_line},${cfg_total_lines}p" ${cloud_init_cfg} | grep "groups:" || true)
    if [[ -z ${openeuler_sudo:-} ]]; then
        sed -i '/name: openeuler/a \ \ \ \ sudo: ["ALL= (ALL) NOPASSWD: ALL"]' ${cloud_init_cfg}
    fi

    if [[ -z ${openeuler_group:-} ]]; then
        sed -i '/name: openeuler/a \ \ \ \ groups: [wheel, adm, systemd-journal]' ${cloud_init_cfg}
    fi
}

if [ -z "$ARCH" ]; then
    errcho "OPENEULER_ARCH must be set"
    exit 1
fi

echo "----------------------------------------"

# Delete default root password
passwd -d root
passwd -l root

yum -y update
yum -y install cloud-init cloud-utils-growpart gdisk
yum -y install vim tar make zip gzip wget git tmux \
    conntrack-tools socat iptables-services htop open-iscsi \
    qemu-guest-agent

# Disable GRUB Timeout
sed -i 's/GRUB_TIMEOUT=3/GRUB_TIMEOUT=3/g' /etc/default/grub
# Add `apparmor=0` in kernel parameter to disable Apparmor
echo "GRUB_CMDLINE_LINUX_DEFAULT=\"apparmor=0\"" >> /etc/default/grub

# Ensure openeuler user is configured in sudoers
ensure_user_sudo_configured

if [[ "$ARCH" == "x86_64" ]]; then
    grub2-mkconfig -o /boot/grub2/grub.cfg
elif [[ "$ARCH" == "aarch64" ]]; then
    grub2-mkconfig -o /boot/efi/EFI/openEuler/grub.cfg
fi
