#!/usr/bin/env bash
set -Eeuo pipefail

ROOTFS_DIR="${ROOTFS_DIR:-build/rootfs}"
ARTIFACT_DIR="${ARTIFACT_DIR:-artifacts}"
ARTIFACT_NAME="${ARTIFACT_NAME:-debian-arm64-custom.tar.gz}"

if [[ ! -d "${ROOTFS_DIR}" ]]; then
    echo "ERROR: Rootfs does not exist: ${ROOTFS_DIR}" >&2
    exit 1
fi

mkdir -p "${ARTIFACT_DIR}"

ARTIFACT_PATH="${ARTIFACT_DIR}/${ARTIFACT_NAME}"

echo "INFO: Removing build-time QEMU interpreter from final rootfs"
rm -f "${ROOTFS_DIR}/usr/bin/qemu-aarch64-static"

echo "INFO: Creating artifact: ${ARTIFACT_PATH}"
tar -C "${ROOTFS_DIR}" -czf "${ARTIFACT_PATH}" .

echo "INFO: Validating compressed archive"
tar -tzf "${ARTIFACT_PATH}" >/dev/null

echo "INFO: Creating SHA256 checksum"
sha256sum "${ARTIFACT_PATH}" > "${ARTIFACT_PATH}.sha256"

echo "INFO: Artifact details"
ls -lh "${ARTIFACT_PATH}" "${ARTIFACT_PATH}.sha256"

echo "INFO: SHA256"
cat "${ARTIFACT_PATH}.sha256"

echo "PASS: Artifact created successfully"
