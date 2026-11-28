#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/tests/lib.sh"

if ! command -v apt-ftparchive >/dev/null 2>&1; then
  echo "SKIP: apt-ftparchive not found; skipping apt repo test"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Build a fake kernel deb and produce vdtos-base + linux-image-vdtos
kpkg="$tmp/fake-kpkg"
mkdir -p "$kpkg/DEBIAN" "$kpkg/boot"
cat > "$kpkg/DEBIAN/control" <<'EOF'
Package: linux-image-6.18.65-vdtos
Version: 6.18.65-1
Section: kernel
Priority: optional
Architecture: amd64
Maintainer: Test <test@example.com>
Description: Fake kernel for apt repo test
EOF
touch "$kpkg/boot/vmlinuz-6.18.65-vdtos"
dpkg-deb --build --root-owner-group "$kpkg" "$tmp/linux-image-6.18.65-vdtos_6.18.65-1_amd64.deb" >/dev/null

mkdir -p "$tmp/debs"
bash "$ROOT_DIR/packaging/build-debs.sh" \
  "0.2.0" \
  "$tmp/linux-image-6.18.65-vdtos_6.18.65-1_amd64.deb" \
  "$tmp/debs"

# Missing APT_GPG_KEY_ID must fail
assert_fails env -u APT_GPG_KEY_ID bash "$ROOT_DIR/apt/build-repo.sh" "$tmp/debs" "$tmp/repo"

# Generate throwaway GPG key
export GNUPGHOME="$tmp/gnupg"
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"
gpg --batch --pinentry-mode loopback --passphrase '' \
  --quick-generate-key "VDTOS Apt Test <apt@example.com>" default default never >/dev/null 2>&1
key_id="$(gpg --list-secret-keys --with-colons | awk -F: '/^fpr:/ {print $10; exit}')"
gpg --export "$key_id" > "$tmp/pub.gpg"

APT_GPG_KEY_ID="$key_id" bash "$ROOT_DIR/apt/build-repo.sh" "$tmp/debs" "$tmp/repo"

mkdir -p "$tmp/verify-gnupg"
chmod 700 "$tmp/verify-gnupg"
GNUPGHOME="$tmp/verify-gnupg" gpg --no-default-keyring --keyring "$tmp/pub.gpg" --verify "$tmp/repo/dists/vdtos/InRelease"
GNUPGHOME="$tmp/verify-gnupg" gpg --no-default-keyring --keyring "$tmp/pub.gpg" --verify "$tmp/repo/dists/vdtos/Release.gpg" "$tmp/repo/dists/vdtos/Release"

pkgs_file="$tmp/repo/dists/vdtos/main/binary-amd64/Packages"
[[ -f "$pkgs_file" ]] || { echo "FAIL: missing $pkgs_file" >&2; exit 1; }
[[ -f "$tmp/repo/dists/vdtos/main/binary-amd64/Packages.gz" ]] || { echo "FAIL: missing Packages.gz" >&2; exit 1; }
grep -q '^Package: vdtos-base$' "$pkgs_file" || { echo "FAIL: vdtos-base missing from Packages" >&2; exit 1; }
grep -q '^Package: linux-image-vdtos$' "$pkgs_file" || { echo "FAIL: linux-image-vdtos missing from Packages" >&2; exit 1; }

echo "test_apt_repo.sh: OK"
