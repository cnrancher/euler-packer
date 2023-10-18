# SUSE Euler Linux Huawei Cloud

使用 `euler-packer` 项目的脚本为 [华为云](https://www.huaweicloud.com/intl/zh-cn/) 构建 SUSE Euler Linux 镜像。

![](/docs/images/suseeuler/generated-hwcloud-image.png)

本仓库的脚本会在 **华东-上海一** 区生成供鲲鹏 CPU 使用的 ARM64 架构的镜像。

可通过修改 [suseeuler/hwcloud/](/suseeuler/hwcloud/) 目录下的 Packer 配置文件指定镜像的生成区域。

## 构建流程

构建流程与 [openEuler 华为云镜像构建流程](./openeuler-hwcloud.md#构建流程) 一致。

## 准备工作

1. Linux 系统

    在构建镜像的过程中，需要使用 `qemu-nbd` 将 qcow2 格式的镜像的分区表加载至系统中，之后对根分区进行缩容和分区表调整，因此 `euler-packer` 的脚本仅支持在 Linux 系统上运行。

    > 本仓库的脚本使用系统 Debian 12

1. 安装依赖

    安装运行脚本所需的依赖：`docker`, `awscli`, `jq`, `qemu-utils`, `partprobe` (`parted`), `packer`, `fdisk`, `obsutil`

    ```sh
    # Ubuntu / Debian
    sudo apt install awscli jq qemu-utils parted fdisk util-linux
    ```

    本仓库的脚本所使用的 Packer 建议版本为 1.7，请按照 [官方教程](https://developer.hashicorp.com/packer/tutorials/docker-get-started/get-started-install-cli#installing-packer) 安装 Packer。

    安装 `obsutil` 的教程请参考 [OBS 简介](https://support.huaweicloud.com/utiltg-obs/obs_11_0001.html)。

1. 初始化 `obsutil`

    设定 `obsutil` 的默认 endpoint 为 `cn-east-3` (华东-上海一区)。

    ```sh
    obsutil config -i=<AK> -k=<SK> -e=obs.cn-east-3.myhuaweicloud.com
    ```

    可使用 `obsutil ls` 检查是否配置成功。

1. 建立 [OBS 存储桶](https://support.huaweicloud.com/obs/index.html)，用于储存 qcow2 镜像。

1. 克隆此仓库代码

    ```sh
    git clone https://github.com/cnrancher/euler-packer.git && cd euler-packer
    ```

1. 其他

    构建镜像时，脚本会使用 `date +"%Y%m%d"` 获取时间为镜像命名，因此请确保运行此脚本的系统时间和时区设置正确。

## 构建华为云镜像

1. 构建 `qcow2` 格式的基础镜像并上传至华为云 OBS 存储桶。

    ```bash
    ./suseeuler.sh \
        --hwcloud-base \
        --version 2.1 \
        --arch aarch64 \
        --obs-bucket <BUCKET_NAME>
    ```

    执行脚本的参数：
    - `--version`: SUSE Euler 版本号（**必须**）
    - `--arch`: 系统架构，默认为 `aarch64`，目前仅支持 `aarch64` 架构
    - `--obs-bucket`: 华为云 OBS 存储桶名称

1. 手动在华为云 *IMS 镜像服务* 页面创建基础云镜像。

    ![](../images/suseeuler/build-base-hwcloud.png)

    为了保持统一，将基础云镜像的名称格式设定为：`DEV-SEL-<VERSION>-<ARCH>-<DATETIME>-BASE`

    ![](../images/suseeuler/build-base-hwcloud-2.png)

1. 参照 [华为云文档 - 使用Packer创建私有镜像](https://support.huaweicloud.com/bestpractice-ims/ims_bp_0031.html#section3) 设定下方所需的环境变量，执行脚本，使用 Packer 构建华为云镜像。

    ```bash
    #!/bin/bash

    # See <https://support.huaweicloud.com/bestpractice-ims/ims_bp_0031.html#section3>
    # and <https://developer.hashicorp.com/packer/plugins/builders/openstack>

    # identity endpoint (身份鉴别节点地址，格式为：https://IAM的Endpoint/v3)
    export HWCLOUD_IDENTITY_ENDPOINT="https://iam.cn-east-3.myhuaweicloud.com/v3"
    # tenant name (项目名称)
    export HWCLOUD_TENANT_NAME="cn-east-3"
    # domain name (主帐号名)
    export HWCLOUD_DOMAIN_NAME="<USER_NAME>"
    # IAM username (IAM 用户名)
    export HWCLOUD_USERNAME="<IAM_USER_NAME>"
    # password of control panel (管理控制台的登录密码)
    export HWCLOUD_PASSWORD="<IAM_USER_LOGIN PASSWD>"
    # Subnet ID (子网网络 ID)
    export HWCLOUD_NETWORK_ID="<SUBNET_ID>"
    # EIP ID (弹性公网 IP 的 ID，需要手动创建一个弹性公网 IP，之后复制 ID 到此处)
    export HWCLOUD_FLOATING_IP_ID="<EIP_ID>"
    # source image ID (源镜像 ID)
    export SOURCE_IMAGE_ID="<SOURCE_IMAGE_ID>"

    ./suseeuler.sh \
        --hwcloud \
        --version 2.1 \
        --arch aarch64
    ```

----

最终构建的 AMI 镜像可于 *IMS 镜像服务* 页面获取到，命名格式为：`SUSE-Euler-Linux-<VERSION>-<ARCH>-<DATETIME>`
