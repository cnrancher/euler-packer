#!/bin/bash

set -e

# Set working dir to root dir of this project
cd $(dirname $0)/../../
export WORKING_DIR=$(pwd)

# Ensure packer is installed
type packer

function errcho() {
   >&2 echo $@;
}

if [[ $(uname) == "Darwin" ]]; then
    errcho "macOS is not supported"
    exit 1
fi

echo "--------------------------------------------------------------------"
echo "Please edit ${WORKING_DIR}/$0 manually before running this script,"
echo "do not publish the security information and keep your password safe!"
echo "--------------------------------------------------------------------"
echo ""

################### PLEASE EDIT THESE VARIABLES MANUALLY BEFORE RUN THIS SCRIPT! ################
###################                  KEEP YOUR PASSWORD SAFE                     ################
export OPENEULER_ARCH="${OPENEULER_ARCH:="aarch64"}"
export OPENEULER_VERSION="${OPENEULER_VERSION:="22.03-LTS"}"

# Environment variable definitions required by hwcloud
# See <https://support.huaweicloud.com/bestpractice-ims/ims_bp_0031.html#section3>
# and <https://developer.hashicorp.com/packer/plugins/builders/openstack>
# identity endpoint (身份鉴别节点地址，格式为：https://IAM的Endpoint/v3)
export HWCLOUD_IDENTITY_ENDPOINT=${HWCLOUD_IDENTITY_ENDPOINT:="https://iam.cn-east-3.myhuaweicloud.com/v3"}
# tenant name (项目名称)
export HWCLOUD_TENANT_NAME="${HWCLOUD_TENANT_NAME:="cn-east-3"}"
# domain name (帐号名)
export HWCLOUD_DOMAIN_NAME="${HWCLOUD_DOMAIN_NAME:=""}"
# IAM username (IAM 用户名)
export HWCLOUD_USERNAME="${HWCLOUD_USERNAME:=""}"
# password of control panel (管理控制台的登录密码)
export HWCLOUD_PASSWORD="${HWCLOUD_PASSWORD:=""}"
# Subnet ID (VPC 的子网网络 ID，注意是子网 ID 不是 VPC ID)
export HWCLOUD_NETWORK_ID="${HWCLOUD_NETWORK_ID:="868c33d4-58fd-439b-88bd-8f30bf8b08a8"}"
# floating IP ID (弹性公网 IP 的 ID，需要手动创建一个弹性公网 IP，之后复制 ID 到此处)
export HWCLOUD_FLOATING_IP_ID="${HWCLOUD_FLOATING_IP_ID:=""}"
# source image ID (源镜像 ID)
export SOURCE_IMAGE_ID="${SOURCE_IMAGE_ID:="81821d0b-55ea-411b-ac12-6c6818a1a41b"}"

export CURRENT_TIME=$(date +"%Y%m%d")
export WORKING_DIR=${WORKING_DIR}
cd $WORKING_DIR/openeuler/hwcloud
if [[ "${OPENEULER_ARCH}" == "aarch64" ]]; then
    packer build openeuler-huawei-kunpeng-arm64.json
elif [[ "" ]]; then
    packer build openeuler-huawei-x86_64.json
else
    errcho "Unsupported Arch: ${OPENEULER_ARCH}"
    errcho "Only aarch64 and x86_64 are supported."
    exit 1
fi
