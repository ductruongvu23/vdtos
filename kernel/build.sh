#!/usr/bin/env bash
set -euo pipefail

check_fragment() {
  local config_file="$1"
  local fragment_file="$2"
  local missing=0
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    if ! grep -qxF -- "$line" "$config_file"; then
      echo "Missing config line: $line" >&2
      missing=1
    fi
  done < "$fragment_file"

  return "$missing"
}

main() {
  local repo_root kver kdir fragment tmp pkg deb
  local kcc="${KCC:-gcc}"
  repo_root="$PWD"
  kver="$(cat build/KVER)"
  kdir="$repo_root/build/linux-${kver}"
  fragment="$repo_root/kernel/config.fragment"

  if [[ ! -d "$kdir" ]]; then
    echo "Kernel source directory not found: $kdir" >&2
    exit 1
  fi

  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  pkg="$(apt-cache pkgnames linux-image- \
    | grep -E '^linux-image-[0-9]+\.[0-9]+.*-amd64$' \
    | grep -v -E '(-dbg|-unsigned|-cloud|-rt)' \
    | sort -V \
    | tail -n 1)"

  if [[ -z "$pkg" ]]; then
    echo "Failed to find Debian linux-image-*-amd64 package" >&2
    exit 1
  fi

  (cd "$tmp" && apt-get download "$pkg")
  dpkg-deb -x "$tmp"/*.deb "$tmp/extracted"
  cp "$tmp"/extracted/boot/config-* "$kdir/.config"

  cd "$kdir"
  ./scripts/config --set-str SYSTEM_TRUSTED_KEYS "" --set-str SYSTEM_REVOCATION_KEYS ""
  ./scripts/kconfig/merge_config.sh -m .config "$fragment"
  make CC="$kcc" olddefconfig
  check_fragment .config "$fragment"

  make -j"$(nproc)" CC="$kcc" bindeb-pkg

  mkdir -p "$repo_root/live/config/packages.chroot"
  rm -f "$repo_root/live/config/packages.chroot"/linux-image-*-vdtos*.deb

  for deb in "$repo_root/build"/linux-image-*-vdtos_*.deb; do
    [[ -f "$deb" ]] || continue
    [[ "$deb" == *-dbg_* ]] && continue
    cp "$deb" "$repo_root/live/config/packages.chroot/"
  done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
