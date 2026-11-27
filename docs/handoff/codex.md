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

---

## Quy trình điều phối (từ 2026-11-28)
Claude là người điều phối. Mỗi khi bạn xong việc hoặc được nhắc "làm tiếp":
1. `git fetch origin && git switch main && git pull --ff-only`
2. Đọc mục **Việc hiện tại** ngay bên dưới và làm theo. Mỗi việc làm trên một branch mới tạo từ `main`, tên `<agent>/<việc>`. Push xong là xong; Claude sẽ tự review và gộp.
3. Nếu mục đó ghi "Chờ" thì không làm gì cả.
4. Làm trong thư mục riêng của mình (Anti: `C:\Users\VDT\Documents\New_os`, Codex: `C:\Users\VDT\Documents\New_os-codex` qua `git worktree`), không đổi branch trong thư mục của agent kia.

## Việc hiện tại
**Sửa `evaluate` trong `tests/smoke.sh` để đọc được dòng có rác terminal ở đầu** (branch `codex/smoke-parse`, tạo từ `origin/main`, trong worktree `New_os-codex`).
CI run 46069964477: ISO boot được và báo đúng số liệu, nhưng smoke vẫn ra `FAIL: no VDTOS-BOOT`. Lý do là dòng thật trong `serial.log` trông như sau (serial-getty in mã escape lên cùng dòng):
`<ESC>[!p<ESC>]104<ESC>[?7h<ESC>[6n<ESC>[32766;32766H<ESC>[6nVDTOS-BOOT 9.161`
còn dòng tiếp theo là `VDTOS-MEM 360` (dòng này sạch).
Yêu cầu:
- Nhận `VDTOS-BOOT <số>` và `VDTOS-MEM <số>` ở **bất kỳ vị trí nào trong dòng**, không bắt buộc ở đầu dòng. Giá trị vẫn phải là số và kết thúc ở cuối dòng: `VDTOS-MEM 540oops` vẫn phải FAIL.
- Thêm fixture `tests/fixtures/serial.escapes.log`, chép đúng hai dòng trên (có ký tự ESC thật, ``), và test: `evaluate` trên fixture này với kvm=1 phải PASS.
- Các test cũ vẫn phải PASS.
Push xong là xong; job `unit` phải xanh.
