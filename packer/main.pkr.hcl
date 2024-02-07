# Overall settings
variable "image_version" { default = "dev" }
variable "agent_git_ref" { default = "master" }
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
		"sources.amazon-ebs.ubuntu-20-arm64",
		"sources.amazon-ebs.ubuntu-22-arm64",
		"sources.amazon-ebs.amazonlinux-2",
		"sources.amazon-ebs.amazonlinux-2-arm64",
		"sources.amazon-ebs.amazonlinux-2023",
		"sources.amazon-ebs.amazonlinux-2023-arm64",
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
		inline = [
			"sudo apt-get clean -y",
			"sudo apt-get update -y",
			"sudo apt-get upgrade -y"
		]
		environment_vars = [ "DEBIAN_FRONTEND=noninteractive" ]
		only   = [
			"amazon-ebs.ubuntu-18", "amazon-ebs.ubuntu-20", "amazon-ebs.ubuntu-22",
			"amazon-ebs.ubuntu-20-arm64", "amazon-ebs.ubuntu-22-arm64",
			"googlecompute.ubuntu-20", "googlecompute.ubuntu-22"
		]
	}

	// Install - Amazon Linux 2
	provisioner "shell" {
		script = "${path.root}/../AgentAmazonLinux2/Setup.sh"
		environment_vars = [
			"DOWNLOAD_REF=${var.agent_git_ref}"
		]
		only   = [
			"amazon-ebs.amazonlinux-2", "amazon-ebs.amazonlinux-2023",
			"amazon-ebs.amazonlinux-2-arm64", "amazon-ebs.amazonlinux-2023-arm64"
		]
	}

	// Install - Ubuntu 18
	provisioner "shell" {
		script = "${path.root}/../Agent/Setup_16.04.sh"
		environment_vars = [
			"DOWNLOAD_REF=${var.agent_git_ref}",
			"DEBIAN_FRONTEND=noninteractive"
		]
		only   = [ "amazon-ebs.ubuntu-18" ]
	}

	// Install - Ubuntu 20
	provisioner "shell" {
		script = "${path.root}/../AgentUbuntu20/Setup.sh"
		environment_vars = [
			"DOWNLOAD_REF=${var.agent_git_ref}",
			"DEBIAN_FRONTEND=noninteractive"
		]
		only   = [ "amazon-ebs.ubuntu-20", "amazon-ebs.ubuntu-20-arm64", "googlecompute.ubuntu-20" ]
	}

	// Install - Ubuntu 22
	provisioner "shell" {
		script = "${path.root}/../AgentUbuntu22/Setup.sh"
		environment_vars = [
			"DOWNLOAD_REF=${var.agent_git_ref}",
			"DEBIAN_FRONTEND=noninteractive"
		]
		only   = [ "amazon-ebs.ubuntu-22", "amazon-ebs.ubuntu-22-arm64", "googlecompute.ubuntu-22" ]
	}

	// Cleanup - Amazon Linux
	provisioner "shell" {
		inline = [ 
			"sudo rm -rf /home/ec2-user/.history /home/ec2-user/authorized_keys", // user history and SSH authorized keys
		]
		only   = [
			"amazon-ebs.amazonlinux-2", "amazon-ebs.amazonlinux-2023",
			"amazon-ebs.amazonlinux-2-arm64", "amazon-ebs.amazonlinux-2023-arm64"
		]
	}

	// Cleanup - Ubuntu
	provisioner "shell" {
		inline = [ 
			"sudo rm -rf /home/ubuntu/.history /home/ubuntu/authorized_keys", // user history and SSH authorized keys
		]
		only   = [
			"amazon-ebs.ubuntu-18", "amazon-ebs.ubuntu-20", "amazon-ebs.ubuntu-22",
			"amazon-ebs.ubuntu-20-arm64", "amazon-ebs.ubuntu-22-arm64",
			"googlecompute.ubuntu-20", "googlecompute.ubuntu-22"
		]
	}

	// Cleanup - all systems
	provisioner "shell" {
		inline = [ 
			"sudo rm -rf /etc/ssh/*_key /etc/ssh/*_key.pub",         // host keys
			"sudo rm -rf /root/.history /root/.ssh/authorized_keys", // root user history and SSH authorized keys
			"sudo rm -rf /tmp/*"
		]
	}

	post-processor "manifest" {}

  post-processor "shell-local" {
    inline = [
			"${local.is_public} || exit 0",
      "LAST_RUN=$(jq -r '.builds[-1].packer_run_uuid' packer-manifest.json)",
      "GCP_IMAGES=\"$(jq -r '.builds[] | select((.packer_run_uuid == \"'\"$LAST_RUN\"'\") and .builder_type == \"googlecompute\") | .artifact_id' packer-manifest.json)\"",
			"echo 'Making GCP images public'",
      "for img in $${GCP_IMAGES}; do gcloud compute images add-iam-policy-binding $${img} --project=${var.gcp_project_id} --member='allAuthenticatedUsers' --role='roles/compute.imageUser'; done",
    ]
	}
}
