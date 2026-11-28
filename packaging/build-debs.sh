#!/usr/bin/env bash
set -euo pipefail

main() {
  if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <version> <kernel-deb> <out-dir>" >&2
    exit 1
  fi

  local script_dir root_dir version kernel_deb out_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  root_dir="$(cd "$script_dir/.." && pwd)"
  version="${1#v}"
  version="${version:-0.1.0}"
  kernel_deb="$2"
  out_dir="$3"

  if [[ ! -f "$kernel_deb" ]]; then
    echo "ERROR: kernel deb not found: $kernel_deb" >&2
    exit 1
  fi

  local kpkg_ver kver
  kpkg_ver="$(dpkg-deb -f "$kernel_deb" Version)"
  kver="${kpkg_ver%-*}"
  if [[ -z "$kver" ]]; then
    echo "ERROR: could not parse kernel version from $kernel_deb" >&2
    exit 1
  fi

  mkdir -p "$out_dir"
  rm -f "$out_dir"/vdtos-base_*.deb "$out_dir"/linux-image-vdtos_*.deb

  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  # Build vdtos-base_<version>_all.deb
  local base_dir="$tmp/vdtos-base"
  mkdir -p "$base_dir"
  cp -a "$script_dir/vdtos-base/." "$base_dir/"
  chmod 0755 "$base_dir/DEBIAN/postinst" "$base_dir/usr/local/bin/vdtos-report" "$base_dir/usr/bin/vdtos-wine"

  cat > "$base_dir/DEBIAN/control" <<EOF
Package: vdtos-base
Version: ${version}
Section: metapackages
Priority: optional
Architecture: all
Depends: linux-image-vdtos, zram-tools, orchis-gtk-theme, papirus-icon-theme, fonts-inter, fonts-jetbrains-mono, xfce4-whiskermenu-plugin, xfce4-docklike-plugin, xfce4-power-manager-plugins, xfce4-pulseaudio-plugin, librsvg2-common, wine, wine64, fonts-wine, fonts-liberation, libgl1, libgl1-mesa-dri, libasound2-plugins, gstreamer1.0-plugins-good, python3-gi, gir1.2-gtk-3.0
Maintainer: VDTOS <vdtos@example.invalid>
Description: VDTOS base configuration, tuning, and apt repository
EOF

  local keyring_src="${APT_KEYRING:-$root_dir/apt/vdtos-archive-keyring.asc}"
  if [[ -f "$keyring_src" ]]; then
    install -Dm644 "$keyring_src" "$base_dir/usr/share/keyrings/vdtos-archive-keyring.asc"
    mkdir -p "$base_dir/etc/apt/sources.list.d"
    cat > "$base_dir/etc/apt/sources.list.d/vdtos.sources" <<'EOF'
Types: deb
URIs: https://ductruongvu23.github.io/vdtos
Suites: vdtos
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/vdtos-archive-keyring.asc
EOF
  else
    echo "WARN: $keyring_src not found; skipping vdtos.sources and archive keyring" >&2
  fi

  dpkg-deb --build --root-owner-group "$base_dir" \
    "$out_dir/vdtos-base_${version}_all.deb"

  # Build linux-image-vdtos_<X.Y.Z>_amd64.deb
  local meta_dir="$tmp/linux-image-vdtos"
  mkdir -p "$meta_dir/DEBIAN"
  cat > "$meta_dir/DEBIAN/control" <<EOF
Package: linux-image-vdtos
Version: ${kver}
Section: kernel
Priority: optional
Architecture: amd64
Depends: linux-image-${kver}-vdtos
Maintainer: VDTOS <vdtos@example.invalid>
Description: VDTOS kernel metapackage
EOF

  dpkg-deb --build --root-owner-group "$meta_dir" \
    "$out_dir/linux-image-vdtos_${kver}_amd64.deb"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
