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
Description: Fake kernel for Wine test
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
  ./usr/bin/vdtos-wine \
  ./usr/share/vdtos/wine/dark.reg \
  ./usr/share/vdtos/wine/light.reg \
  ./usr/share/applications/vdtos-wine-run.desktop \
  ./etc/xdg/vdtos/mimeapps.list \
  ./etc/X11/Xsession.d/56vdtos-wine; do
  grep -qF "$f" <<< "$contents" || { echo "FAIL: $base_deb missing $f" >&2; exit 1; }
done

# Check wine.list.chroot packages are in Depends
wine_list="$ROOT_DIR/live/config/package-lists/wine.list.chroot"
[[ -f "$wine_list" ]] || { echo "FAIL: missing $wine_list" >&2; exit 1; }
deps="$(dpkg-deb -f "$base_deb" Depends)"
for pkg in $(cat "$wine_list"); do
  grep -qwF "$pkg" <<< "$deps" || { echo "FAIL: vdtos-base Depends missing $pkg" >&2; exit 1; }
done

# Validate .desktop if desktop-file-validate is available
desktop_file="$ROOT_DIR/packaging/vdtos-base/usr/share/applications/vdtos-wine-run.desktop"
if command -v desktop-file-validate >/dev/null 2>&1; then
  desktop-file-validate "$desktop_file"
fi

# Validate .reg headers and required keys
dark_reg="$ROOT_DIR/packaging/vdtos-base/usr/share/vdtos/wine/dark.reg"
light_reg="$ROOT_DIR/packaging/vdtos-base/usr/share/vdtos/wine/light.reg"
assert_eq "Windows Registry Editor Version 5.00" "$(head -n 1 "$dark_reg")" "dark.reg header"
assert_eq "Windows Registry Editor Version 5.00" "$(head -n 1 "$light_reg")" "light.reg header"
grep -qF '"MS Shell Dlg"="Inter"' "$dark_reg" || { echo "FAIL: dark.reg missing Inter font substitute" >&2; exit 1; }
grep -qF '"Decorated"="Y"' "$dark_reg" || { echo "FAIL: dark.reg missing Decorated=Y" >&2; exit 1; }
grep -qF '"ThemeActive"="0"' "$dark_reg" || { echo "FAIL: dark.reg missing ThemeActive=0" >&2; exit 1; }
grep -qF '"ThemeActive"="1"' "$light_reg" || { echo "FAIL: light.reg missing ThemeActive=1" >&2; exit 1; }

# Validate mimeapps.list
mimeapps="$ROOT_DIR/packaging/vdtos-base/etc/xdg/vdtos/mimeapps.list"
for mime in application/x-ms-dos-executable application/x-msi application/x-ms-shortcut; do
  grep -qF "${mime}=vdtos-wine-run.desktop" "$mimeapps" || { echo "FAIL: mimeapps.list missing $mime" >&2; exit 1; }
done

# Validate vdtos-wine --dry-run subcommands
vw="$ROOT_DIR/packaging/vdtos-base/usr/bin/vdtos-wine"
export WINEPREFIX="$tmp/nonexistent-wine"

out_init="$(bash "$vw" --dry-run init)"
grep -qF 'wineboot -i' <<< "$out_init" || { echo "FAIL: init dry-run missing wineboot -i" >&2; exit 1; }
grep -qF 'dark.reg' <<< "$out_init" || { echo "FAIL: init dry-run missing dark.reg" >&2; exit 1; }
grep -qF 'wineserver -w' <<< "$out_init" || { echo "FAIL: init dry-run missing wineserver -w" >&2; exit 1; }

out_run="$(bash "$vw" --dry-run run /tmp/app.exe)"
grep -qF 'wine start /unix /tmp/app.exe' <<< "$out_run" || { echo "FAIL: run dry-run missing wine start" >&2; exit 1; }

out_theme="$(bash "$vw" --dry-run apply-theme light)"
grep -qF 'wine regedit /usr/share/vdtos/wine/light.reg' <<< "$out_theme" || { echo "FAIL: apply-theme dry-run mismatch" >&2; exit 1; }

out_dpi="$(bash "$vw" --dry-run set-dpi 120)"
grep -qF 'LogPixels' <<< "$out_dpi" || { echo "FAIL: set-dpi dry-run missing LogPixels" >&2; exit 1; }
grep -qF '120' <<< "$out_dpi" || { echo "FAIL: set-dpi dry-run missing 120" >&2; exit 1; }

mkdir -p "$WINEPREFIX"
out_reset="$(bash "$vw" --dry-run reset)"
grep -qF 'mv ' <<< "$out_reset" || { echo "FAIL: reset dry-run missing mv backup" >&2; exit 1; }
grep -qF 'wineboot -i' <<< "$out_reset" || { echo "FAIL: reset dry-run missing wineboot -i" >&2; exit 1; }

assert_fails bash "$vw" --dry-run apply-theme invalid
assert_fails bash "$vw" --dry-run set-dpi 999
assert_fails bash "$vw" --dry-run unknown-cmd

# Check wine32 hook exists and verifies 32-bit notepad.exe
wine32_hook="$ROOT_DIR/live/config/hooks/live/0010-wine32.hook.chroot"
[[ -x "$wine32_hook" ]] || { echo "FAIL: missing or non-executable $wine32_hook" >&2; exit 1; }
grep -qF 'dpkg --add-architecture i386' "$wine32_hook" || { echo "FAIL: hook missing i386 arch" >&2; exit 1; }
grep -qF 'wine32:i386' "$wine32_hook" || { echo "FAIL: hook missing wine32:i386" >&2; exit 1; }
grep -qF 'notepad.exe' "$wine32_hook" || { echo "FAIL: hook missing notepad.exe check" >&2; exit 1; }

echo "test_wine.sh: OK"
