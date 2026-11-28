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
**Sửa lỗi ISO: `vdtos-base` đè file của `zram-tools`** (tiếp tục trên branch `anti/apt-repo`; Claude đã merge `main` vào
branch này nên trước tiên `git fetch && git switch anti/apt-repo && git pull --ff-only`). PR #28.
Log CI run 46117280262, job `iso`:
`dpkg: error processing archive .../vdtos-base_0.1.0_all.deb (--unpack): trying to overwrite '/etc/default/zramswap', which is also in package zram-tools`.
Nguyên nhân: một file chỉ được thuộc về một gói. Trước đây `includes.chroot` chép đè lặng lẽ, giờ đóng gói thì dpkg chặn.
Cách sửa:
- Bỏ `packaging/vdtos-base/etc/default/zramswap` khỏi gói. Trong `DEBIAN/postinst`, sửa thẳng file của `zram-tools`:
  đặt `ALGO=zstd` và `PERCENT=25` (sửa dòng có sẵn, kể cả dòng đang bị comment `#ALGO=`; chưa có thì thêm vào cuối).
  `Depends: zram-tools` đã đảm bảo file có trước khi postinst chạy. Chạy lại nhiều lần phải ra cùng kết quả.
- Kiểm tra các file còn lại của `vdtos-base` không thuộc gói Debian nào khác (tra https://packages.debian.org/ phần
  "Search the contents of packages", suite trixie). File nào bị trùng thì xử lý cùng kiểu trên.
- Test: `test_packaging.sh` bỏ `./etc/default/zramswap` khỏi danh sách và kiểm tra gói **không** chứa nó; thêm test cho đoạn
  sửa zramswap (tách thành hàm, chạy trên file tạm có dòng `#ALGO=lz4` và `#PERCENT=50`, chạy hai lần, kết quả đúng một dòng mỗi biến).
Push lên `anti/apt-repo` là xong; job `unit`, `iso` và `smoke` phải xanh.
