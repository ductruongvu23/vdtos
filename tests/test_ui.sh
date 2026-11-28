#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/tests/lib.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Build a fake kernel deb and produce vdtos-base
kpkg="$tmp/fake-kpkg"
mkdir -p "$kpkg/DEBIAN" "$kpkg/boot"
cat > "$kpkg/DEBIAN/control" <<'EOF'
Package: linux-image-6.18.65-vdtos
Version: 6.18.65-1
Section: kernel
Priority: optional
Architecture: amd64
Maintainer: Test <test@example.com>
Description: Fake kernel for UI test
EOF
touch "$kpkg/boot/vmlinuz-6.18.65-vdtos"
dpkg-deb --build --root-owner-group "$kpkg" "$tmp/linux-image-6.18.65-vdtos_6.18.65-1_amd64.deb" >/dev/null

mkdir -p "$tmp/out"
bash "$ROOT_DIR/packaging/build-debs.sh" \
  "0.2.0" \
  "$tmp/linux-image-6.18.65-vdtos_6.18.65-1_amd64.deb" \
  "$tmp/out"

base_deb="$tmp/out/vdtos-base_0.2.0_all.deb"
contents="$(dpkg-deb -c "$base_deb")"

for f in \
  ./etc/xdg/vdtos/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
  ./etc/xdg/vdtos/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml \
  ./etc/xdg/vdtos/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml \
  ./etc/xdg/vdtos/xfce4/panel/default.xml \
  ./etc/X11/Xsession.d/55vdtos-xdg \
  ./etc/lightdm/lightdm-gtk-greeter.conf.d/50-vdtos.conf \
  ./usr/share/backgrounds/vdtos/default.svg; do
  if ! grep -qF "$f" <<< "$contents"; then
    echo "FAIL: $base_deb missing $f" >&2
    exit 1
  fi
done

deps="$(dpkg-deb -f "$base_deb" Depends)"
for pkg in \
  orchis-gtk-theme \
  papirus-icon-theme \
  fonts-inter \
  fonts-jetbrains-mono \
  xfce4-whiskermenu-plugin \
  xfce4-docklike-plugin \
  xfce4-power-manager-plugins \
  xfce4-pulseaudio-plugin; do
  if ! grep -qwF "$pkg" <<< "$deps"; then
    echo "FAIL: vdtos-base Depends missing $pkg (got: $deps)" >&2
    exit 1
  fi
done

# Validate XML and SVG files
while IFS= read -r -d '' f; do
  python3 -c 'import xml.dom.minidom, sys; xml.dom.minidom.parse(sys.argv[1])' "$f"
done < <(find "$ROOT_DIR/packaging/vdtos-base" \( -name '*.xml' -o -name '*.svg' \) -print0)

xsettings="$ROOT_DIR/packaging/vdtos-base/etc/xdg/vdtos/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml"
grep -qF 'Orchis-Dark-Compact' "$xsettings" || { echo "FAIL: xsettings missing Orchis-Dark-Compact" >&2; exit 1; }
grep -qF 'Papirus-Dark' "$xsettings" || { echo "FAIL: xsettings missing Papirus-Dark" >&2; exit 1; }
grep -qF 'Inter 10' "$xsettings" || { echo "FAIL: xsettings missing Inter 10" >&2; exit 1; }

xfwm4="$ROOT_DIR/packaging/vdtos-base/etc/xdg/vdtos/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml"
grep -qF 'name="use_compositing" type="bool" value="true"' "$xfwm4" || { echo "FAIL: xfwm4 missing use_compositing=true" >&2; exit 1; }

panel_xml="$ROOT_DIR/packaging/vdtos-base/etc/xdg/vdtos/xfce4/panel/default.xml"
python3 - "$panel_xml" <<'PY'
import sys, xml.etree.ElementTree as ET
tree = ET.parse(sys.argv[1])
p2 = tree.find(".//property[@name='panel-2']")
assert p2 is not None, "panel-2 missing"
ah = p2.find("./property[@name='autohide-behavior']")
assert ah is not None and ah.attrib.get("value") == "0", "panel-2 autohide-behavior must be 0"
PY

for rc_rel in \
  ./etc/xdg/vdtos/xfce4/panel/docklike-9.rc \
  ./etc/skel/.config/xfce4/panel/docklike-9.rc; do
  grep -qF "$rc_rel" <<< "$contents" || { echo "FAIL: $base_deb missing $rc_rel" >&2; exit 1; }
done

docklike_rc="$ROOT_DIR/packaging/vdtos-base/etc/xdg/vdtos/xfce4/panel/docklike-9.rc"
for app in firefox-esr.desktop thunar.desktop xfce4-terminal.desktop org.xfce.mousepad.desktop; do
  grep -qF "$app" "$docklike_rc" || { echo "FAIL: docklike-9.rc missing $app" >&2; exit 1; }
done

svg="$ROOT_DIR/packaging/vdtos-base/usr/share/backgrounds/vdtos/default.svg"
svg_size="$(wc -c < "$svg")"
if (( svg_size >= 51200 )); then
  echo "FAIL: default.svg too large ($svg_size bytes >= 51200)" >&2
  exit 1
fi

echo "test_ui.sh: OK"
