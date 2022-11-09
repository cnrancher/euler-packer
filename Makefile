.dapper:
	@echo Downloading dapper
	@curl -sL https://releases.rancher.com/dapper/latest/dapper-`uname -s`-`uname -m` > .dapper.tmp
	@@chmod +x .dapper.tmp
	@./.dapper.tmp -v
	@mv .dapper.tmp .dapper

.default:
	@echo "Usage:"
	@echo "    make prep  -- Prepare AWS base AMI image."
	@echo "    make build -- Create AMI image from base image by using packer."
	@echo "    make clean -- Delete temporary files in 'tmp' folder."

build: .dapper
	./.dapper

prep:
	@echo "Running preparation..."
	./scripts/preparation

clean:
	rm -r ./tmp || echo "tmp folder already deleted"
	rm $(shell find . -name "*.dapper*" ! -name "Dockerfile.dapper") || echo "dapper temp file already deleted"
	rm .dapper || echo ".dapper already deleted"
	echo "Finished successfully"

.DEFAULT_GOAL := .default

.PHONY: build prep clean
