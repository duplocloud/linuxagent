# Automated Installation

[![Latest Build](https://github.com/duplocloud/linuxagent/actions/workflows/build-image.yml/badge.svg?branch=master)](https://github.com/duplocloud/linuxagent/actions/workflows/build-image.yml "See latest builds")

## Run from Github Actions

**Full instructions TBD**

Run the `Image: Agent - duplocloud-docker` action to build both AWS and GCP images.

- `image_version`:  set this to `release_MONTH_YEAR` to build a release
- `only_builders`:  you can change this build only certain images (packer `-only` syntax)

### Notes

- If you leave the `image_version` as `dev` - you will build a private image, only in `us-west-2`.
- If you change the `image_version` to a release version - you will build a public image, in multiple regions.

# Manual Installation Steps

## Steps to create DUPLO AMI.

### OS : Ubuntu 20.04 and Ubuntu 22.04
[Ubuntu 20.04 and Ubuntu 22.04](docs/README_UBUNTU_20_04_AND_22_04.md)
### OS :  Amazon linux 2
[Amazon Linux 2](docs/README_AMAZON_LINUX_2.md)
 