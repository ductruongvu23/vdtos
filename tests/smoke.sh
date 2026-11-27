#!/usr/bin/env bash
set -euo pipefail

evaluate() {
    local serial_log=$1 kvm=$2
    if [[ "$kvm" != 0 && "$kvm" != 1 ]]; then
        echo 'FAIL: kvm must be 1 or 0' >&2
        return 1
    fi
    awk -v kvm="$kvm" '
        { sub(/\r$/, "") }
        /^VDTOS-MEM [0-9]+$/ { mem = $2; has_mem = 1 }
        /^VDTOS-BOOT [0-9]+([.][0-9]+)?$/ { boot = $2; has_boot = 1 }
        END {
            if (!has_mem) { print "FAIL: no VDTOS-MEM"; exit 1 }
            if (!has_boot) { print "FAIL: no VDTOS-BOOT"; exit 1 }
            if (mem >= 700) { print "FAIL: RAM " mem " MB (must be < 700)"; exit 1 }
            if (kvm == 1 && boot >= 30) {
                print "FAIL: boot " boot " s (must be < 30 with KVM)"; exit 1
            }
            if (kvm == 0) print "WARN: TCG boot time is not enforced"
            print "PASS: RAM " mem " MB, boot " boot " s"
        }
    ' "$serial_log"
}

main() (
    cd "$(dirname "${BASH_SOURCE[0]}")/.."
    local iso=out/vdtos-amd64.hybrid.iso boot_dir kvm=0 status=0
    [[ -f "$iso" ]] || { echo "FAIL: missing $iso" >&2; exit 1; }
    mkdir -p out
    boot_dir=$(mktemp -d out/boot.XXXXXX)
    trap 'rm -rf -- "$boot_dir"' EXIT
    xorriso -osirrox on -indev "$iso" -extract /live "$boot_dir"

    shopt -s nullglob
    local kernels=("$boot_dir"/vmlinuz*-vdtos*)
    local initrds=("$boot_dir"/initrd.img*-vdtos*)
    if (( ${#kernels[@]} == 0 )); then kernels=("$boot_dir"/vmlinuz*); fi
    if (( ${#initrds[@]} == 0 )); then initrds=("$boot_dir"/initrd.img*); fi
    if (( ${#kernels[@]} != 1 || ${#initrds[@]} != 1 )); then
        echo 'FAIL: expected one live kernel and one initrd in ISO' >&2
        exit 1
    fi
    [[ -e /dev/kvm ]] && kvm=1
    : > out/serial.log
    timeout 300 qemu-system-x86_64 \
        -accel kvm -accel tcg -cpu SandyBridge -smp 2 -m 8G \
        -cdrom "$iso" -kernel "${kernels[0]}" -initrd "${initrds[0]}" \
        -append 'boot=live components console=ttyS0 vdtos.test preempt=full' \
        -serial file:out/serial.log -display none || status=$?
    if (( status != 0 && status != 124 )); then
        echo "FAIL: QEMU exited with status $status" >&2
        exit 1
    fi
    evaluate out/serial.log "$kvm"
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
