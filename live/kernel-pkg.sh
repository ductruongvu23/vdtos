#!/usr/bin/env bash
set -euo pipefail

kernel_pkg_from_deb() {
  local deb_path="$1"
  local base pkg
  base="$(basename "$deb_path")"

  if [[ "$base" != linux-image-*-vdtos_*.deb ]]; then
    echo "Invalid vdtos kernel deb filename: $base" >&2
    return 1
  fi

  pkg="${base%%_*}"
  pkg="${pkg%-vdtos}"
  printf '%s\n' "$pkg"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then kernel_pkg_from_deb "$@"; fi
