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
**App "Tinh chỉnh Wine": Task 10 trong spec, phần app** (branch `codex/wine-settings`, tạo từ `main`,
làm trong `C:\Users\VDT\Documents\New_os-codex`).
Đọc Task 10 trong `docs/superpowers/specs/2026-11-27-vdtos-design.md`, mục **App tinh chỉnh `vdtos-wine-settings`**.
Người dùng đã duyệt thiết kế.
Bạn chỉ tạo 3 file: `packaging/vdtos-base/usr/bin/vdtos-wine-settings` (Python 3 + GTK 3 qua `gi`, chmod +x, shebang `#!/usr/bin/env python3`),
`packaging/vdtos-base/usr/share/applications/vdtos-wine-settings.desktop` và `tests/test_wine_settings.sh`.
- App chỉ gọi lệnh ngoài: `vdtos-wine apply-theme|set-dpi|reset` (Anti đang viết, cứ code theo interface trong spec), `winecfg`,
  `wine uninstaller`, `wine --version`, `xdg-open`. Không tự ghi registry.
- `--dry-run --self-test`: không mở cửa sổ, in ra mỗi dòng một lệnh sẽ chạy cho từng tùy chỉnh, exit 0. Test dựa vào đây.
- Không sửa `packaging/build-debs.sh`, `live/`, `tests/run.sh` (runner tự tìm `tests/test_*.sh`). Anti đã thêm
  `python3-gi gir1.2-gtk-3.0` vào `Depends`.
Push xong là xong; job `unit` phải xanh.
