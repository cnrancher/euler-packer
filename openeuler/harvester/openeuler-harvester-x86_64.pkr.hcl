packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.4"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variables {
  version = env("OPENEULER_VERSION")
  build   = env("AWS_IMAGE_BUILD_NUMBER")
  arch =  env("OPENEULER_ARCH")
  working_dir = env("WORKING_DIR")
}

source "qemu" "harvester_base_image" {
  disk_image       = true
  iso_url          = "${var.working_dir}/tmp/SHRINKED-openEuler-${var.version}-${var.arch}.qcow2"
  iso_checksum     = "none"
  output_directory = "${var.working_dir}/harvester_image_output/"
  shutdown_command = "echo 'packer' | sudo -S shutdown -P now"
  disk_size        = "8G"
  format           = "qcow2"
  accelerator      = "none"
  #http_directory    = "path/to/httpdir"
  ssh_username     = "root"
  ssh_password     = "openEuler12#$"
  ssh_timeout      = "2m"
  vm_name          = "Harvester-openEuler-${var.version}-${var.arch}.qcow2"
  net_device       = "virtio-net"
  disk_interface   = "virtio"
  boot_wait        = "10s"
  vnc_bind_address = "0.0.0.0"
  qemuargs = [
    ["-m", "4096"],
    ["-smp", "2"],
    ["-nographic"],
    ["-display", "none"],
  ]
}

build {
  sources = ["source.qemu.harvester_base_image"]

  provisioner "shell" {
    environment_vars = [
      "VERSION=${var.version}",
      "ARCH=${var.arch}",
    ]
    script = "../../scripts/openeuler/packer/harvester-install-cloud-init.sh"
  }
}
