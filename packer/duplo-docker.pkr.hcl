# Overall settings
variable "default_disk_size" { default = 35 }
variable "temporary_key_pair_type" { default = "ecdsa" }

# Settings for GCP
variable "gcp_project_id" { default = "msp-duplocloud-01" }
variable "gcp_region" { default = "us-west2" }
variable "gcp_zone" { default = "us-west2-a" }
variable "gcp_ssh_username" { default = "packer" }
variable "gcp_machine_type" { default = "e2-small" }

source "googlecompute" "ubuntu-18" {
  project_id              = var.gcp_project_id
	source_image_project_id = ["ubuntu-os-cloud"]
  source_image_family     = "ubuntu-1804-lts"
  ssh_username            = var.gcp_ssh_username
  region                  = var.gcp_region
  zone                    = var.gcp_zone
	machine_type            = var.gcp_machine_type
	disk_size               = var.default_disk_size
	temporary_key_pair_type = var.temporary_key_pair_type
}

source "googlecompute" "ubuntu-20" {
  project_id              = var.gcp_project_id
	source_image_project_id = ["ubuntu-os-cloud"]
  source_image_family     = "ubuntu-2004-lts"
  ssh_username            = var.gcp_ssh_username
  region                  = var.gcp_region
  zone                    = var.gcp_zone
	machine_type            = var.gcp_machine_type
	disk_size               = var.default_disk_size
	temporary_key_pair_type = var.temporary_key_pair_type
}

source "googlecompute" "ubuntu-22" {
  project_id              = var.gcp_project_id
	source_image_project_id = ["ubuntu-os-cloud"]
  source_image_family     = "ubuntu-2204-lts"
  ssh_username            = var.gcp_ssh_username
  region                  = var.gcp_region
  zone                    = var.gcp_zone
	machine_type            = var.gcp_machine_type
	disk_size               = var.default_disk_size
	temporary_key_pair_type = var.temporary_key_pair_type
}

build {
  sources = [
		"sources.googlecompute.ubuntu-18",
		"sources.googlecompute.ubuntu-20",
		"sources.googlecompute.ubuntu-22"
	]
}
