#!/usr/bin/env bash
set -euo pipefail

assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="${3:-values differ}"
  if [[ "$expected" != "$actual" ]]; then
    echo "FAIL: $msg: expected '$expected', got '$actual'" >&2
    exit 1
  fi
}

assert_fails() {
  if "$@"; then
    echo "FAIL: expected command to fail: $*" >&2
    exit 1
  fi
}
