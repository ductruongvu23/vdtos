#!/usr/bin/env bash
set -euo pipefail

main() {
  if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <debs-dir> <out-dir>" >&2
    exit 1
  fi

  local debs_dir="$1"
  local out_dir="$2"

  if [[ -z "${APT_GPG_KEY_ID:-}" ]]; then
    echo "ERROR: APT_GPG_KEY_ID is required" >&2
    exit 1
  fi

  if [[ ! -d "$debs_dir" ]]; then
    echo "ERROR: debs directory not found: $debs_dir" >&2
    exit 1
  fi

  mkdir -p "$out_dir/pool/main" "$out_dir/dists/vdtos/main/binary-amd64"

  shopt -s nullglob
  local debs=("$debs_dir"/*.deb)
  shopt -u nullglob
  if (( ${#debs[@]} == 0 )); then
    echo "ERROR: no .deb files found in $debs_dir" >&2
    exit 1
  fi
  cp -f "${debs[@]}" "$out_dir/pool/main/"

  (
    cd "$out_dir"
    apt-ftparchive packages pool/main > dists/vdtos/main/binary-amd64/Packages
    gzip -9c dists/vdtos/main/binary-amd64/Packages > dists/vdtos/main/binary-amd64/Packages.gz

    local release_tmp
    release_tmp="$(mktemp)"
    apt-ftparchive \
      -o APT::FTPArchive::Release::Origin=VDTOS \
      -o APT::FTPArchive::Release::Label=VDTOS \
      -o APT::FTPArchive::Release::Suite=vdtos \
      -o APT::FTPArchive::Release::Codename=vdtos \
      -o APT::FTPArchive::Release::Architectures=amd64 \
      -o APT::FTPArchive::Release::Components=main \
      release dists/vdtos > "$release_tmp"
    mv "$release_tmp" dists/vdtos/Release

    gpg --batch --yes --pinentry-mode loopback -u "$APT_GPG_KEY_ID" \
      --clearsign -o dists/vdtos/InRelease dists/vdtos/Release
    gpg --batch --yes --pinentry-mode loopback -u "$APT_GPG_KEY_ID" \
      -abs -o dists/vdtos/Release.gpg dists/vdtos/Release
  )
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
