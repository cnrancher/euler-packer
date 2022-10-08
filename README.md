# Packer Build Scripts for openEuler

## Purpose

These scripts are used to create openEuler cloud image for AWS.

## Usage

1. Install build dependencies and prepare.

    - Ensure `make`, `docker`, `awscli`, `jq`, `qemu-utils`, `partprobe` and `fdisk` are installed.
    - Make sure AWS config file `~/.aws/config` is configured or `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables are configured.

2. Preparation
   - Download openEuler qcow2 image and shrink its partition size to 8G, then convert qcow2 image to RAW format.
   - Upload openEuler RAW image to AWS S3 bucket, then create snapshot from this bucket and create base AMI image from this snapshot.

    ``` sh
    AWS_BUCKET_NAME=<bucket_name> \
        OPENEULER_ARCH=<arch_name> \
        OPENEULER_VERSION=<version> \
        AWS_REGION=<region> \
        make prep
    ```

    - Environment variables:
       - `AWS_BUCKET_NAME`: AWS S3 bucket name, required
       - `OPENEULER_ARCH`: openEuler arch, default is x86_64
       - `OPENEULER_VERSION`: openEuler version, default is `22.03-LTS`
       - `AWS_REGION`: AWS region, default is `ap-northeast-1` (Tokyo)

3. Use packer to create AMI image from base AMI image.

    ``` sh
    OPENEULER_VERSION=<version> \
        AWS_BASE_AMI=<base_ami_id> \
        OPENEULER_ARCH=<arch> \
        make build
    ```

    - Environment variables:
      - `OPENEULER_VERSION`: openEuler version, default is `22.03-LTS`
      - `AWS_BASE_AMI`: base AMI id, required if not executed `make prep`
      - `OPENEULER_ARCH`: openEuler arch, default is `x86_64`

4. Finally packer will create a AMI image with its name format `openEuler-<VERSION>-<ARCH>-hvm-<NUMBER>`.

### Environment variables

- `OPENEULER_VERSION`: (required) Version of openEuler, default is `22.03-LTS`.
- `OPENEULER_ARCH`: Architecture of openEuler image, can be `x86_64` or `aarch64`.
- `AWS_BUCKET_NAME`: (required) The name of AWS S3 bucket.
- `AWS_REGION`: The region of AWS, default is `ap-northeast-1`.
- `AWS_BASE_AMI`: (required) Base AMI id used for packer.

    > If you run `make build` after `make prep`, the AWS snapshot and base AMI image is created successfully, the script will read `AWS_BASE_AMI` from log files in `tmp` folder.

## Others

- If `make prep` failed when trying to download/uncompress `qcow.xz` archive file, run `make clean` before re-run `make prep`.

- If `make prep` failed when resizing partition size, and `/dev/nbd0` is loaded on your system, run following command before re-run `make-prep`:

    ``` sh
    sudo qemu-nbd -d /dev/nbd0
    ```

- Currently openEuler aarch64 does not have [ENA](https://github.com/amzn/amzn-drivers/tree/master/kernel/linux/ena) driver installed in kernel, this project use a workaround to download pre-build ENA kernel module from AWS s3 bucket (`s3://${AWS_BUCKET_NAME}/ena.ko`) and install into system when creating openEuler RAW image.

    > Do not delete `/root/ena.ko` or the ec2 instance will failed to connect to the internet.

## License

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
