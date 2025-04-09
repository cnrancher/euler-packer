packer {
  required_plugins {
    huaweicloud = {
      version = ">= 0.4.0"
      source  = "github.com/huaweicloud/huaweicloud"
    }
  }
}

variables {
  version = env("OPENEULER_VERSION")
  arch = env("OPENEULER_ARCH")
  source_image = env("SOURCE_IMAGE_ID")
  vpc_id = env("VPC_ID")
  subnet_id = env("SUBNET_ID")
  current_time = env("CURRENT_TIME")
}

source "huaweicloud-ecs" "artifact" {
  region            = "ap-southeast-1"
  availability_zone = "ap-southeast-1a"
  flavor            = "kc2.large.2"
  source_image      = "${var.source_image}"
  image_name        = "openEuler-${var.version}-arm64-${var.current_time}"
  image_tags = {
    builder = "packer"
    os      = "openEuler-${var.version}"
  }
  instance_name      = "PACKER-openEuler-${var.version}-arm64"
  ssh_username       = "root"
  ssh_password       = "openEuler12#$"
  vpc_id             = "${var.vpc_id}"
  subnets            = [ "${var.subnet_id}" ]
  eip_type           = "5_bgp"
  eip_bandwidth_size = 5
  volume_size        = 40
  volume_type        = "SSD"
}

build {
  sources = ["source.huaweicloud-ecs.artifact"]

  provisioner "shell" {
    environment_vars = [
      "VERSION=${var.version}",
      "ARCH=${var.arch}",
    ]
    script = "../../scripts/openeuler/packer/hwcloud-install-cloud-init.sh"
  }
}
