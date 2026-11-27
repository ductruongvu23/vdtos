#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

for t in "$SCRIPT_DIR"/test_*.sh; do
  echo "==> $t"
  bash "$t"
done

echo "ALL TESTS PASSED"
