#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIST_FILE="$ROOT_DIR/live/config/package-lists/desktop.list.chroot"

if ! command -v apt-cache >/dev/null 2>&1; then
  echo "SKIP: apt-cache not found; skipping package check"
  exit 0
fi

if [[ ! -f "$LIST_FILE" ]]; then
  echo "FAIL: missing $LIST_FILE" >&2
  exit 1
fi

missing=0
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%#*}"
  for pkg in $line; do
    case "$pkg" in
      vdtos-base|linux-image-vdtos) continue ;;
    esac
    if ! apt-cache show "$pkg" >/dev/null 2>&1; then
      echo "FAIL: package not found in apt-cache: $pkg" >&2
      missing=1
    fi
  done
done < "$LIST_FILE"

exit "$missing"
