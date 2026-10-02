#!/usr/bin/env bash
set -Eeuo pipefail

DISTRO_SUITE="${DISTRO_SUITE:-bookworm}"
TARGET_ARCH="${TARGET_ARCH:-arm64}"
ROOTFS_DIR="${ROOTFS_DIR:-build/rootfs}"
DEBIAN_MIRROR="${DEBIAN_MIRROR:-https://deb.debian.org/debian}"

if ! command -v debootstrap >/dev/null 2>&1; then
    echo "ERROR: debootstrap is not installed or not in PATH." >&2
    exit 1
fi

if [[ -z "${ROOTFS_DIR}" || "${ROOTFS_DIR}" == "/" ]]; then
    echo "ERROR: Unsafe ROOTFS_DIR value: '${ROOTFS_DIR}'" >&2
    exit 1
fi

echo "INFO: Preparing clean rootfs directory: ${ROOTFS_DIR}"
rm -rf "${ROOTFS_DIR}"
mkdir -p "${ROOTFS_DIR}"

echo "INFO: Bootstrapping Debian ${DISTRO_SUITE} for ${TARGET_ARCH}"
echo "INFO: Mirror: ${DEBIAN_MIRROR}"

debootstrap \
    --arch="${TARGET_ARCH}" \
    --foreign \
    "${DISTRO_SUITE}" \
    "${ROOTFS_DIR}" \
    "${DEBIAN_MIRROR}"

echo "INFO: ARM64 rootfs first stage completed successfully."
