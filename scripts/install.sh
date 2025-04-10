#!/usr/bin/env bash

set -euxo pipefail

# Detect the current OS, OS version, and architecture and download and unpack
# the appropriate solvers. Intended for use in CI builds. Only supports
# detecting OSes/versions/architectures for which we build the solvers. The
# results on other combinations are not guaranteed.
#
# Takes two positional parameters:
#
# 1. The snapshot version, e.g., "20250326"
# 2. The destination directory
#
# Example usage in a CI build:
#
#   snapshot=YYYYMMDD
#   curl \
#     --fail \
#     --location \
#     --proto '=https' \
#     --show-error \
#     --silent \
#     --tlsv1.2 \
#     "https://raw.githubusercontent.com/GaloisInc/what4-solvers/${snapshot}/scripts/install.sh" | \
#     bash -s -- "${snapshot}" "${PWD}/bin"

die() { printf 'fatal error: %s\n' "{1}"; exit 1; }

if [[ -z "${1}" ]] || [[ -z "${2}" ]]; then
  die "This script expects two arguments, snapshot version and destination dir"
fi

case "${OSTYPE}" in
  linux-gnu*) os=ubuntu ;;
  darwin*) os=macos ;;
  cygwin) os=windows ;;
  msys) os=windows ;;
  *) die "Unknown OSTYPE: ${OSTYPE}" ;;
esac

case "${os}" in
  ubuntu) version=$(lsb_release -r -s) ;;
  macos) version=$(sw_vers -productVersion | cut -d '.' -f 1) ;;
  windows) version=$(wmic os get version | findstr /r "^[0-9]" | awk -F. '{print $1}') ;;
esac

case "${os}" in
  ubuntu) arch=$([[ "$(uname -m)" = "aarch64" ]] && echo "ARM64" || echo "X64") ;;
  macos) arch=$([[ "$(uname -m)" = "aarch64" ]] && echo "ARM64" || echo "X64") ;;
  windows) arch=X64 ;;
esac

mkdir -p "${2}"
cd "${2}"
curl \
  --fail \
  --location \
  --output bins.zip \
  --proto '=https' \
  --show-error \
  --silent \
  --tlsv1.2 \
  "https://github.com/GaloisInc/what4-solvers/releases/download/snapshot-${1}/${os}-${version}-${arch}-bin.zip"
unzip bins.zip
rm bins.zip
ext=""
[[ ${os} == Windows ]] && ext=".exe"
cp "yices_smt2${ext}" "yices-smt2${ext}"
chmod +x -- *
