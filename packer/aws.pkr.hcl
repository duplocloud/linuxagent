# Settings for AWS
variable "aws_instance_type" { default = "t3.small" }
variable "aws_region" { default = "us-west-2" }
variable "aws_vpc_id" { default = "vpc-083b7145ef48f1f6d" }
variable "aws_subnet_id" { default = "subnet-01ebe232b391d652b" }
variable "aws_security_group_id" { default = "sg-0a6d127e0ef1a2dd5" }
variable "aws_iam_instance_profile" { default = "duploservices-github" }

# Calculated settings.
locals {
  is_govcloud  = (var.aws_region=="us-gov-west-1" || var.aws_region=="us-gov-east-1")
  ubuntu_owners = local.is_govcloud ? ["513442679011"] : ["099720109477"]

  # AMI regions if public
  ami_regions = !local.is_public ? [] : local.is_govcloud ? ["us-gov-west-1", "us-gov-east-1"] : [
      "us-east-1",
      "us-east-2",
      "us-west-1",
      "us-west-2",
      "eu-central-1",
      "eu-west-1",
      "eu-west-2",
      "eu-west-3",
      "ap-northeast-1",
      "ap-south-1",
      "sa-east-1",
      "ca-central-1",
      "ap-southeast-1",
      "ap-southeast-2"
    ]
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

	temporary_key_pair_type = var.temporary_key_pair_type
	ssh_username            = "ubuntu"
  ssh_interface           = "session_manager"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = local.ubuntu_owners
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
    delete_on_termination = true
  }

  # Source instance tags.
  run_tags = {
    Name    = "Packer Builder: ${local.image_family}-ubuntu18-${local.image_version}"
    Creator = "Packer"
  }
  run_volume_tags = {
    Creator = "Packer"
  }

  # Target AMI tags.
  tags = {
    Name    = "${local.image_family}-ubuntu18-${local.image_version}"
    Creator = "Packer"
  }
  snapshot_tags = {
    Creator = "Packer"
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

	temporary_key_pair_type = var.temporary_key_pair_type
	ssh_username            = "ubuntu"
  ssh_interface           = "session_manager"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = local.ubuntu_owners
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
    delete_on_termination = true
  }

  # Source instance tags.
  run_tags = {
    Name    = "Packer Builder: ${local.image_family}-ubuntu20-${local.image_version}"
    Creator = "Packer"
  }
  run_volume_tags = {
    Creator = "Packer"
  }

  # Target AMI tags.
  tags = {
    Name    = "${local.image_family}-ubuntu20-${local.image_version}"
    Creator = "Packer"
  }
  snapshot_tags = {
    Creator = "Packer"
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

	temporary_key_pair_type = var.temporary_key_pair_type
	ssh_username            = "ubuntu"
  ssh_interface           = "session_manager"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = local.ubuntu_owners
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
    delete_on_termination = true
  }

  # Source instance tags.
  run_tags = {
    Name    = "Packer Builder: ${local.image_family}-ubuntu22-${local.image_version}"
    Creator = "Packer"
  }
  run_volume_tags = {
    Creator = "Packer"
  }

  # Target AMI tags.
  tags = {
    Name    = "${local.image_family}-ubuntu22-${local.image_version}"
    Creator = "Packer"
  }
  snapshot_tags = {
    Creator = "Packer"
  }
}

source "amazon-ebs" "amazonlinux-2" {
  ami_name                    = "${local.image_family}-amazonlinux2-${local.image_version}"
  ami_description             = "${local.image_description} (amazonlinux2)"
  instance_type               = var.aws_instance_type
  region                      = var.aws_region
  vpc_id                      = var.aws_vpc_id
  subnet_id                   = var.aws_subnet_id
  security_group_id           = var.aws_security_group_id
  iam_instance_profile        = var.aws_iam_instance_profile
  associate_public_ip_address = true

	temporary_key_pair_type = var.temporary_key_pair_type
	ssh_username            = "ec2-user"
  ssh_interface           = "session_manager"

  source_ami_filter {
    filters = {
      name                = "amzn2-ami-kernel-5.10-hvm-*-x86_64-gp2"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }

  # Build a public AMI
  encrypt_boot = false
  ami_groups   = local.is_public ? ["all"] : []
  ami_regions  = [for region in local.ami_regions: region if region != var.aws_region]

  # Customize the volumes
  launch_block_device_mappings {
    device_name = "/dev/xvda"
    encrypted   = false
    volume_size = 35
    volume_type = "gp3"
    delete_on_termination = true
  }

  # Source instance tags.
  run_tags = {
    Name    = "Packer Builder: ${local.image_family}-amazonlinux2-${local.image_version}"
    Creator = "Packer"
  }
  run_volume_tags = {
    Creator = "Packer"
  }

  # Target AMI tags.
  tags = {
    Name    = "${local.image_family}-amazonlinux2-${local.image_version}"
    Creator = "Packer"
  }
  snapshot_tags = {
    Creator = "Packer"
  }
}
