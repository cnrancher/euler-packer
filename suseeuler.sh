#!/usr/bin/env bash

set -euo pipefail

cd $(dirname $0)
WORKINGDIR=$(pwd)

function errcho() {
   >&2 echo $@;
}

function suseeuler_aws {
    if [[ -z ${AWS:-} ]]; then
        return
    fi
    if [[ -z "${SUSEEULER_VERSION:-}" ]]; then
        errcho "--version option not provided"
        exit 1
    fi
    if [[ -z "${SUSEEULER_ARCH:-}" ]]; then
        SUSEEULER_ARCH="x86_64"
        echo "--arch option not provided, set to default x86_64"
    fi
    if [[ -z "${AWS_OWNER_ID:-}" ]]; then
        errcho "--aws-owner-id option not provided"
        exit 1
    fi
    if [[ -z "${AWS_BUCKET:-}" ]]; then
        errcho "--aws-bucket option not provided"
        exit 1
    fi

    export SUSEEULER_VERSION=${SUSEEULER_VERSION} \
        SUSEEULER_ARCH=${SUSEEULER_ARCH} \
        BUCKET_NAME=${AWS_BUCKET} \
        AWS_BASE_AMI_OWNER_ID=${AWS_OWNER_ID} \
        SUSEEULER_MIRROR=${SUSEEULER_MIRROR:-}

    ${WORKINGDIR}/scripts/suseeuler/build-base-image.sh
    ${WORKINGDIR}/scripts/suseeuler/build-base-ami.sh
    ${WORKINGDIR}/scripts/suseeuler/build-ami.sh
}

function suseeuler_hwcloud_base {
    if [[ -z ${HWCLOUD_BASE:-} ]]; then
        return
    fi
    if [[ -z "${SUSEEULER_VERSION:-}" ]]; then
        errcho "--version option not provided"
        exit 1
    fi
    if [[ -z "${SUSEEULER_ARCH:-}" ]]; then
        SUSEEULER_ARCH="aarch64"
        echo "--arch option not provided, set to default aarch64"
    fi
    if [[ -z "${OBS_BUCKET:-}" ]]; then
        errcho "--obs-bucket option not provided"
        exit 1
    fi

    export SUSEEULER_VERSION=${SUSEEULER_VERSION} \
        SUSEEULER_ARCH=${SUSEEULER_ARCH} \
        BUCKET_NAME=${OBS_BUCKET} \
        SUSEEULER_MIRROR=${SUSEEULER_MIRROR:-}

    ${WORKINGDIR}/scripts/suseeuler/build-base-image.sh
    ${WORKINGDIR}/scripts/suseeuler/build-hwcloud-base-image.sh
}

function suseeuler_hwcloud {
    if [[ -z ${HWCLOUD:-} ]]; then
        return
    fi
    if [[ -z "${SUSEEULER_VERSION:-}" ]]; then
        errcho "--version option not provided"
        exit 1
    fi
    if [[ -z "${SUSEEULER_ARCH:-}" ]]; then
        SUSEEULER_ARCH="aarch64"
        echo "--arch option not provided, set to default aarch64"
    fi

    export SUSEEULER_VERSION=${SUSEEULER_VERSION} \
        SUSEEULER_ARCH=${SUSEEULER_ARCH}

    ${WORKINGDIR}/scripts/suseeuler/build-hwcloud.sh
}

function suseeuler_harvester {
    if [[ -z ${HARVESTER:-} ]]; then
        return
    fi
    if [[ -z "${SUSEEULER_VERSION:-}" ]]; then
        errcho "--version option not provided"
        exit 1
    fi
    if [[ -z "${SUSEEULER_ARCH:-}" ]]; then
        SUSEEULER_ARCH="x86_64"
        echo "--arch option not provided, set to default x86_64"
    fi

    export SUSEEULER_VERSION=${SUSEEULER_VERSION} \
        SUSEEULER_ARCH=${SUSEEULER_ARCH} \
        SUSEEULER_MIRROR=${SUSEEULER_MIRROR:-}

    ${WORKINGDIR}/scripts/suseeuler/build-base-image.sh
    ${WORKINGDIR}/scripts/suseeuler/build-harvester.sh
}

function usage {
    echo "$0 - 构建 SUSE Euler Linux 云镜像"
    echo
    echo "USAGE: $0 [-h|--help]     显示帮助信息"
    echo '    [--aws]               构建 AWS AMI 镜像'
    echo '    [--hwcloud-base]      构建华为云基础镜像'
    echo '    [--hwcloud]           构建华为云镜像'
    # echo '    [--harvester]         构建 Harvester 镜像'
    echo '    [--version text]      SUSE Euler Linux 系统版本号'
    echo '    [--arch text]         SUSE Euler Linux 系统架构 (x86_64 / aarch64)'
    echo '    [--aws-owner-id text] AWS 帐号 Owner ID'
    echo '    [--aws-bucket text]   AWS S3 存储桶名称'
    echo '    [--obs-bucket text]   华为云 OBS 存储桶名称'
    echo '    [--mirror text]       下载 SUSE Euler Linux qcow2 镜像源'
    echo '    [--debug]             显示调试信息'
    echo
    echo "Example:"
    echo "构建 AWS AMI 镜像："
    echo "$0 \\"
    echo "    --aws \\"
    echo "    --aws-owner-id <OWNER_ID> \\"
    echo "    --version 2.1 \\"
    echo "    --arch x86_64 \\"
    echo "    --aws-bucket <BUCKET_NAME>"
    echo
    echo "构建 HWCloud 基础云镜像 (鲲鹏):"
    echo "$0 \\"
    echo "    --hwcloud-base \\"
    echo "    --version 2.1 \\"
    echo "    --arch aarch64 \\"
    echo "    --obs-bucket <BUCKET_NAME>"
    echo
    echo "构建 HWCloud 公有云镜像 (鲲鹏):"
    echo "$0 \\"
    echo "    --hwcloud \\"
    echo "    --version 2.1 \\"
    echo "    --arch aarch64"
    # echo
    # echo "构建 Harvester 镜像:"
    # echo "$0 \\"
    # echo "    --harvester \\"
    # echo "    --version 2.1 \\"
    # echo "    --arch aarch64"
}

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
    --aws)
        AWS="true"
        shift
        ;;
    --hwcloud)
        HWCLOUD="true"
        shift
        ;;
    --hwcloud-base)
        HWCLOUD_BASE="true"
        shift
        ;;
    --harvester)
        HARVESTER="true"
        shift
        ;;
    --version)
        SUSEEULER_VERSION="$2"
        shift
        shift
        ;;
    --arch)
        SUSEEULER_ARCH="$2"
        shift
        shift
        ;;
    --aws-owner-id)
        AWS_OWNER_ID="$2"
        shift
        shift
        ;;
    --aws-bucket)
        AWS_BUCKET="$2"
        shift
        shift
        ;;
    --obs-bucket)
        OBS_BUCKET="$2"
        shift
        shift
        ;;
    --mirror)
        SUSEEULER_MIRROR="$2"
        shift
        shift
        ;;
    --debug)
        DEBUG_MODE="true"
        set -x
        shift
        ;;
    -h|--help)
        help="true"
        shift
        ;;
    *)
        errcho "Unrecognized option: $key"
        errcho
        usage
        exit 1
        ;;
    esac
done

if [[ ${help:-} ]]; then
    usage
    exit 0
fi

suseeuler_aws
suseeuler_hwcloud_base
suseeuler_hwcloud
suseeuler_harvester
