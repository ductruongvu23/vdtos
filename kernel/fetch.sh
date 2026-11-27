#!/usr/bin/env bash
set -euo pipefail

pick_longterm() {
  local releases_json="$1"
  jq -r '.releases[] | select(.moniker == "longterm") | .version' "$releases_json" \
    | sort -V \
    | tail -n 1
}

verify_tarball() {
  local tar="$1"
  local sign="$2"
  [[ -f "$tar" && -f "$sign" ]] || return 1
  xz -dc "$tar" | gpg --verify "$sign" -
}

main() {
  mkdir -p build
  curl -fsSL https://www.kernel.org/releases.json -o build/releases.json

  local kver major base_url tar sign
  kver="$(pick_longterm build/releases.json)"
  if [[ -z "$kver" ]]; then
    echo "Failed to determine longterm kernel version" >&2
    exit 1
  fi

  major="${kver%%.*}"
  base_url="https://cdn.kernel.org/pub/linux/kernel/v${major}.x"
  tar="build/linux-${kver}.tar.xz"
  sign="build/linux-${kver}.tar.sign"

  [[ -f "$tar" ]] || curl -fsSL "${base_url}/linux-${kver}.tar.xz" -o "$tar"
  [[ -f "$sign" ]] || curl -fsSL "${base_url}/linux-${kver}.tar.sign" -o "$sign"

  gpg --locate-keys torvalds@kernel.org gregkh@kernel.org
  verify_tarball "$tar" "$sign"

  [[ -d "build/linux-${kver}" ]] || tar -xf "$tar" -C build
  printf '%s\n' "$kver" > build/KVER
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
