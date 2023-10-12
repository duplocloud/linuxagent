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
