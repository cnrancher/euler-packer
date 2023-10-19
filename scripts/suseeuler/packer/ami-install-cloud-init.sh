#!/bin/bash
set -e

# This script should be running in the VM launched by packer

function errcho() {
   >&2 echo $@;
}

function ensure_user_sudo_configured() {
    cloud_init_cfg="/etc/cloud/cloud.cfg"
    system_info_line=$(grep -n "system_info" ${cloud_init_cfg} | cut -d: -f1)
    suseeuler_user_line=$(grep -n "name: suseeuler" ${cloud_init_cfg} | cut -d: -f1)
    openeuler_user_line=$(grep -n "name: openeuler" ${cloud_init_cfg} | cut -d: -f1)
    cfg_total_lines=$(wc -l ${cloud_init_cfg} | cut -d' ' -f1)
    suseeuler_sudo=$(sed -n "${system_info_line},${cfg_total_lines}p" ${cloud_init_cfg} | grep "sudo:" || echo -n "")
    suseeuler_group=$(sed -n "${system_info_line},${cfg_total_lines}p" ${cloud_init_cfg} | grep "groups:" || echo -n "")
    if [[ -z ${suseeuler_user_line} ]] && [[ ! -z ${openeuler_user_line} ]]; then
        # Ensure the user created by cloud-init is suseeuler instead of openeuler
        sed -i 's/name: openeuler/name: suseeuler/g' ${cloud_init_cfg}
    fi
    if [[ -z ${suseeuler_sudo} ]]; then
        sed -i '/name: suseeuler/a \ \ \ \ \ sudo: ["ALL= (ALL) NOPASSWD: ALL"]' ${cloud_init_cfg}
    fi

    if [[ -z ${suseeuler_group} ]]; then
        sed -i '/name: suseeuler/a \ \ \ \ \ groups: [wheel, adm, systemd-journal]' ${cloud_init_cfg}
    fi
}

echo "----------------------------------------"

# Delete default root password
passwd -d root
passwd -l root

yum -y --nobest update
yum -y install cloud-init cloud-utils-growpart gdisk\
    vim tar make zip gzip wget git tmux \
    conntrack-tools socat iptables-services htop open-iscsi

# Disable multipath & apparmor for public cloud
sed -i 's/crashkernel=512M/crashkernel=512M apparmor=0 rd.multipath=0/' /etc/default/grub
echo "GRUB config CMDLINE_LINUX_DEFAULT:"
cat /etc/default/grub | grep CMDLINE_LINUX_DEFAULT

# Ensure suseeuler user is configured in sudoers
ensure_user_sudo_configured

grub2-mkconfig -o /boot/grub2/grub.cfg
