## 2024-02-07

### Added
- Introduced support for ARM64 architecture in Docker native image generation.
- Added ARM64 builds for Ubuntu 20, Ubuntu 22, Amazon Linux 2, and Amazon Linux 2023 in AWS Packer configurations.
- Updated the main Packer build configuration to include ARM64 versions.

### Changed
- Modified the GitHub Actions workflow to exclude Ubuntu 18 from the build process, facilitating ARM64 build integration.