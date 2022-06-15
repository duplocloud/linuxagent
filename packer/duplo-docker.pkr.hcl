# Overall settings
variable "image_version" { default = "dev" }
variable "default_disk_size" { default = 35 }
variable "temporary_key_pair_type" { default = "ecdsa" }

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

build {
  sources = [
		"sources.googlecompute.ubuntu-18",
		"sources.googlecompute.ubuntu-20",
		"sources.googlecompute.ubuntu-22"
	]

	// OS updates - Ubuntu
	provisioner "shell" {
		inline = [ "sudo apt-get clean -y", "sudo apt-get update -y", "sudo apt-get upgrade -y" ]
		env    = { DEBIAN_FRONTEND = "noninteractive" }
		only   = ["googlecompute.ubuntu-18", "googlecompute.ubuntu-20", "googlecompute.ubuntu-22"]
	}

	provisioner "shell" {
		script = "${path.root}/../Agent/Setup_16.04.sh"
		env    = { DEBIAN_FRONTEND = "noninteractive" }
		only   = ["googlecompute.ubuntu-18"]
	}

	provisioner "shell" {
		script = "${path.root}/../AgentUbuntu20/Setup.sh"
		env    = { DEBIAN_FRONTEND = "noninteractive" }
		only   = ["googlecompute.ubuntu-20"]
	}

	provisioner "shell" {
		script = "${path.root}/../AgentUbuntu22/Setup.sh"
		env    = { DEBIAN_FRONTEND = "noninteractive" }
		only   = ["googlecompute.ubuntu-22"]
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
      "IMAGE=$(jq -r \".builds[-1].artifact_id\" packer-manifest.json)",
			"echo 'Making image public'",
      "gcloud compute images add-iam-policy-binding $${IMAGE} --project=${var.gcp_project_id} --member='allAuthenticatedUsers' --role='roles/compute.imageUser'",
    ]
	}
}
