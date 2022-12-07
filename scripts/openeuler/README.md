# Scripts for build openEuler Images

```
build-ami.sh                - Use packer to build openEuler cloud image from 'base AMI image'.
build-base-ami.sh           - Convert base qcow2 image to RAW and upload it to AWS S3 bucket and build base AMI image from RAW image.
build-base-image.sh         - Shrink original qcow2 image disk size to 8G
                              (The shrinked qcow2 image won't be deleted)
build-hwcloud-base-image.sh - Upload base image to Huawei cloud OBS Bucket
build-hwcloud.sh            - Create huawei cloud image from the base image uploaded to OBS Bucket
build-harvester.sh          - Use packer to build openEuler harvester image from 'shrinked base qcow2 image'.
```
