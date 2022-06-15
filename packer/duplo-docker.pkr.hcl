# Overall settings
variable "image_version" { default = "dev" }
variable "default_disk_size" { default = 35 }
variable "temporary_key_pair_type" { default = "ecdsa" }

# Settings for AWS
variable "aws_instance_type" { default = "t3.small" }
variable "aws_region" { default = "us-west-2" }
variable "aws_vpc_id" { default = "vpc-083b7145ef48f1f6d" }
variable "aws_subnet_id" { default = "subnet-01ebe232b391d652b" }
variable "aws_security_group_id" { default = "sg-0a6d127e0ef1a2dd5" }
variable "aws_iam_instance_profile" { default = "duploservices-github" }

# Settings for GCP
variable "gcp_project_id" { default = "msp-duplocloud-01" }
variable "gcp_region" { default = "us-west2" }
variable "gcp_zone" { default = "us-west2-a" }
variable "gcp_image_storage_locations" { default = ["us"] }
variable "gcp_machine_type" { default = "e2-small" }

# Calculated settings.
locals {
	# GCP settings
	gcp_image_storage_locations = var.gcp_image_storage_locations

  # Image name
  image_version     = "${var.image_version}-${formatdate("YYYYMMDD't'HHmmss", timestamp())}"
	image_family      = "duplocloud-docker"
  image_name        = "${local.image_family}-${local.image_version}"
  image_description = "DuploCloud Docker Native (${local.image_version})"

	# Image publishing
	is_release        = ( (trimprefix(local.image_version, "release") != local.image_version) ||
                        (trimprefix(local.image_version, "hotfix") != local.image_version) )
	is_public         = local.is_release

  # AMI regions if public
  ami_regions = !local.is_public ? [] : [
    "us-east-1",
    "us-east-2",
    "us-west-1",
    "us-west-2",
    "eu-west-2",
    "ap-northeast-1",
    "ap-south-1"
  ]
}

source "googlecompute" "ubuntu-18" {
  project_id              = var.gcp_project_id
	source_image_project_id = ["ubuntu-os-cloud"]
  source_image_family     = "ubuntu-1804-lts"
  ssh_username            = "ubuntu"
  region                  = var.gcp_region
  zone                    = var.gcp_zone
	machine_type            = var.gcp_machine_type
	disk_size               = var.default_disk_size
	temporary_key_pair_type = var.temporary_key_pair_type

	image_family      = "${local.image_family}-ubuntu18"
	image_labels      = { os = "ubuntu18" }
	image_name        = "${local.image_name}-ubuntu18"
	image_description = "${local.image_description} (ubuntu18)"

	image_storage_locations = local.gcp_image_storage_locations 
}

source "googlecompute" "ubuntu-20" {
  project_id              = var.gcp_project_id
	source_image_project_id = ["ubuntu-os-cloud"]
  source_image_family     = "ubuntu-2004-lts"
  ssh_username            = "ubuntu"
  region                  = var.gcp_region
  zone                    = var.gcp_zone
	machine_type            = var.gcp_machine_type
	disk_size               = var.default_disk_size
	temporary_key_pair_type = var.temporary_key_pair_type
	metadata = {
    block-project-ssh-keys = "true"
  }

	image_family      = "${local.image_family}-ubuntu20"
	image_labels      = { os = "ubuntu20" }
	image_name        = "${local.image_name}-ubuntu20"
	image_description = "${local.image_description} (ubuntu20)"

	image_storage_locations = local.gcp_image_storage_locations 
}

source "googlecompute" "ubuntu-22" {
  project_id              = var.gcp_project_id
	source_image_project_id = ["ubuntu-os-cloud"]
  source_image_family     = "ubuntu-2204-lts"
  ssh_username            = "ubuntu"
  region                  = var.gcp_region
  zone                    = var.gcp_zone
	machine_type            = var.gcp_machine_type
	disk_size               = var.default_disk_size
	temporary_key_pair_type = var.temporary_key_pair_type
	metadata = {
    block-project-ssh-keys = "true"
  }

	image_family      = "${local.image_family}-ubuntu22"
	image_labels      = { os = "ubuntu22" }
	image_name        = "${local.image_name}-ubuntu22"
	image_description = "${local.image_description} (ubuntu22)"

	image_storage_locations = local.gcp_image_storage_locations 
}

source "amazon-ebs" "ubuntu-18" {
  ami_name                    = "${local.image_family}-ubuntu18-${local.image_version}"
  ami_description             = "${local.image_description} (ubuntu18)"
  instance_type               = var.aws_instance_type
  region                      = var.aws_region
  vpc_id                      = var.aws_vpc_id
  subnet_id                   = var.aws_subnet_id
  security_group_id           = var.aws_security_group_id
  iam_instance_profile        = var.aws_iam_instance_profile
  associate_public_ip_address = true

	ssh_username = "ubuntu"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }

  # Build a public AMI
  encrypt_boot = false
  ami_groups   = local.is_public ? ["all"] : []
  ami_regions  = [for region in local.ami_regions: region if region != var.aws_region]

  # Customize the volumes
  launch_block_device_mappings {
    device_name = "/dev/sda1"
    encrypted   = false
    volume_size = 35
    volume_type = "gp3"
  }

  # Source instance tags.
  run_tag {
    key   = "Name"
    value = "Packer Builder: ${local.image_family}-ubuntu18-${local.image_version}"
  }

  # AMI tags.
  tag {
    key   = "Name"
    value = "${local.image_family}-ubuntu18-${local.image_version}"
  }
  tag {
		key   = "OS"
		value = "ubuntu18"
  }
}

source "amazon-ebs" "ubuntu-20" {
  ami_name                    = "${local.image_family}-ubuntu20-${local.image_version}"
  ami_description             = "${local.image_description} (ubuntu20)"
  instance_type               = var.aws_instance_type
  region                      = var.aws_region
  vpc_id                      = var.aws_vpc_id
  subnet_id                   = var.aws_subnet_id
  security_group_id           = var.aws_security_group_id
  iam_instance_profile        = var.aws_iam_instance_profile
  associate_public_ip_address = true

	ssh_username = "ubuntu"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }

  # Build a public AMI
  encrypt_boot = false
  ami_groups   = local.is_public ? ["all"] : []
  ami_regions  = [for region in local.ami_regions: region if region != var.aws_region]

  # Customize the volumes
  launch_block_device_mappings {
    device_name = "/dev/sda1"
    encrypted   = false
    volume_size = 35
    volume_type = "gp3"
  }

  # Source instance tags.
  run_tag {
    key   = "Name"
    value = "Packer Builder: ${local.image_family}-ubuntu20-${local.image_version}"
  }

  # AMI tags.
  tag {
    key   = "Name"
    value = "${local.image_family}-ubuntu20-${local.image_version}"
  }
  tag {
		key   = "OS"
		value = "ubuntu20"
  }
}

source "amazon-ebs" "ubuntu-22" {
  ami_name                    = "${local.image_family}-ubuntu22-${local.image_version}"
  ami_description             = "${local.image_description} (ubuntu22)"
  instance_type               = var.aws_instance_type
  region                      = var.aws_region
  vpc_id                      = var.aws_vpc_id
  subnet_id                   = var.aws_subnet_id
  security_group_id           = var.aws_security_group_id
  iam_instance_profile        = var.aws_iam_instance_profile
  associate_public_ip_address = true

	ssh_username = "ubuntu"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }

  # Build a public AMI
  encrypt_boot = false
  ami_groups   = local.is_public ? ["all"] : []
  ami_regions  = [for region in local.ami_regions: region if region != var.aws_region]

  # Customize the volumes
  launch_block_device_mappings {
    device_name = "/dev/sda1"
    encrypted   = false
    volume_size = 35
    volume_type = "gp3"
  }

  # Source instance tags.
  run_tag {
    key   = "Name"
    value = "Packer Builder: ${local.image_family}-ubuntu22-${local.image_version}"
  }

  # AMI tags.
  tag {
    key   = "Name"
    value = "${local.image_family}-ubuntu22-${local.image_version}"
  }
  tag {
		key   = "OS"
		value = "ubuntu22"
  }
}

build {
  sources = [
		"sources.amazon-ebs.ubuntu-18",
		"sources.amazon-ebs.ubuntu-20",
		"sources.amazon-ebs.ubuntu-22",
		"sources.googlecompute.ubuntu-18",
		"sources.googlecompute.ubuntu-20",
		"sources.googlecompute.ubuntu-22"
	]

	// OS updates - Ubuntu
	provisioner "shell" {
		inline = [ "sudo apt-get clean -y", "sudo apt-get update -y", "sudo apt-get upgrade -y" ]
		env    = { DEBIAN_FRONTEND = "noninteractive" }
		only   = [
			"amazon-ebs.ubuntu-18", "amazon-ebs.ubuntu-20", "amazon-ebs.ubuntu-22",
			"googlecompute.ubuntu-18", "googlecompute.ubuntu-20", "googlecompute.ubuntu-22"
		]
	}

	// Install - Ubuntu 18
	provisioner "shell" {
		script = "${path.root}/../Agent/Setup_16.04.sh"
		env    = { DEBIAN_FRONTEND = "noninteractive" }
		only   = [ "amazon-ebs.ubuntu-18", "googlecompute.ubuntu-18" ]
	}

	// Install - Ubuntu 20
	provisioner "shell" {
		script = "${path.root}/../AgentUbuntu20/Setup.sh"
		env    = { DEBIAN_FRONTEND = "noninteractive" }
		only   = [ "amazon-ebs.ubuntu-20", "googlecompute.ubuntu-20" ]
	}

	// Install - Ubuntu 22
	provisioner "shell" {
		script = "${path.root}/../AgentUbuntu22/Setup.sh"
		env    = { DEBIAN_FRONTEND = "noninteractive" }
		only   = [ "amazon-ebs.ubuntu-22", "googlecompute.ubuntu-22" ]
	}

	// Docker credential helpers - GCP
	provisioner "file" {
		source      = "${path.root}/files/docker-config.gcloud.json"
		destination = "/tmp/docker-config.gcloud.json"
		only   = ["googlecompute.ubuntu-18", "googlecompute.ubuntu-20", "googlecompute.ubuntu-22"]
	}
	provisioner "shell" {
		inline = [
			"sudo mkdir -p /root/.docker",
			"sudo install -o root -g root -m 640 /tmp/docker-config.gcloud.json /root/.docker/config.json",
			"sudo rm -f /tmp/docker-config.gcloud.json"
		]
		only   = ["googlecompute.ubuntu-18", "googlecompute.ubuntu-20", "googlecompute.ubuntu-22"]
	}

	post-processor "manifest" {}

  post-processor "shell-local" {
    inline = [
			"${local.is_public} || exit 0",
      "LAST_RUN=$(jq -r '.builds[-1].packer_run_uuid' packer-manifest.json)",
      "GCP_IMAGES=$(jq -r '.builds[] | select(.packer_run_uuid == \"'\"$LAST_RUN\"'\") | .artifact_id' packer-manifest.json)",
			"echo 'Making GCP images public'",
      "for img in $${GCP_IMAGES[@]}; do gcloud compute images add-iam-policy-binding $${img} --project=${var.gcp_project_id} --member='allAuthenticatedUsers' --role='roles/compute.imageUser'; done",
    ]
	}
}
