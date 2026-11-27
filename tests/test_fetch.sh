#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/tests/lib.sh"
source "$ROOT_DIR/kernel/fetch.sh"

# Test 1: pick_longterm chooses highest version by version sort, not string sort
assert_eq "6.12.9" "$(pick_longterm "$ROOT_DIR/tests/fixtures/releases.json")" "pick_longterm selects 6.12.9"

# Test 2: verify_tarball passes valid signature and rejects tampered or missing signature
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export GNUPGHOME="$tmp/gnupg"
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"

gpg --batch --pinentry-mode loopback --passphrase '' \
  --quick-generate-key "VDTOS Test <test@example.com>" default default never >/dev/null 2>&1

printf 'vdtos kernel tarball test payload\n' > "$tmp/test.tar"
gpg --batch --yes --armor --detach-sign -o "$tmp/test.tar.sign" "$tmp/test.tar"
xz -z "$tmp/test.tar"

verify_tarball "$tmp/test.tar.xz" "$tmp/test.tar.sign"

# Tamper with the compressed tarball
cp "$tmp/test.tar.xz" "$tmp/tampered.tar.xz"
printf 'x' >> "$tmp/tampered.tar.xz"
assert_fails verify_tarball "$tmp/tampered.tar.xz" "$tmp/test.tar.sign"

# Missing signature file
rm -f "$tmp/test.tar.sign"
assert_fails verify_tarball "$tmp/test.tar.xz" "$tmp/test.tar.sign"

echo "test_fetch.sh: OK"
