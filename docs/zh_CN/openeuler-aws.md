# openEuler AWS

使用 `euler-packer` 脚本为 [AWS](https://aws.amazon.com/) 构建 openEuler [AMI](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) 镜像。

默认会在 AWS `ap-northeast-1` (Tokyo) 和 `ca-central-1` (Canada) 区域生成 AMI 镜像，可通过修改 [openeuler/aws/](/openeuler/aws/) 目录下的 Packer 配置文件指定 AMI 的生成区域。

![](../images/generated-ami.png)

## 构建流程

`euler-packer` 脚本构建 openEuler AWS AMI 镜像的流程如下：

1. 构建基础镜像 (base-image)

    1. 下载 openEuler qcow2 格式的虚拟机镜像至本地。
    1. 使用 `qemu-nbd` 将 qcow2 格式的虚拟机镜像分区加载至系统，将总大小为 40G 的磁盘分区调整为 8G。

1. 构建基础 AMI 镜像 (base-ami)

    1. 将调整过分区大小的 qcow2 镜像转换为 RAW 格式，上传至 AWS S3 存储桶。
    1. 将存储桶中的 RAW 镜像创建 Snapshot，之后使用此 Snapshot 创建基础 AMI 镜像 (`DEV-*-BASE`)。

    > 基础 AMI 镜像不包含 `cloud-init` 机制，且未禁用 root 密码登录，基础 AMI 镜像仅用来构建最终的 AMI 镜像或调试使用。

1. 使用 Packer 构建 AMI 镜像

    1. 使用 Packer 启动 “基础 AMI 镜像” EC2 虚拟机。
    1. 在虚拟机中安装 `cloud-init` 等基础软件包，调整内核参数，删除 root 密码等。
    1. 最终将此 EC2 虚拟机的磁盘制作 Snapshot，并制作最终可供使用的 AMI 镜像 (`openEuler-<VERSION>-<ARCH>-hvm-<DATETIME>`)。

## 准备工作

1. Linux 系统

    在构建镜像的过程中，需要使用 `qemu-nbd` 将 qcow2 格式的镜像的分区表加载至系统中，之后对根分区进行缩容和分区表调整，因此 `euler-packer` 的脚本仅支持在 Linux 系统上运行。

    > 本仓库的脚本目前进行开发和调试的系统为 Ubuntu 20.04

1. 安装依赖

    安装运行脚本所需的依赖：`make`, `docker`, `awscli`, `jq`, `qemu-utils`, `partprobe` (`parted`), `packer`, `fdisk`

    ```sh
    # Ubuntu
    sudo apt install make awscli jq qemu-utils parted fdisk
    ```

    本仓库的脚本所使用的 Packer 版本需要大于等于 1.7，请按照 [官方教程](https://developer.hashicorp.com/packer/tutorials/docker-get-started/get-started-install-cli#installing-packer) 安装 Packer。

1. 初始化 `awscli` 并配置环境变量

    - 执行 `aws configure`，填写 Access Key ID，Secret Key 并将区域设定为 `ap-northeast-1`。
    - 设定环境变量 `AWS_ACCESS_KEY_ID`，`AWS_SECRET_ACCESS_KEY`。

     ```sh
    # Generate ~/.aws/credential
    aws configure
    # Set environment variables
    export AWS_ACCESS_KEY_ID=<access_key_id>
    export AWS_SECRET_ACCESS_KEY=<secret>
    ```

1. 建立 [AWS S3 存储桶](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html)

    在构建镜像的过程中会将 RAW 格式的 openEuler 镜像上传至此存储桶中，之后为存储桶中的 RAW 镜像创建 Snapshot。

1. 克隆此仓库代码

    ```sh
    git clone https://github.com/cnrancher/euler-packer.git && cd euler-packer
    ```

1. 其他

    构建镜像时，脚本会使用 `date +"%Y%m%d"` 获取时间为 AMI 镜像命名，因此请确保运行此脚本的系统时间和时区设置正确。

## 构建 AMI 镜像

``` sh
#!/usr/bin/env bash

OPENEULER_VERSION=<version> \
    OPENEULER_ARCH=<arch> \
    AWS_BUCKET_NAME=<bucket_name> \
    AWS_BASE_AMI_OWNER_ID=<ower_id> \
    make ami
```

执行 `make ami` 时涉及到的环境变量：

- `AWS_BUCKET_NAME`: AWS S3 存储桶名称（**必须**）
- `AWS_BASE_AMI_OWNER_ID`: AWS 帐号的 Owner ID，当前帐号的 Owner ID 可从 AWS 控制台获取（**必须**）
- `OPENEULER_VERSION`: openEuler 版本号，默认为 `22.03-LTS`
- `OPENEULER_ARCH`: 系统架构，默认为 `x86_64`，可设定为 `x86_64` 或 `aarch64`
- `OPENEULER_MIRROR`: 下载 openEuler qcow2 镜像的镜像源链接，默认为 `https://repo.openeuler.org`

----

最终构建的 AMI 镜像的命名格式为 `openEuler-<VERSION>-<ARCH>-hvm-<DATETIME>`。

## 其他

1. `22.03-LTS` 版本 `aarch64` 架构的 Linux 内核未包含 [ENA](https://github.com/amzn/amzn-drivers/tree/master/kernel/linux/ena) 网卡驱动，在构建此版本 `aarch64` 架构的 openEuler 镜像时会下载已编译好的 ENA 网卡驱动至 `/opt/ena-driver/ena.ko`，并配置 `modprobe` 在开机时自动加载此网卡驱动。

    在使用 AMI 镜像时请勿删除此文件，否则将无法连接至网络。

1. openEuler 一键安装高版本 Docker 脚本 [scripts/others/install-docker.sh](/scripts/others/install-docker.sh)。
