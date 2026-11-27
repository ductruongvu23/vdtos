# Giao việc cho Codex (phần phụ)

Bạn làm **Task 4, Step 1–4** trong `docs/superpowers/plans/2026-11-27-vdtos.md`: `tests/smoke.sh` (gồm hàm `evaluate` và `main`),
các fixture `tests/fixtures/serial.*.log`, `tests/test_smoke_eval.sh` và `Makefile`.
Step 5–6 (build ISO thật và chạy smoke test) sẽ tự chạy trên GitHub Actions sau khi phần của Antigravity và phần của bạn đều đã merge.

## Quy tắc
- **Không cần ảo hóa, không cần WSL hay Docker ở máy local.** Bạn chỉ viết code rồi push. Build và test chạy trên GitHub Actions
  (`.github/workflows/build.yml`, **không sửa file này**). Đọc file đó để biết CI gọi đúng những lệnh nào:
  `make kernel`, `make iso` (chạy bằng root trong docker debian:trixie, nên **không dùng `sudo`**),
  `bash tests/smoke.sh` (chạy trên Ubuntu có `/dev/kvm`, ISO nằm ở `out/vdtos-amd64.hybrid.iso`, phải ghi ra `out/serial.log`).
- Branch: `codex/smoke` tạo từ `main`. Không commit thẳng vào `main` (đã bị khóa), không tạo tag.
- Chỉ tạo hoặc sửa các file vừa liệt kê. Antigravity đang làm `kernel/`, `live/`, `tests/lib.sh`, `tests/run.sh`, nên bạn không đụng vào.
- `tests/lib.sh` chưa có trên `main`, nhưng interface đã chốt, bạn cứ code theo:
  `assert_eq <expected> <actual> <msg>` và `assert_fails <cmd...>` (lỗi thì in msg rồi exit 1). Test của bạn `source tests/lib.sh`.
  Để test chạy được ngay, bạn được tạo bản tạm `tests/lib.sh` trên branch của mình. Khi merge sẽ lấy bản của Antigravity.
- Dòng serial cần đọc: `VDTOS-BOOT <giây, số thập phân>` và `VDTOS-MEM <MB, số nguyên>`. Ngưỡng: RAM < 700, boot < 30 giây (ngưỡng boot chỉ áp khi có KVM).
- Script dùng `#!/usr/bin/env bash`, `set -euo pipefail`, xuống dòng LF, và chỉ chạy `main "$@"` khi file được gọi trực tiếp.
- Xong thì `git push -u origin codex/smoke`.

## Xong khi
- `bash tests/test_smoke_eval.sh` PASS đủ 5 trường hợp: pass / slow (kvm 1) / slow (kvm 0, có WARN) / heavy / hang.
  Chạy ở local bằng Git Bash, hoặc xem job `unit` khi branch đã có `tests/run.sh`.
- `make -n kernel iso` in ra các lệnh đúng như plan, không có `sudo`.
