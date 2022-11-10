.dapper:
	@echo Downloading dapper
	@curl -sL https://releases.rancher.com/dapper/latest/dapper-`uname -s`-`uname -m` > .dapper.tmp
	@@chmod +x .dapper.tmp
	@./.dapper.tmp -v
	@mv .dapper.tmp .dapper

.default:
	@echo "Usage:"
	@echo "    make base-image  -- Shrink the openEuler qcow2 disk to 8G and use it as the base image."
	@echo "    make aws-image -- Create AMI image from base image by using packer."
	@echo "    make qemu-image -- Create qemu image from base image by using packer."
	@echo "    make clean -- Delete temporary files in 'tmp' folder."

base-image:
	@echo "Building the base image..."
	./scripts/build-base-image

aws-image: .dapper
	@echo "Uploading an image to aws s3..."
	./scripts/upload-to-s3
	@echo "Building an aws image"
	./.dapper

qemu-image: base-image
	@echo "Building a qemu image..."
	./scripts/openeuler-build-qemu

clean:
	rm -r ./tmp || echo "tmp folder already deleted"
	rm $(shell find . -name "*.dapper*" ! -name "Dockerfile.dapper") || echo "dapper temp file already deleted"
	rm .dapper || echo ".dapper already deleted"
	echo "Finished successfully"

.DEFAULT_GOAL := .default

.PHONY: base-image aws-image qemu-image clean
