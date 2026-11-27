#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/tests/lib.sh"
source "$ROOT_DIR/kernel/build.sh"

# Test 1: valid config passes
check_fragment "$ROOT_DIR/tests/fixtures/config.good" "$ROOT_DIR/kernel/config.fragment"

# Test 2: missing CONFIG_LRU_GEN_ENABLED=y fails and prints the missing line
assert_fails check_fragment "$ROOT_DIR/tests/fixtures/config.missing" "$ROOT_DIR/kernel/config.fragment"

out="$(check_fragment "$ROOT_DIR/tests/fixtures/config.missing" "$ROOT_DIR/kernel/config.fragment" 2>&1 || true)"
if [[ "$out" != *"CONFIG_LRU_GEN_ENABLED=y"* ]]; then
  echo "FAIL: expected output to contain CONFIG_LRU_GEN_ENABLED=y, got: $out" >&2
  exit 1
fi

echo "test_build.sh: OK"
