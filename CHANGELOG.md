## 2024-08-13

### Changed
- Added `--trusted-host pypi.python.org` parameter to all `pip install` commands in the Amazon Linux 2 setup script for improved consistency and reliability.

## 2024-04-18

### Added
- Installed `amazon-ecr-credential-helper` and configured Docker to use it across Ubuntu 20, Ubuntu 22, and AmazonLinux2 setups.

### Changed
- Corrected function name typo from `installDependancies` to `installDependencies` in setup scripts.
- Updated GitHub Actions in the workflow file to use newer versions (v4) for better performance and features.

## 2024-02-16

### Added
- Enabled support for the "me-central-1" AWS region in the Packer configuration, allowing the creation of AMIs in the Middle East (Bahrain) region.

## 2024-02-07

### Added
- Introduced support for ARM64 architecture in Docker native image generation.
- Added ARM64 builds for Ubuntu 20, Ubuntu 22, Amazon Linux 2, and Amazon Linux 2023 in AWS Packer configurations.
- Updated the main Packer build configuration to include ARM64 versions.

### Changed
- Modified the GitHub Actions workflow to exclude Ubuntu 18 from the build process, facilitating ARM64 build integration.