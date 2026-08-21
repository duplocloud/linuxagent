## 2026-08-19

### Added
- Enabled the Amazon Linux 2023 x86_64 and arm64 Packer builders, along with `AgentAmazonLinux2023/Setup.sh` and a README for it. These sources were added commented-out in 2024-02, so the Amazon Linux 2023 builders claimed by the 2024-02-07 entry below have never run until now.
- Pinned the Amazon Linux 2023 `source_ami_filter` to `al2023-ami-2023.*`, which excludes the ECS-optimized and minimal AMI variants that the looser `al2023-ami-*` pattern also matches.
- Added a per-builder SSH username check to `gen-native-images.sh`. An unmapped builder name previously reused the previous row's username instead of failing.

### Changed
- Merged the generated native-image rows by `Name` instead of replacing every `Docker-Duplo*` row. A build scoped with `only_builders` now leaves the Amazon Linux 2, Ubuntu, and GovCloud rows intact.
- Pinned all third-party GitHub Actions to commit SHAs, and bumped `actions/checkout` to v7, `actions/upload-artifact` to v7, and `actions/download-artifact` to v8.
- Switched the commercial `Packer AWS Role` step to OIDC alone, dropping the static credential inputs that were resolving to empty strings.
- Skipped the GCP credential step unless `only_builders` names a `googlecompute` builder. It had been authenticating on the `all` path, which excludes those builders.
- Treated an empty `only_builders` the same as `all`. A cleared input previously reached packer with no filter, building every source including the GCP ones.
- Added `amazon-ebs.amazonlinux-2-arm64` to the Amazon Linux OS-update step, which had listed only the x86_64 builder.

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