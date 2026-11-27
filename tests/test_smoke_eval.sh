#!/usr/bin/env bash
set -euo pipefail

main() {
    cd "$(dirname "${BASH_SOURCE[0]}")/.."
    source tests/lib.sh
    source tests/smoke.sh

    evaluate tests/fixtures/serial.pass.log 1
    assert_fails evaluate tests/fixtures/serial.slow.log 1
    local output
    output=$(evaluate tests/fixtures/serial.slow.log 0)
    [[ "$output" == *WARN* ]] || { echo 'FAIL: TCG must print WARN'; exit 1; }
    assert_fails evaluate tests/fixtures/serial.heavy.log 1
    output=$(evaluate tests/fixtures/serial.hang.log 1 2>&1) && {
        echo 'FAIL: hung boot passed'; exit 1;
    }
    [[ "$output" == *'no VDTOS-MEM'* ]] || { echo 'FAIL: missing memory diagnostic'; exit 1; }
    echo 'PASS: smoke evaluation (5 cases)'

    evaluate <(printf 'VDTOS-BOOT 29.999\r\nVDTOS-MEM 699\r\n') 1
    assert_fails evaluate <(printf 'VDTOS-BOOT 30\nVDTOS-MEM 540\n') 1
    assert_fails evaluate <(printf 'VDTOS-BOOT 12.1\nVDTOS-MEM 700\n') 0
    assert_fails evaluate <(printf 'VDTOS-MEM 540\n') 0
    assert_fails evaluate <(printf 'VDTOS-BOOT 12.1\nVDTOS-MEM 540oops\n') 1
    assert_fails evaluate tests/fixtures/serial.pass.log invalid
    echo 'PASS: thresholds, CRLF and invalid reports'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
