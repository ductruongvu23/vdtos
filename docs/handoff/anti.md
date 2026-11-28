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
**Dock hiện rõ ở cạnh dưới màn hình và sửa lỗi plugin nguồn** (branch `anti/dock`, tạo từ `main` sau PR #41).
Ảnh chụp ISO từ run 46141959434 cho thấy desktop đã tự đăng nhập, có hình nền và menu. Còn hai lỗi:
1. Vừa vào desktop là hiện hộp thoại *Plugin "power-manager-plugin" could not be loaded*. Gói `xfce4-power-manager-plugins`
   chỉ là Recommends nên không có trong ISO (vì `--apt-recommends false`).
2. Không thấy dock. Trong `packaging/vdtos-base/etc/xdg/vdtos/xfce4/panel/default.xml`, `panel-2` có `autohide-behavior` = 1
   và `length` = 1. docklike lại chưa ghim ứng dụng nào, nên panel co lại gần như không còn gì.

Việc cần làm:
- Thêm `xfce4-power-manager-plugins` vào `live/config/package-lists/ui.list.chroot` và vào `Depends` của `vdtos-base` (`packaging/build-debs.sh`).
  Kiểm tra các plugin còn lại của panel (`pulseaudio`, `systray`, `actions`, `docklike`, `whiskermenu`) xem gói chứa chúng
  có nằm trong danh sách gói không. Gói nào chỉ là Recommends thì thêm luôn, ví dụ `xfce4-pulseaudio-plugin`.
- `panel-2`, tức dock: giữ ở cạnh dưới, căn giữa (`p=10`); `autohide-behavior` = 0 (luôn hiện); `size` 48; nền bo tròn hoặc trong mờ nhẹ nếu Orchis hỗ trợ.
- Ghim sẵn ứng dụng vào docklike: Firefox ESR, Thunar, Terminal, Mousepad. Cấu hình của docklike nằm ở file
  `xfce4/panel/docklike-9.rc` (9 là id plugin). Đặt file này dưới `/etc/xdg/vdtos/`; nếu docklike không đọc XDG_CONFIG_DIRS thì
  chép vào `/etc/skel/.config/xfce4/panel/`. Đọc mã nguồn hoặc tài liệu docklike của trixie để lấy đúng định dạng khoá `pinned`.
- Test (`tests/test_ui.sh`): `Depends` có `xfce4-power-manager-plugins`; `default.xml` của `panel-2` có `autohide-behavior` = 0;
  file cấu hình docklike có trong gói và liệt kê đủ 4 file `.desktop`; mọi XML parse được.
- Không sửa `.github/workflows`, `Makefile`, `tests/smoke.sh`.

Push xong là xong; `unit`, `iso`, `smoke` phải xanh. Claude sẽ chạy ISO trong QEMU và chụp dock.
