# Giao việc cho Antigravity (phần chính)

Bạn làm **Task 1, 2, 3** trong `docs/superpowers/plans/2026-11-27-vdtos.md`, theo đúng thứ tự.
Đọc kèm spec `docs/superpowers/specs/2026-11-27-vdtos-design.md`, cùng hai phần "Global Constraints" và "Review Focus" của plan.

## Quy tắc
- **Không cần ảo hóa, không cần WSL, VM hay Docker ở máy local.** Bạn chỉ viết code trên Windows rồi push.
  Mọi việc build và test trên Linux đều chạy ở GitHub Actions (`.github/workflows/build.yml`, **không sửa file này**).
  Xem kết quả ở tab Actions của repo https://github.com/ductruongvu23/vdtos.
- Test đơn vị chạy được ở local bằng Git Bash nếu máy có `jq`, `gpg`, `xz`. Nếu thiếu thì push lên rồi xem job `unit`.
- Script phải chạy được dưới quyền root trong Debian trixie và **không dùng `sudo`**.
- Branch: `anti/kernel-live` tạo từ `main`. Không commit thẳng vào `main` (đã bị khóa), không tạo tag.
- Mỗi task: viết test trước → thấy FAIL → viết code → test PASS → commit với message ghi trong plan → `git push -u origin anti/kernel-live`.
- Chỉ sửa các file Task 1–3 liệt kê, cộng thêm `.gitignore`. Không đụng `Makefile`, `tests/smoke.sh`, `tests/test_smoke_eval.sh` (phần của Codex).
- Giữ nguyên tên hàm và định dạng output ghi trong khối **Interfaces** của từng task, vì Codex code dựa vào đó:
  `assert_eq`, `assert_fails` (trong tests/lib.sh), và hai dòng serial `VDTOS-BOOT <giây>`, `VDTOS-MEM <MB>`.

## Xong khi
- Job `unit` trên branch `anti/kernel-live` xanh: `tests/run.sh` PASS và `lb config` chạy được.
- Job `kernel` sẽ tự chạy sau khi phần `Makefile` của Codex được merge vào. Lúc đó nếu job đỏ thì bạn sửa.
- Báo lại: link tới lần chạy Actions đã xanh.

---

## Quy trình điều phối (từ 2026-11-28)
Claude là người điều phối. Mỗi khi bạn xong việc hoặc được nhắc "làm tiếp":
1. `git fetch origin && git switch main && git pull --ff-only`
2. Đọc mục **Việc hiện tại** ngay bên dưới và làm theo. Mỗi việc làm trên một branch mới tạo từ `main`, tên `<agent>/<việc>`. Push xong là xong; Claude sẽ tự review và gộp.
3. Nếu mục đó ghi "Chờ" thì không làm gì cả.
4. Làm trong thư mục riêng của mình (Anti: `C:\Users\VDT\Documents\New_os`, Codex: `C:\Users\VDT\Documents\New_os-codex` qua `git worktree`), không đổi branch trong thư mục của agent kia.

## Việc hiện tại
**Sửa lỗi ISO thiếu kernel** (branch `anti/iso-kernel`, tạo từ `main`). Log CI run 46056716432, job `iso`:
`ls: cannot access 'binary/live/vmlinuz-*'` → `ln: failed to access 'binary/live/vmlinuz'` → `E: An unexpected failure occurred`.
Nguyên nhân: `--linux-packages none` làm live-build bỏ qua bước chép kernel (binary_linux-image), nên bước bootloader (syslinux) không tìm thấy `vmlinuz`. Hook `.hook.binary` chạy quá muộn nên không dùng được.
Cách sửa: trong `live/auto/config`, cho live-build cài và chép đúng kernel của mình:
- Lấy tên gói từ file `.deb` có trong `config/packages.chroot/`: `linux-image-6.18.65-vdtos_6.18.65-1_amd64.deb` → tên gói `linux-image-6.18.65-vdtos`.
- Truyền `--linux-flavours vdtos --linux-packages "linux-image-6.18.65"` (live-build tự ghép thành `<packages>-<flavour>`). Phiên bản phải đọc từ tên file, không viết cứng.
- Nếu không có file `.deb` (job `unit` chạy `lb config` khi chưa build kernel) thì dùng `--linux-packages none` và in ra cảnh báo, để `lb config` vẫn chạy được.
- Viết test trong `tests/` cho hàm tách tên gói từ tên file `.deb`. Tách hàm này ra file riêng có thể `source` được, ví dụ `live/kernel-pkg.sh` với hàm `kernel_pkg_from_deb <file>` trả về `linux-image-6.18.65`.
Không sửa `kernel/build.sh` trong lần này (branch `anti/ccache` của bạn đang chờ gộp riêng).
Push xong là xong; job `unit` phải xanh. Claude sẽ gộp; job `iso`/`smoke` trên `main` sẽ kiểm tra thật (kernel đã có sẵn trong cache, nên CI không phải build lại kernel).
