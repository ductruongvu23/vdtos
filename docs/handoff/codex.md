# Giao việc cho Codex (phần phụ)

Bạn triển khai **Task 4, Step 1–4** của `docs/superpowers/plans/2026-11-27-vdtos.md`: `tests/smoke.sh` (hàm `evaluate` + `main`),
các fixture `tests/fixtures/serial.*.log`, `tests/test_smoke_eval.sh` và `Makefile`.
Step 5–6 (build ISO thật, `make test`) sẽ chạy sau khi branch của Antigravity đã merge.

## Quy tắc
- Branch: `codex/smoke` tạo từ `main`. Không commit thẳng vào `main`, không tạo tag.
- Chỉ tạo hoặc sửa các file vừa liệt kê. Antigravity đang làm `kernel/`, `live/`, `tests/lib.sh`, `tests/run.sh`, nên không đụng vào.
- `tests/lib.sh` chưa có trên `main`. Interface đã chốt như sau, cứ code theo:
  `assert_eq <expected> <actual> <msg>`, `assert_fails <cmd...>` (lỗi thì in msg rồi exit 1).
  Test của bạn `source tests/lib.sh`. Để test chạy được ngay, bạn được tạo bản tạm `tests/lib.sh` trên branch của mình;
  khi merge sẽ lấy bản của Antigravity.
- Dòng serial cần đọc: `VDTOS-BOOT <giây, số thập phân>` và `VDTOS-MEM <MB, số nguyên>`. Ngưỡng: RAM < 700, boot < 30 giây (chỉ áp khi có KVM).
- Script dùng `#!/usr/bin/env bash`, `set -euo pipefail`, xuống dòng LF, và chỉ chạy `main "$@"` khi file được gọi trực tiếp.
- Xong thì `git push -u origin codex/smoke`.

## Xong khi
- `bash tests/test_smoke_eval.sh` PASS với đủ 5 trường hợp pass / slow (kvm 1) / slow (kvm 0, có WARN) / heavy / hang.
- `make -n iso test` in ra đúng các lệnh như trong plan.
