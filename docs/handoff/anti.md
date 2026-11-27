# Giao việc cho Antigravity (phần chính)

Bạn triển khai **Task 1, 2, 3** của `docs/superpowers/plans/2026-11-27-newos.md`, đúng thứ tự.
Đọc kèm spec `docs/superpowers/specs/2026-11-27-newos-design.md`, phần "Global Constraints" và "Review Focus" của plan.

## Quy tắc
- Làm trong WSL2 Debian 13. Clone repo vào `~/New_os`, **không** làm trong `/mnt/c`.
- Branch: `anti/kernel-live` tạo từ `main`. Không commit thẳng vào `main`, không tạo tag.
- Mỗi task: viết test trước → chạy thấy FAIL → code → `bash tests/run.sh` PASS → commit theo message trong plan.
- Chỉ sửa file mà Task 1–3 liệt kê, cộng `.gitignore`. Không sửa `Makefile`, `tests/smoke.sh`, `tests/test_smoke_eval.sh` (Codex làm).
- Giữ đúng tên hàm và định dạng output trong khối **Interfaces** của từng task, vì Codex code dựa vào đó:
  `assert_eq`, `assert_fails` (tests/lib.sh), dòng serial `NEWOS-BOOT <giây>` và `NEWOS-MEM <MB>`.
- Làm xong mỗi task thì `git push -u origin anti/kernel-live`.

## Xong khi
- `bash tests/run.sh` PASS.
- `bash kernel/build.sh` ra đúng 1 file `live/config/packages.chroot/linux-image-*-newos*.deb`.
- `cd live && lb config` exit 0.
- Ghi vào mô tả PR (hoặc báo lại): phiên bản kernel đã build và output của `tests/run.sh`.
