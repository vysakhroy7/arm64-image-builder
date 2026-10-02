#!/usr/bin/env bash
set -Eeuo pipefail

ROOTFS_DIR="${ROOTFS_DIR:-build/rootfs}"
QEMU_BINARY="${QEMU_BINARY:-/usr/bin/qemu-aarch64-static}"
PACKAGE_FILE="${PACKAGE_FILE:-config/packages.txt}"
REMOVE_PACKAGE="${REMOVE_PACKAGE:-jq}"

if [[ ! -d "${ROOTFS_DIR}" ]]; then
    echo "ERROR: Rootfs directory does not exist: ${ROOTFS_DIR}" >&2
    exit 1
fi

if [[ ! -x "${QEMU_BINARY}" ]]; then
    echo "ERROR: QEMU binary not found or not executable: ${QEMU_BINARY}" >&2
    exit 1
fi

if [[ ! -x "${ROOTFS_DIR}/bin/bash" ]]; then
    echo "ERROR: Target bash not found: ${ROOTFS_DIR}/bin/bash" >&2
    exit 1
fi

if [[ ! -f "${PACKAGE_FILE}" ]]; then
    echo "ERROR: Package configuration file does not exist: ${PACKAGE_FILE}" >&2
    exit 1
fi

mapfile -t PACKAGES < <(grep -Ev '^[[:space:]]*(#|$)' "${PACKAGE_FILE}")

if [[ ${#PACKAGES[@]} -lt 3 ]]; then
    echo "ERROR: At least three packages must be defined in ${PACKAGE_FILE}" >&2
    exit 1
fi

echo "INFO: Installing QEMU interpreter into target rootfs"
cp "${QEMU_BINARY}" "${ROOTFS_DIR}/usr/bin/qemu-aarch64-static"

echo "INFO: Testing transparent ARM64 execution through chroot"
if ! chroot "${ROOTFS_DIR}" /bin/bash -c 'true'; then
    echo "ERROR: Unable to execute ARM64 binaries transparently." >&2
    echo "ERROR: Verify AArch64 QEMU/binfmt support on the Jenkins node." >&2
    exit 1
fi

echo "INFO: Completing debootstrap second stage"
chroot "${ROOTFS_DIR}" /debootstrap/debootstrap --second-stage

echo "INFO: Running apt update inside ARM64 rootfs"
chroot "${ROOTFS_DIR}" /usr/bin/env \
    DEBIAN_FRONTEND=noninteractive \
    apt-get update

echo "INFO: Installing packages: ${PACKAGES[*]}"
chroot "${ROOTFS_DIR}" /usr/bin/env \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends "${PACKAGES[@]}"

echo "INFO: Verifying installed packages"
for package in "${PACKAGES[@]}"; do
    if ! chroot "${ROOTFS_DIR}" dpkg-query \
        -W -f='${Status}\n' "${package}" 2>/dev/null |
        grep -qx 'install ok installed'; then
        echo "ERROR: Package was not installed successfully: ${package}" >&2
        exit 1
    fi

    echo "PASS: ${package} is installed"
done

echo "INFO: Removing package: ${REMOVE_PACKAGE}"
chroot "${ROOTFS_DIR}" /usr/bin/env \
    DEBIAN_FRONTEND=noninteractive \
    apt-get remove -y "${REMOVE_PACKAGE}"

echo "INFO: Verifying ${REMOVE_PACKAGE} is absent"
if chroot "${ROOTFS_DIR}" dpkg-query \
    -W -f='${Status}\n' "${REMOVE_PACKAGE}" 2>/dev/null |
    grep -qx 'install ok installed'; then
    echo "ERROR: ${REMOVE_PACKAGE} is still installed" >&2
    exit 1
fi

echo "PASS: ${REMOVE_PACKAGE} is not installed"

echo "INFO: Cleaning package cache"
chroot "${ROOTFS_DIR}" apt-get clean

echo "INFO: ARM64 rootfs customization completed successfully"
