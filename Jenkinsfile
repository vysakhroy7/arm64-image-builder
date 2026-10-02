pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 45, unit: 'MINUTES')
    }

    parameters {
        string(
            name: 'DISTRO_SUITE',
            defaultValue: 'bookworm',
            description: 'Debian release suite'
        )

        string(
            name: 'TARGET_ARCH',
            defaultValue: 'arm64',
            description: 'Target architecture'
        )

        string(
            name: 'REMOVE_PACKAGE',
            defaultValue: 'jq',
            description: 'Package installed and then removed'
        )
    }

    environment {
        ROOTFS_DIR = 'build/rootfs'
        ARTIFACT_DIR = 'artifacts'
        ARTIFACT_NAME = 'debian-arm64-custom.tar.gz'
        PACKAGE_FILE = 'config/packages.txt'
        QEMU_BINARY = '/usr/bin/qemu-aarch64-static'
    }

    stages {

        stage('Validate Builder') {
            steps {
                sh '''
                    set -Eeuo pipefail

                    echo "Builder architecture:"
                    uname -m

                    test "$(uname -m)" = "x86_64" || {
                        echo "ERROR: Jenkins builder must be x86_64"
                        exit 1
                    }

                    for cmd in debootstrap chroot qemu-aarch64-static tar sha256sum; do
                        command -v "$cmd" >/dev/null || {
                            echo "ERROR: Required command missing: $cmd"
                            exit 1
                        }
                    done

                    echo "PASS: Builder prerequisites available"
                '''
            }
        }

        stage('Bootstrap ARM64 RootFS') {
            steps {
                sh '''
                    DISTRO_SUITE="${DISTRO_SUITE}" \
                    TARGET_ARCH="${TARGET_ARCH}" \
                    ROOTFS_DIR="${ROOTFS_DIR}" \
                    scripts/bootstrap-rootfs.sh
                '''
            }
        }

        stage('Customize ARM64 RootFS') {
            steps {
                sh '''
                    ROOTFS_DIR="${ROOTFS_DIR}" \
                    PACKAGE_FILE="${PACKAGE_FILE}" \
                    QEMU_BINARY="${QEMU_BINARY}" \
                    REMOVE_PACKAGE="${REMOVE_PACKAGE}" \
                    scripts/customize-rootfs.sh
                '''
            }
        }

        stage('Validate ARM64 RootFS') {
            steps {
                sh '''
                    ROOTFS_DIR="${ROOTFS_DIR}" \
                    REMOVE_PACKAGE="${REMOVE_PACKAGE}" \
                    scripts/validate-rootfs.sh
                '''
            }
        }

        stage('Package Artifact') {
            steps {
                sh '''
                    ROOTFS_DIR="${ROOTFS_DIR}" \
                    ARTIFACT_DIR="${ARTIFACT_DIR}" \
                    ARTIFACT_NAME="${ARTIFACT_NAME}" \
                    scripts/package-rootfs.sh
                '''
            }
        }

        stage('Archive Artifact') {
            steps {
                archiveArtifacts(
                    artifacts: 'artifacts/*',
                    fingerprint: true
                )
            }
        }
    }

    post {
        success {
            echo 'ARM64 image preparation completed successfully.'
        }

        failure {
            echo 'ARM64 image preparation failed. Review the failing stage above.'
        }

        always {
            sh '''
                if [ -n "${ROOTFS_DIR:-}" ] && [ "${ROOTFS_DIR}" != "/" ]; then
                    rm -rf "${ROOTFS_DIR}"
                fi
            '''
        }
    }
}
