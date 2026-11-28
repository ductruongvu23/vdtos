#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/tests/lib.sh"
source "$ROOT_DIR/packaging/vdtos-base/usr/local/bin/vdtos-report"

assert_eq "8.2" "$(boot_seconds "graphical.target reached after 8.2s in userspace.")" "boot_seconds seconds"
assert_eq "64.512" "$(boot_seconds "graphical.target reached after 1min 4.512s in userspace.")" "boot_seconds min+s"
assert_eq "0.85" "$(boot_seconds "graphical.target reached after 850ms in userspace.")" "boot_seconds ms"

free_sample=$'               total        used        free      shared  buff/cache   available\nMem:            7936         512        6800          32         624        7200\nSwap:           1984           0        1984'
assert_eq "512" "$(mem_used_mb "$free_sample")" "mem_used_mb parses Mem used"

echo "test_report.sh: OK"
