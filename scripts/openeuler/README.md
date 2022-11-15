# Scripts for build openEuler Images

```
build-ami.sh      - Use packer to build openEuler cloud image from 'base AMI image'.
build-base-ami.sh - Upload RAW image to AWS S3 bucket and build 'base AMI image' from RAW image.
build-qemu.sh     - Use packer to build openEuler qemu image from 'shrinked base qcow2 image'.
build-raw.sh      - Shrink original qcow2 image disk size to 8G and convert it to RAW image
                    (The shrinked qcow2 image won't be deleted)
```
