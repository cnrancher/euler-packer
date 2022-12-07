.default:
	@echo "Usage:"
	@echo "    make ami        - Create 'AMI image' from the base AMI image by using packer"
	@echo "    make harvester  - Create harvester 'qcow2 image' by using packer"
	@echo "    make clean      - Delete temporary files in 'tmp'"

# base-image will generate a base qcow2 image at tmp/SHRINKED-*.qcow2
base-image:
	./scripts/build-base-image.sh

# base-ami will create a BASE AMI cloud image
base-ami: base-image
	./scripts/build-base-ami.sh

# base-hwcloud will upload the base qcow2 image to hwcloud OBS bucket
base-hwcloud: base-image
	./scripts/build-base-hwcloud.sh

# ami: Generate a AWS ami image with name format 'openEuler-<VERSION>-<ARCH>-hvm-<DATETIME>'
# use SKIP_BASE_AMI=1 to skip build base AMI image.
ami: base-ami
	./scripts/openeuler/build-ami.sh

harvester: base-image
	./scripts/openeuler/build-harvester.sh

hwcloud:
	./scripts/openeuler/build-hwcloud.sh

clean:
	./scripts/clean.sh

.DEFAULT_GOAL := .default

.PHONY: base-image base-ami ami harvester clean
