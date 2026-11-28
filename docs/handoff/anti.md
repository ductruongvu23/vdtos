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
**Sửa bản live không có tài khoản và hình nền SVG không hiện** (branch `anti/live-user`, tạo từ `main`).
Ảnh chụp ISO v0.2.0 trong QEMU: LightDM hiện màn hình đăng nhập thay vì tự vào desktop. Đăng nhập bằng `user` / `live`
thì bị báo sai mật khẩu. Nền màn hình đăng nhập đen, không có `default.svg`.
Nguyên nhân: ISO build với `--apt-recommends false`, nên thiếu hai gói vốn chỉ là Recommends:
- `user-setup`: `live-config` cần gói này để tạo tài khoản live và bật tự đăng nhập cho LightDM.
- `librsvg2-common`: loader SVG cho gdk-pixbuf; thiếu gói này thì greeter và xfdesktop không vẽ được hình nền `.svg`.

Việc cần làm:
- Thêm `user-setup` vào `live/config/package-lists/desktop.list.chroot`, cùng dòng với `live-config`.
- Thêm `librsvg2-common` vào `live/config/package-lists/ui.list.chroot`, và vào `Depends` của `vdtos-base` trong
  `packaging/build-debs.sh` (máy đã cài cũng cần gói này để hiện hình nền khi `apt full-upgrade`).
- Test: `tests/test_packaging.sh` kiểm `Depends` có `librsvg2-common`; `test_packages.sh` sẵn có sẽ kiểm hai tên gói có trong trixie.
- Không sửa `--apt-recommends false`, không sửa `.github/workflows`, `Makefile`, `tests/smoke.sh`.

Push xong là xong; `unit`, `iso`, `smoke` phải xanh. Claude sẽ tự chạy ISO trong QEMU để xem có vào thẳng desktop không.
