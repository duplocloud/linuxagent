# Overall settings
variable "image_version" { default = "dev" }
variable "default_disk_size" { default = 35 }
variable "temporary_key_pair_type" { default = "ed25519" }

# Calculated settings.
locals {
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

build {
  sources = [
		"sources.amazon-ebs.ubuntu-18",
		"sources.amazon-ebs.ubuntu-20",
		"sources.amazon-ebs.ubuntu-22",
		"sources.amazon-ebs.amazonlinux-2",
		"sources.googlecompute.ubuntu-18",
		"sources.googlecompute.ubuntu-20",
		"sources.googlecompute.ubuntu-22"
	]

	// OS updates - Amazon Linux
	provisioner "shell" {
		inline = [ "sleep 10", "sudo yum update -y" ]
		only   = [ "amazon-ebs.amazonlinux-2" ]
	}

	// OS updates - Ubuntu
	provisioner "shell" {
		inline = [ "sudo apt-get clean -y", "sudo apt-get update -y", "sudo apt-get upgrade -y" ]
		environment_vars = [ "DEBIAN_FRONTEND=noninteractive" ]
		only   = [
			"amazon-ebs.ubuntu-18", "amazon-ebs.ubuntu-20", "amazon-ebs.ubuntu-22",
			"googlecompute.ubuntu-18", "googlecompute.ubuntu-20", "googlecompute.ubuntu-22"
		]
	}

	// Install - Amazon Linux 2
	provisioner "shell" {
		script = "${path.root}/../AgentAmazonLinux2/Setup.sh"
		only   = [ "amazon-ebs.amazonlinux-2" ]
	}

	// Install - Ubuntu 18
	provisioner "shell" {
		script = "${path.root}/../Agent/Setup_16.04.sh"
		environment_vars = [ "DEBIAN_FRONTEND=noninteractive" ]
		only   = [ "amazon-ebs.ubuntu-18", "googlecompute.ubuntu-18" ]
	}

	// Install - Ubuntu 20
	provisioner "shell" {
		script = "${path.root}/../AgentUbuntu20/Setup.sh"
		environment_vars = [ "DEBIAN_FRONTEND=noninteractive" ]
		only   = [ "amazon-ebs.ubuntu-20", "googlecompute.ubuntu-20" ]
	}

	// Install - Ubuntu 22
	provisioner "shell" {
		script = "${path.root}/../AgentUbuntu22/Setup.sh"
		environment_vars = [ "DEBIAN_FRONTEND=noninteractive" ]
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
      "GCP_IMAGES=$(jq -r '.builds[] | select((.packer_run_uuid == \"'\"$LAST_RUN\"'\") and .builder_type == \"googlecompute\") | .artifact_id' packer-manifest.json)",
			"echo 'Making GCP images public'",
      "for img in $${GCP_IMAGES[@]}; do gcloud compute images add-iam-policy-binding $${img} --project=${var.gcp_project_id} --member='allAuthenticatedUsers' --role='roles/compute.imageUser'; done",
    ]
	}
}
