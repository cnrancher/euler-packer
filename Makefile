.default:
	@echo "Usage:"
	@echo "    make ami        - Create 'AMI image' from the base AMI image by using packer"
	@echo "    make qemu       - Create qemu 'acow2 image' by using packer"
	@echo "    make clean      - Delete temporary files in 'tmp'"

# base-image will generate a base qcow2 image at tmp/SHRINKED-*.qcow2
base-image:
	./scripts/build-base-image.sh

# base-ami will create a BASE AMI cloud image
base-ami: base-image
	./scripts/build-base-ami.sh

# ami: Generate a AWS ami image with name format 'openEuler-<VERSION>-<ARCH>-hvm-<DATETIME>'
# use SKIP_BASE_AMI=1 to skip build base AMI image.
ami: base-ami
	./scripts/openeuler/build-ami.sh

qemu: base-image
	./scripts/openeuler/build-qemu.sh

clean:
	./scripts/clean.sh

.DEFAULT_GOAL := .default

.PHONY: base-image base-ami ami qemu clean
