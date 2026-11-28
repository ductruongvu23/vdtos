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
**Giao diện hiện đại: Task 8 trong spec** (branch `anti/modern-ui`, tạo từ `main` **sau khi PR #28 đã gộp**).
Đọc Task 8 trong `docs/superpowers/specs/2026-11-27-vdtos-design.md` rồi làm đúng như ở đó. Bản thiết kế đã được người dùng duyệt.
- Mọi file mới nằm trong `packaging/vdtos-base/` (theo đúng đường dẫn cài đặt), thêm gói vào `Depends` trong `packaging/build-debs.sh`.
- Chuyển `packaging/vdtos-base/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml` sang `etc/xdg/vdtos/...` bằng `git mv`.
- Panel `default.xml`: id plugin phải duy nhất, mỗi plugin có `<property name="plugin-N" type="string" value="<tên>"/>`.
  Tên plugin: `whiskermenu`, `separator` (expand=true), `clock`, `systray`, `pulseaudio`, `power-manager-plugin`,
  `actions`, `docklike`. Kiểm tra tên bằng thư mục `/usr/share/xfce4/panel/plugins/*.desktop` của trixie.
- Hình nền SVG tự vẽ, viết tay bằng XML (gradient + chữ), < 50KB.
- Sửa kèm (nhỏ): `apt/build-repo.sh` đang sinh `dists/vdtos/Release` bằng `apt-ftparchive release dists/vdtos > dists/vdtos/Release`,
  nên file `Release` tự liệt kê chính nó. Ghi ra file tạm ngoài `dists/vdtos` rồi `mv` vào.
- Test (`tests/test_packaging.sh` hoặc file mới `tests/test_ui.sh`):
  - `vdtos-base` chứa đủ: `xsettings.xml`, `xfwm4.xml`, `xfce4-desktop.xml`, `panel/default.xml` dưới `/etc/xdg/vdtos/`,
    `/etc/X11/Xsession.d/55vdtos-xdg`, `/etc/lightdm/lightdm-gtk-greeter.conf.d/50-vdtos.conf`, `/usr/share/backgrounds/vdtos/default.svg`.
  - Mọi file `.xml` và `.svg` parse được (`python3 -c 'import xml.dom.minidom,sys; xml.dom.minidom.parse(sys.argv[1])'`).
  - `xsettings.xml` có `Materia-dark-compact`, `Papirus-Dark`, `Inter 10`; `xfwm4.xml` có `use_compositing` = true.
  - `Depends` của `vdtos-base` có đủ 6 gói mới; `test_packages.sh` đã tra tên gói, nên thêm 6 gói đó vào một file
    `live/config/package-lists/ui.list.chroot` để CI kiểm chúng có trong trixie.
  - NOTICE.md cập nhật như Task 8.
Push xong là xong; `unit`, `iso`, `smoke` phải xanh (smoke vẫn kiểm RAM < 700MB khi đã bật compositor).
