#!/usr/bin/env bash
# Download what4-solvers binaries for the current platform
#
# Usage: download-solvers.sh [OPTIONS]
#
# Options:
#   -d, --dest DIR       Destination directory (default: ./solvers)
#   -r, --release TAG    Release tag to download (default: latest)
#   -o, --os OS          Override OS detection (ubuntu-22.04, ubuntu-24.04, macos-15, windows-2022, redhat-ubi9)
#   -a, --arch ARCH      Override architecture detection (X64, ARM64)
#   -h, --help           Show this help message
#
# Environment variables:
#   WHAT4_SOLVERS_DEST   Same as --dest
#   WHAT4_SOLVERS_TAG    Same as --release

set -euo pipefail

REPO="GaloisInc/what4-solvers"
DEST="${WHAT4_SOLVERS_DEST:-./solvers}"
RELEASE_TAG="${WHAT4_SOLVERS_TAG:-latest}"
OS_OVERRIDE=""
ARCH_OVERRIDE=""

usage() {
    cat <<EOF
Download what4-solvers binaries for the current platform

Usage: $(basename "$0") [OPTIONS]

Options:
  -d, --dest DIR       Destination directory (default: ./solvers)
  -r, --release TAG    Release tag to download (default: latest)
  -o, --os OS          Override OS detection
  -a, --arch ARCH      Override architecture detection (X64, ARM64)
  -h, --help           Show this help message

Supported OS values:
  ubuntu-22.04, ubuntu-24.04, macos-15, windows-2022, redhat-ubi9

Environment variables:
  WHAT4_SOLVERS_DEST   Same as --dest
  WHAT4_SOLVERS_TAG    Same as --release
EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dest)
            DEST="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE_TAG="$2"
            shift 2
            ;;
        -o|--os)
            OS_OVERRIDE="$2"
            shift 2
            ;;
        -a|--arch)
            ARCH_OVERRIDE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            printf "Unknown option: %s" "$1" >&2
            usage
            ;;
    esac
done

# Detect operating system
detect_os() {
    if [[ -n "$OS_OVERRIDE" ]]; then
        printf "%s" "$OS_OVERRIDE"
        return
    fi

    local kernel
    kernel=$(uname -s)

    case "$kernel" in
        Linux)
            # Detect the specific Linux distribution
            if [[ ! -f /etc/os-release ]]; then
                printf "Error: Cannot detect Linux distribution (/etc/os-release not found)" >&2
                printf "Use --os to specify one of: ubuntu-22.04, ubuntu-24.04, redhat-ubi9" >&2
                exit 1
            fi
            # shellcheck disable=SC1091
            . /etc/os-release
            case "$ID" in
                ubuntu)
                    case "$VERSION_ID" in
                        22.04) printf "ubuntu-22.04" ;;
                        24.04) printf "ubuntu-24.04" ;;
                        *)
                            printf "Error: Unsupported Ubuntu version: %s" "$VERSION_ID" >&2
                            printf "Supported versions: 22.04, 24.04" >&2
                            printf "Use --os to override if binaries from a similar version may work" >&2
                            exit 1
                            ;;
                    esac
                    ;;
                rhel)
                    case "${VERSION_ID%%.*}" in
                        9) printf "redhat-ubi9" ;;
                        *)
                            printf "Error: Unsupported RHEL version: %s" "$VERSION_ID" >&2
                            printf "Supported versions: 9.x" >&2
                            printf "Use --os to override if binaries from a similar version may work" >&2
                            exit 1
                            ;;
                    esac
                    ;;
                *)
                    printf "Error: Unsupported Linux distribution: %s" "$ID" >&2
                    printf "Supported distributions: ubuntu (22.04, 24.04), rhel (9.x)" >&2
                    printf "Use --os to override if binaries from a similar distribution may work" >&2
                    exit 1
                    ;;
            esac
            ;;
        Darwin)
            printf "macos-15"
            ;;
        MINGW*|MSYS*|CYGWIN*|Windows_NT)
            printf "windows-2022"
            ;;
        *)
            printf "Error: Unsupported operating system: %s" "$kernel" >&2
            printf "Supported systems: Linux (Ubuntu, RHEL), macOS, Windows" >&2
            exit 1
            ;;
    esac
}

# Detect architecture
detect_arch() {
    if [[ -n "$ARCH_OVERRIDE" ]]; then
        printf "%s" "$ARCH_OVERRIDE"
        return
    fi

    local machine
    machine=$(uname -m)

    case "$machine" in
        x86_64|amd64)
            printf "X64"
            ;;
        aarch64|arm64)
            printf "ARM64"
            ;;
        *)
            printf "Error: Unsupported architecture: %s" "$machine" >&2
            exit 1
            ;;
    esac
}

# Get the download URL for the release
get_download_url() {
    local os="$1"
    local arch="$2"
    local tag="$3"

    local asset_name
    asset_name="${os}-${arch}-bin.zip"

    if [[ "$tag" == "latest" ]]; then
        printf "https://github.com/%s/releases/latest/download/%s" "$REPO" "$asset_name"
    else
        printf "https://github.com/%s/releases/download/%s/%s" "$REPO" "$tag" "$asset_name"
    fi
}

# Download and extract solvers
download_solvers() {
    local os arch url

    os=$(detect_os)
    arch=$(detect_arch)

    printf "Detected OS: %s\n" "$os"
    printf "Detected architecture: %s\n" "$arch"
    printf "Release: %s\n" "$RELEASE_TAG"
    printf "Destination: %s\n" "$DEST"

    url=$(get_download_url "$os" "$arch" "$RELEASE_TAG")
    printf "Download URL: %s\n" "$url"

    # Create destination directory
    mkdir -p "$DEST"

    # Create temporary directory for download
    local tmpdir
    tmpdir=$(mktemp -d)
    # Use single quotes to defer variable expansion until trap execution
    trap 'rm -rf '"$tmpdir"'' EXIT

    local zipfile="$tmpdir/solvers.zip"

    printf "Downloading solvers..."
    if command -v curl &> /dev/null; then
        curl \
          --fail \
          --location \
          --proto '=https' \
          --retry 1 \
          --retry-delay 3 \
          --show-error \
          --silent \
          --tlsv1.2 \
          --output  "$zipfile" \
          "$url"
    elif command -v wget &> /dev/null; then
        wget -q -O "$zipfile" "$url"
    else
        printf "Error: Neither curl nor wget found" >&2
        exit 1
    fi

    printf "Extracting to %s...\n" "$DEST"
    if command -v unzip &> /dev/null; then
        unzip -o -q "$zipfile" -d "$DEST"
    elif command -v 7z &> /dev/null; then
        7z x -y -o"$DEST" "$zipfile" > /dev/null
    else
        printf "Error: Neither unzip nor 7z found" >&2
        exit 1
    fi

    # Make binaries executable (not needed on Windows)
    if [[ "$os" != windows-* ]]; then
        chmod +x "$DEST"/*
    fi

    printf "Solvers installed to %s:\n" "$DEST"
    ls -la "$DEST"
}

download_solvers
