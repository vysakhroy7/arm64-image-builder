#!/usr/bin/env bash
set -Eeuo pipefail

ROOTFS_DIR="${ROOTFS_DIR:-build/rootfs}"
EXPECTED_OS_ID="${EXPECTED_OS_ID:-debian}"
EXPECTED_VERSION="${EXPECTED_VERSION:-12}"
EXPECTED_DPKG_ARCH="${EXPECTED_DPKG_ARCH:-arm64}"
EXPECTED_RUNTIME_ARCH="${EXPECTED_RUNTIME_ARCH:-aarch64}"
REMOVE_PACKAGE="${REMOVE_PACKAGE:-jq}"

if [[ ! -d "${ROOTFS_DIR}" ]]; then
    echo "ERROR: Rootfs does not exist: ${ROOTFS_DIR}" >&2
    exit 1
fi

echo "INFO: Validating operating system"

OS_ID="$(grep '^ID=' "${ROOTFS_DIR}/etc/os-release" | cut -d= -f2 | tr -d '"')"
OS_VERSION="$(grep '^VERSION_ID=' "${ROOTFS_DIR}/etc/os-release" | cut -d= -f2 | tr -d '"')"

[[ "${OS_ID}" == "${EXPECTED_OS_ID}" ]] || {
    echo "ERROR: Expected OS ${EXPECTED_OS_ID}, found ${OS_ID}" >&2
    exit 1
}

[[ "${OS_VERSION}" == "${EXPECTED_VERSION}" ]] || {
    echo "ERROR: Expected version ${EXPECTED_VERSION}, found ${OS_VERSION}" >&2
    exit 1
}

echo "PASS: OS = ${OS_ID} ${OS_VERSION}"

echo "INFO: Validating package architecture"
DPKG_ARCH="$(chroot "${ROOTFS_DIR}" dpkg --print-architecture)"

[[ "${DPKG_ARCH}" == "${EXPECTED_DPKG_ARCH}" ]] || {
    echo "ERROR: Expected dpkg architecture ${EXPECTED_DPKG_ARCH}, found ${DPKG_ARCH}" >&2
    exit 1
}

echo "PASS: dpkg architecture = ${DPKG_ARCH}"

echo "INFO: Validating ARM64 runtime"
RUNTIME_ARCH="$(chroot "${ROOTFS_DIR}" uname -m)"

[[ "${RUNTIME_ARCH}" == "${EXPECTED_RUNTIME_ARCH}" ]] || {
    echo "ERROR: Expected runtime architecture ${EXPECTED_RUNTIME_ARCH}, found ${RUNTIME_ARCH}" >&2
    exit 1
}

echo "PASS: runtime architecture = ${RUNTIME_ARCH}"

echo "INFO: Verifying required final packages"

for package in curl git; do
    if ! chroot "${ROOTFS_DIR}" dpkg-query \
        -W -f='${Status}\n' "${package}" 2>/dev/null |
        grep -qx 'install ok installed'; then
        echo "ERROR: Required package missing: ${package}" >&2
        exit 1
    fi

    echo "PASS: ${package} installed"
done

echo "INFO: Verifying removed package"

if chroot "${ROOTFS_DIR}" dpkg-query \
    -W -f='${Status}\n' "${REMOVE_PACKAGE}" 2>/dev/null |
    grep -qx 'install ok installed'; then
    echo "ERROR: Removed package still installed: ${REMOVE_PACKAGE}" >&2
    exit 1
fi

echo "PASS: ${REMOVE_PACKAGE} absent"

echo "INFO: Validating ARM64 executable exists"

if command -v file >/dev/null 2>&1; then
    file "${ROOTFS_DIR}/bin/bash"
fi

echo "PASS: All rootfs validation checks succeeded"
