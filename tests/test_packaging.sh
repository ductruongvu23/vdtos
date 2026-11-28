#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/tests/lib.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Build a fake kernel deb
kpkg="$tmp/fake-kpkg"
mkdir -p "$kpkg/DEBIAN" "$kpkg/boot"
cat > "$kpkg/DEBIAN/control" <<'EOF'
Package: linux-image-6.18.65-vdtos
Version: 6.18.65-1
Section: kernel
Priority: optional
Architecture: amd64
Maintainer: Test <test@example.com>
Description: Fake kernel for packaging test
EOF
touch "$kpkg/boot/vmlinuz-6.18.65-vdtos"
dpkg-deb --build --root-owner-group "$kpkg" "$tmp/linux-image-6.18.65-vdtos_6.18.65-1_amd64.deb" >/dev/null

# Provide a test keyring via APT_KEYRING
printf '%s\n' "-----BEGIN PGP PUBLIC KEY BLOCK-----" > "$tmp/test-keyring.asc"
mkdir -p "$tmp/out"

APT_KEYRING="$tmp/test-keyring.asc" bash "$ROOT_DIR/packaging/build-debs.sh" \
  "v0.2.0" \
  "$tmp/linux-image-6.18.65-vdtos_6.18.65-1_amd64.deb" \
  "$tmp/out"

base_deb="$tmp/out/vdtos-base_0.2.0_all.deb"
meta_deb="$tmp/out/linux-image-vdtos_6.18.65_amd64.deb"

[[ -f "$base_deb" ]] || { echo "FAIL: missing $base_deb" >&2; exit 1; }
[[ -f "$meta_deb" ]] || { echo "FAIL: missing $meta_deb" >&2; exit 1; }

contents="$(dpkg-deb -c "$base_deb")"
for f in \
  ./etc/sysctl.d/90-vdtos.conf \
  ./etc/systemd/system/vdtos-report.service \
  ./etc/udev/rules.d/60-iosched.rules \
  ./etc/xdg/vdtos/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml \
  ./usr/local/bin/vdtos-report \
  ./etc/apt/sources.list.d/vdtos.sources \
  ./usr/share/keyrings/vdtos-archive-keyring.asc; do
  if ! grep -qF "$f" <<< "$contents"; then
    echo "FAIL: $base_deb missing $f" >&2
    exit 1
  fi
done

if grep -qF "./etc/default/zramswap" <<< "$contents"; then
  echo "FAIL: $base_deb must not ship /etc/default/zramswap (owned by zram-tools)" >&2
  exit 1
fi

assert_eq "0.2.0" "$(dpkg-deb -f "$base_deb" Version)" "vdtos-base Version"
assert_eq "linux-image-vdtos, zram-tools, materia-gtk-theme, papirus-icon-theme, fonts-inter, fonts-jetbrains-mono, xfce4-whiskermenu-plugin, xfce4-docklike-plugin" "$(dpkg-deb -f "$base_deb" Depends)" "vdtos-base Depends"
assert_eq "6.18.65" "$(dpkg-deb -f "$meta_deb" Version)" "linux-image-vdtos Version"
assert_eq "linux-image-6.18.65-vdtos" "$(dpkg-deb -f "$meta_deb" Depends)" "linux-image-vdtos Depends"

# Test postinst configure_zramswap idempotency
source "$ROOT_DIR/packaging/vdtos-base/DEBIAN/postinst"
zram_cfg="$tmp/zramswap"
cat > "$zram_cfg" <<'EOF'
#ALGO=lz4
#PERCENT=50
PRIORITY=100
EOF

configure_zramswap "$zram_cfg"
configure_zramswap "$zram_cfg"

assert_eq "1" "$(grep -c '^ALGO=zstd$' "$zram_cfg")" "ALGO=zstd appears once"
assert_eq "1" "$(grep -c '^PERCENT=25$' "$zram_cfg")" "PERCENT=25 appears once"
assert_eq "1" "$(grep -c '^#\?ALGO=' "$zram_cfg")" "only one ALGO line"
assert_eq "1" "$(grep -c '^#\?PERCENT=' "$zram_cfg")" "only one PERCENT line"
assert_eq "1" "$(grep -c '^PRIORITY=100$' "$zram_cfg")" "unrelated lines preserved"

echo "test_packaging.sh: OK"
