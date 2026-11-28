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
**Kho apt để cập nhật tại chỗ** (branch `anti/apt-repo`, tạo từ `main`). Đọc **Task 7** trong spec trước.
Bạn làm:
1. `packaging/build-debs.sh <version> <kernel-deb> <out-dir>`: build `vdtos-base_<version>_all.deb` và
   `linux-image-vdtos_<X.Y.Z>_amd64.deb` bằng `dpkg-deb --build --root-owner-group` từ thư mục dựng tạm (không cần debhelper).
   Lấy X.Y.Z bằng `dpkg-deb -f <kernel-deb> Version` bỏ đuôi `-N`. File của `vdtos-base` lấy từ `packaging/vdtos-base/`
   (chuyển nguyên các file đang ở `live/config/includes.chroot/` sang đây bằng `git mv`, kèm `DEBIAN/postinst`).
2. `apt/build-repo.sh <debs-dir> <out-dir>`: dựng `pool/main/` + `dists/vdtos/main/binary-amd64/Packages{,.gz}` +
   `dists/vdtos/Release` bằng `apt-ftparchive`, rồi ký ra `InRelease` và `Release.gpg` bằng key trong keyring GPG hiện tại
   (id lấy từ biến `APT_GPG_KEY_ID`). Thiếu biến hoặc ký lỗi thì exit 1.
3. `live/`: bỏ `includes.chroot/` và hook 0100; `make iso` gọi `packaging/build-debs.sh` để thả hai gói vào `packages.chroot`
   và thêm `vdtos-base linux-image-vdtos` vào package list. `live/auto/config` giữ `--linux-packages` như hiện tại.
4. Test (thêm vào `tests/`, chạy qua `tests/run.sh`):
   - `test_packaging.sh`: dùng một kernel .deb giả (dựng bằng dpkg-deb trong test). Kiểm tra `vdtos-base` chứa đủ các file cũ,
     có keyring + `vdtos.sources`, `Depends` đúng; `linux-image-vdtos` có `Version` = X.Y.Z và `Depends: linux-image-X.Y.Z-vdtos`.
   - `test_apt_repo.sh`: tạo key GPG tạm (`gpg --batch --quick-gen-key` trong `GNUPGHOME` tạm, không mật khẩu), dựng kho,
     rồi `gpgv` kiểm `InRelease` qua được, và `Packages` có đủ hai gói. Thiếu `APT_GPG_KEY_ID` thì `build-repo.sh` phải fail.
- Bỏ qua phần public key thật `apt/vdtos-archive-keyring.asc` và job CI `apt`: Claude làm (key và GitHub Pages cần người dùng
  đồng ý). Trong `vdtos-base`, keyring lấy từ `apt/vdtos-archive-keyring.asc` nếu có; chưa có thì build vẫn chạy nhưng in WARN.
- Không sửa `.github/workflows/build.yml`. Push xong là xong; job `unit` phải xanh và job `smoke` vẫn phải xanh (ISO đổi cách cài file).
