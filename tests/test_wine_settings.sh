#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/tests/lib.sh"

app="$ROOT_DIR/packaging/vdtos-base/usr/bin/vdtos-wine-settings"
desktop="$ROOT_DIR/packaging/vdtos-base/usr/share/applications/vdtos-wine-settings.desktop"

[[ -f "$app" ]] || { echo "FAIL: missing $app" >&2; exit 1; }
[[ -f "$desktop" ]] || { echo "FAIL: missing $desktop" >&2; exit 1; }

python3 -m py_compile "$app"

if command -v desktop-file-validate >/dev/null 2>&1; then
  desktop-file-validate "$desktop"
fi

grep -qF 'Name=Tinh chỉnh Wine' "$desktop" || { echo "FAIL: desktop missing Vietnamese Name" >&2; exit 1; }
grep -qF 'Exec=vdtos-wine-settings' "$desktop" || { echo "FAIL: desktop missing Exec" >&2; exit 1; }
grep -qF 'Đã áp dụng. Mở lại app Windows để thấy thay đổi.' "$app" || { echo "FAIL: app missing reopen hint" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export WINEPREFIX="$tmp/wine-prefix"
out="$(python3 "$app" --dry-run --self-test)"

for expected in \
  "vdtos-wine apply-theme dark" \
  "vdtos-wine apply-theme light" \
  "vdtos-wine set-dpi 96" \
  "vdtos-wine set-dpi 120" \
  "vdtos-wine set-dpi 144" \
  "winecfg -v win10" \
  "winecfg -v win7" \
  "winecfg -v winxp" \
  "winecfg" \
  "xdg-open $WINEPREFIX/drive_c" \
  "wine uninstaller" \
  "vdtos-wine reset"; do
  grep -qF "$expected" <<< "$out" || { echo "FAIL: self-test output missing '$expected'" >&2; exit 1; }
done

# Verify packaged in vdtos-base
kpkg="$tmp/fake-kpkg"
mkdir -p "$kpkg/DEBIAN" "$kpkg/boot"
cat > "$kpkg/DEBIAN/control" <<'EOF'
Package: linux-image-6.18.65-vdtos
Version: 6.18.65-1
Section: kernel
Priority: optional
Architecture: amd64
Maintainer: Test <test@example.com>
Description: Fake kernel for wine settings test
EOF
touch "$kpkg/boot/vmlinuz-6.18.65-vdtos"
dpkg-deb --build --root-owner-group "$kpkg" "$tmp/linux-image-6.18.65-vdtos_6.18.65-1_amd64.deb" >/dev/null

mkdir -p "$tmp/out"
bash "$ROOT_DIR/packaging/build-debs.sh" \
  "0.2.0" \
  "$tmp/linux-image-6.18.65-vdtos_6.18.65-1_amd64.deb" \
  "$tmp/out"

contents="$(dpkg-deb -c "$tmp/out/vdtos-base_0.2.0_all.deb")"
grep -qF './usr/bin/vdtos-wine-settings' <<< "$contents" || { echo "FAIL: deb missing vdtos-wine-settings" >&2; exit 1; }
grep -qF './usr/share/applications/vdtos-wine-settings.desktop' <<< "$contents" || { echo "FAIL: deb missing vdtos-wine-settings.desktop" >&2; exit 1; }

echo "test_wine_settings.sh: OK"
