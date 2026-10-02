# ARM64 Linux Image Preparation using Jenkins

## Overview

This project implements a Jenkins pipeline that prepares and customizes a Debian ARM64 Linux root filesystem while the Jenkins build executes on an x86_64 Linux node.

The pipeline demonstrates:

- Creation of an ARM64 Debian filesystem from an x86_64 host
- Cross-architecture execution using QEMU user-mode
- Native ARM64 package management using `apt` and `dpkg`
- Installation and removal of packages
- Validation of operating system and target architecture
- Creation of a compressed ARM64 root filesystem artifact
- SHA256 checksum generation
- Jenkins artifact archival
- Automated cleanup and repeatable execution

The generated artifact is:

    debian-arm64-custom.tar.gz

A corresponding SHA256 checksum is also generated:

    debian-arm64-custom.tar.gz.sha256


## Architecture

The Jenkins build node is x86_64, while the target userspace is ARM64.

    +-----------------------------+
    | Jenkins Build Node          |
    | Architecture: x86_64        |
    +-------------+---------------+
                  |
                  | debootstrap --foreign
                  v
    +-----------------------------+
    | Debian ARM64 Root Filesystem|
    +-------------+---------------+
                  |
                  | QEMU user-mode
                  | + binfmt support
                  v
    +-----------------------------+
    | ARM64 userspace             |
    |                             |
    | /bin/bash                   |
    | apt                         |
    | dpkg                        |
    +-------------+---------------+
                  |
                  | customize + validate
                  v
    +-----------------------------+
    | ARM64 RootFS Artifact       |
    | .tar.gz + SHA256            |
    +-----------------------------+


## Distribution Choice

Debian 12 (Bookworm) is used as the target operating system.

Debian was selected because `debootstrap` provides a simple and well-established method for constructing a minimal Debian filesystem without requiring a full ISO installation or virtual machine.

The target architecture is:

    arm64

The Jenkins builder architecture is:

    x86_64


## Cross-Architecture Approach

The main challenge is executing ARM64 programs while the Jenkins node itself is x86_64.

The root filesystem is initially created using:

    debootstrap --arch=arm64 --foreign

The `--foreign` option performs the first bootstrap stage without requiring the x86_64 builder to directly execute ARM64 binaries.

The second stage requires execution of programs from the ARM64 filesystem.

QEMU user-mode is used to provide cross-architecture execution. The Jenkins node must provide an AArch64 execution mechanism using `qemu-aarch64-static` together with appropriate Linux binary-format support.

This allows ARM64 programs such as:

    /bin/bash
    apt
    dpkg

to execute while the underlying Jenkins node remains x86_64.

`chroot` provides the target filesystem environment, while QEMU provides the CPU architecture translation required to execute ARM64 binaries.

The pipeline performs a functional cross-architecture check before customization:

    chroot <rootfs> /bin/bash -c 'true'

If ARM64 execution is unavailable, the build fails before package modification begins.


## Pipeline Stages

The Jenkins pipeline is divided into the following stages:

### 1. Validate Builder

Validates the Jenkins build environment.

Checks include:

- Builder architecture is `x86_64`
- `debootstrap` is available
- `chroot` is available
- `qemu-aarch64-static` is available
- `tar` is available
- `sha256sum` is available


### 2. Bootstrap ARM64 RootFS

Creates a fresh Debian ARM64 root filesystem using `debootstrap`.

The existing build root filesystem is removed first so every build starts from a clean state.


### 3. Customize ARM64 RootFS

Completes the Debian bootstrap second stage and runs package management commands inside the ARM64 environment.

The package list is read from:

    config/packages.txt

The configured packages are:

    curl
    git
    jq

The pipeline performs:

    apt-get update
    apt-get install

and verifies that the packages were successfully installed using `dpkg-query`.

The configured removal package is then removed.

By default:

    jq

is removed using:

    apt-get remove

The pipeline verifies that the removed package is no longer installed.


### 4. Validate ARM64 RootFS

The resulting filesystem is validated before an artifact is produced.

Validation includes:

- Operating system is Debian
- Version is Debian 12
- `dpkg` architecture is `arm64`
- Runtime architecture reports `aarch64`
- Required final packages are installed
- Removed package is absent
- ARM64 executable files are present

A failure in any required validation causes the Jenkins build to fail.


### 5. Package Artifact

The build-time QEMU interpreter copied into the root filesystem is removed before packaging.

The root filesystem is packaged as:

    artifacts/debian-arm64-custom.tar.gz

The archive is tested using `tar` before being accepted.

A SHA256 checksum is generated:

    artifacts/debian-arm64-custom.tar.gz.sha256


### 6. Archive Artifact

Jenkins archives the generated artifact and checksum using `archiveArtifacts`.

Artifact fingerprinting is enabled.


## Repository Structure

    arm64-image-builder/
    ├── Jenkinsfile
    ├── README.md
    ├── Dockerfile.jenkins-lab
    ├── config/
    │   └── packages.txt
    └── scripts/
        ├── bootstrap-rootfs.sh
        ├── customize-rootfs.sh
        ├── validate-rootfs.sh
        └── package-rootfs.sh


## Jenkins Node Prerequisites

The Jenkins build node must be an x86_64 Linux system.

Required tools include:

- Bash
- debootstrap
- QEMU user-mode (`qemu-aarch64-static`)
- chroot
- tar
- sha256sum
- appropriate AArch64 binary-format execution support

The build user must also have sufficient permission to execute `chroot` and create the target filesystem.

For a production Jenkins environment, a dedicated build agent with narrowly scoped privileges is recommended rather than running the Jenkins controller with elevated privileges.


## Jenkins Parameters

The pipeline currently exposes the following parameters:

### DISTRO_SUITE

Default:

    bookworm

Controls the Debian suite passed to `debootstrap`.


### TARGET_ARCH

Default:

    arm64

Controls the target architecture used during bootstrap.


### REMOVE_PACKAGE

Default:

    jq

Specifies the package that will be removed after installation.


## Running the Pipeline

Create a Jenkins Pipeline job and configure it to use:

    Pipeline script from SCM

Configure the Git repository containing this project.

The pipeline definition is:

    Jenkinsfile

Run the job using:

    Build with Parameters

The default parameters produce a Debian Bookworm ARM64 root filesystem.


## Successful Build Result

A successful pipeline produces:

    artifacts/
    ├── debian-arm64-custom.tar.gz
    └── debian-arm64-custom.tar.gz.sha256

Both files are archived by Jenkins and are available from the completed build.


## Repeatability and Cleanup

The pipeline recreates the target root filesystem for each build rather than modifying an existing filesystem.

This provides a consistent clean starting point and avoids dependency on manual preparation from previous builds.

The Jenkins `post` section removes the temporary root filesystem after the build.

The pipeline has been successfully executed repeatedly without manual workspace preparation between builds.


## Error Handling

Shell scripts use strict Bash error handling:

    set -Eeuo pipefail

Validation failures return a non-zero exit status and therefore fail the corresponding Jenkins stage.

Examples include:

- Incorrect builder architecture
- Missing required commands
- Missing ARM64 execution support
- Failed package installation
- Incorrect target architecture
- Required package missing
- Removed package still installed
- Invalid archive generation


## Security Considerations

The implementation avoids hardcoded credentials and secrets.

The ARM64 filesystem is downloaded from the Debian package repository over HTTPS.

The Git repository can be accessed by Jenkins using a read-only deployment credential.

The local Jenkins Docker environment runs with elevated permissions only to demonstrate the assignment in an isolated lab. A production implementation should use a dedicated build agent and grant only the privileges required for filesystem creation and `chroot` execution.

The QEMU interpreter used during image construction is removed from the final target filesystem before packaging.


## Local Jenkins Lab

`Dockerfile.jenkins-lab` provides a reproducible local Jenkins environment for testing the pipeline.

It extends the Jenkins LTS image and installs the tools required for this assignment, including:

- debootstrap
- qemu-user-static
- file

The local lab runs as root because the build requires `chroot`. This is intended only for the isolated development environment and is not a recommended production Jenkins security model.


## Artifact Scope

The output of this project is an ARM64 Linux root filesystem archive.

It is not directly a bootable virtual machine disk image.

The root filesystem can be used as an input for additional workflows such as:

- container image construction
- disk image creation
- VM image preparation
- further ARM64 filesystem customization

Creating a bootable VM image would additionally require disk partitioning, filesystem creation, kernel and bootloader configuration, and other system-specific boot configuration.


## Assumptions and Limitations

- Jenkins executes on an x86_64 Linux build node.
- The target architecture is ARM64.
- Cross-architecture execution support is available on the Jenkins node.
- The default target distribution is Debian 12 Bookworm.
- Internet access to the Debian repositories is available.
- The generated artifact is a root filesystem archive rather than a bootable VM image.
- Package repository contents may change over time, so builds are repeatable from a clean configuration but are not guaranteed to be byte-for-byte identical unless package versions and repository snapshots are pinned.


## Design Rationale

Jenkins is used primarily for pipeline orchestration, while filesystem operations are implemented in separate shell scripts.

This separation provides:

- easier testing
- clearer pipeline stages
- reusable scripts
- simpler troubleshooting
- better separation between CI orchestration and operating-system customization

The implementation intentionally uses standard Linux tools and native Debian package management so that the cross-architecture behavior remains visible and easy to explain.
