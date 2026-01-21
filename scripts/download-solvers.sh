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
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

# Detect operating system
detect_os() {
    if [[ -n "$OS_OVERRIDE" ]]; then
        echo "$OS_OVERRIDE"
        return
    fi

    local kernel
    kernel=$(uname -s)

    case "$kernel" in
        Linux)
            # Detect the specific Linux distribution
            if [[ ! -f /etc/os-release ]]; then
                echo "Error: Cannot detect Linux distribution (/etc/os-release not found)" >&2
                echo "Use --os to specify one of: ubuntu-22.04, ubuntu-24.04, redhat-ubi9" >&2
                exit 1
            fi
            # shellcheck disable=SC1091
            . /etc/os-release
            case "$ID" in
                ubuntu)
                    case "$VERSION_ID" in
                        22.04) echo "ubuntu-22.04" ;;
                        24.04) echo "ubuntu-24.04" ;;
                        *)
                            echo "Error: Unsupported Ubuntu version: $VERSION_ID" >&2
                            echo "Supported versions: 22.04, 24.04" >&2
                            echo "Use --os to override if binaries from a similar version may work" >&2
                            exit 1
                            ;;
                    esac
                    ;;
                rhel)
                    case "${VERSION_ID%%.*}" in
                        9) echo "redhat-ubi9" ;;
                        *)
                            echo "Error: Unsupported RHEL version: $VERSION_ID" >&2
                            echo "Supported versions: 9.x" >&2
                            echo "Use --os to override if binaries from a similar version may work" >&2
                            exit 1
                            ;;
                    esac
                    ;;
                *)
                    echo "Error: Unsupported Linux distribution: $ID" >&2
                    echo "Supported distributions: ubuntu (22.04, 24.04), rhel (9.x)" >&2
                    echo "Use --os to override if binaries from a similar distribution may work" >&2
                    exit 1
                    ;;
            esac
            ;;
        Darwin)
            echo "macos-15"
            ;;
        MINGW*|MSYS*|CYGWIN*|Windows_NT)
            echo "windows-2022"
            ;;
        *)
            echo "Error: Unsupported operating system: $kernel" >&2
            echo "Supported systems: Linux (Ubuntu, RHEL), macOS, Windows" >&2
            exit 1
            ;;
    esac
}

# Detect architecture
detect_arch() {
    if [[ -n "$ARCH_OVERRIDE" ]]; then
        echo "$ARCH_OVERRIDE"
        return
    fi

    local machine
    machine=$(uname -m)

    case "$machine" in
        x86_64|amd64)
            echo "X64"
            ;;
        aarch64|arm64)
            echo "ARM64"
            ;;
        *)
            echo "Error: Unsupported architecture: $machine" >&2
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
        echo "https://github.com/${REPO}/releases/latest/download/${asset_name}"
    else
        echo "https://github.com/${REPO}/releases/download/${tag}/${asset_name}"
    fi
}

# Download and extract solvers
download_solvers() {
    local os arch url

    os=$(detect_os)
    arch=$(detect_arch)

    echo "Detected OS: $os"
    echo "Detected architecture: $arch"
    echo "Release: $RELEASE_TAG"
    echo "Destination: $DEST"

    url=$(get_download_url "$os" "$arch" "$RELEASE_TAG")
    echo "Download URL: $url"

    # Create destination directory
    mkdir -p "$DEST"

    # Create temporary directory for download
    local tmpdir
    tmpdir=$(mktemp -d)
    # Use single quotes to defer variable expansion until trap execution
    trap 'rm -rf '"$tmpdir"'' EXIT

    local zipfile="$tmpdir/solvers.zip"

    echo "Downloading solvers..."
    if command -v curl &> /dev/null; then
        curl -fsSL -o "$zipfile" "$url"
    elif command -v wget &> /dev/null; then
        wget -q -O "$zipfile" "$url"
    else
        echo "Error: Neither curl nor wget found" >&2
        exit 1
    fi

    echo "Extracting to $DEST..."
    if command -v unzip &> /dev/null; then
        unzip -o -q "$zipfile" -d "$DEST"
    elif command -v 7z &> /dev/null; then
        7z x -y -o"$DEST" "$zipfile" > /dev/null
    else
        echo "Error: Neither unzip nor 7z found" >&2
        exit 1
    fi

    # Make binaries executable (not needed on Windows)
    if [[ "$os" != windows-* ]]; then
        chmod +x "$DEST"/*
    fi

    echo "Solvers installed to $DEST:"
    ls -la "$DEST"
}

download_solvers
