#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/tests/lib.sh"
source "$ROOT_DIR/live/kernel-pkg.sh"

assert_eq "linux-image-6.18.65" \
  "$(kernel_pkg_from_deb "config/packages.chroot/linux-image-6.18.65-vdtos_6.18.65-1_amd64.deb")" \
  "extracts package prefix from standard deb filename"

assert_eq "linux-image-6.12.9" \
  "$(kernel_pkg_from_deb "/tmp/linux-image-6.12.9-vdtos_6.12.9-vdtos-1_amd64.deb")" \
  "extracts package prefix from path with custom revision"

assert_fails kernel_pkg_from_deb "config/packages.chroot/other-pkg_1.0_amd64.deb"

echo "test_kernel_pkg.sh: OK"
