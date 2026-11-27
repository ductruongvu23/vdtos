# VDTOS: distro desktop nhẹ, kernel từ kernel.org, userspace Debian

## Context
Thư mục `C:\Users\VDT\Documents\New_os` đang trống và chưa có git. Mục tiêu là một OS desktop cho máy cũ, dùng kernel
tự build từ kernel.org. Máy thấp nhất: x86_64, i3 thế hệ 2 (Sandy Bridge), RAM 8GB. Đã chốt dùng userspace Debian 13 (trixie).
Giả định chưa được xác nhận: máy yếu ở CPU và có thể dùng HDD. RAM 8GB là đủ, nên tối ưu tập trung vào phản hồi
nhanh, ít dịch vụ nền, giao diện nhẹ, ít đọc ghi đĩa.

## Tiêu chí thành công
- Ra được `out/vdtos-amd64.hybrid.iso`, boot được từ USB, chạy live và có trình cài đặt.
- QEMU `-cpu SandyBridge -smp 2 -m 8G` (có KVM): vào được desktop XFCE, có mạng, có âm thanh, Firefox ESR chạy được.
- Lúc nhàn rỗi dùng < 700MB RAM. `graphical.target` đạt trong < 30s.

## Cấu trúc repo
```
Makefile
kernel/fetch.sh  kernel/build.sh  kernel/config.fragment
live/auto/config
live/config/package-lists/desktop.list.chroot
live/config/includes.chroot/etc/{default/zramswap, sysctl.d/90-vdtos.conf, udev/rules.d/60-iosched.rules}
live/config/includes.chroot/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml
live/config/includes.chroot/etc/systemd/system/vdtos-report.service
live/config/includes.chroot/usr/local/bin/vdtos-report
live/config/hooks/live/0100-enable-report.hook.chroot
tests/smoke.sh
docs/superpowers/specs/2026-11-27-vdtos-design.md
README.md
```

## Task 0: Máy build (người dùng tự chạy, cần quyền admin)
```powershell
wsl --install -d Debian
```
Sau đó vào WSL chạy: `sudo apt install build-essential bc bison flex libssl-dev libelf-dev dwarves rsync cpio kmod dpkg-dev fakeroot gnupg2 curl jq xz-utils live-build qemu-system-x86 xorriso`.
Repo nằm trên ổ Linux của WSL (`~/New_os`), **không** đặt ở `/mnt/c`. Lý do: live-build cần chmod và device node,
mà NTFS không hỗ trợ. Thư mục Windows hiện tại chỉ giữ bản git để đồng bộ.

## Task 1: git init + spec
Chạy `git init`, ghi phần thiết kế ở file này vào `docs/superpowers/specs/2026-11-27-vdtos-design.md` và `README.md`
(ngắn: cách build, cách test), rồi commit.

## Task 2: Lấy kernel (`kernel/fetch.sh`)
- Đọc `https://www.kernel.org/releases.json`, chọn bản `moniker == "longterm"` có số phiên bản lớn nhất bằng `jq`.
- Tải `linux-X.Y.Z.tar.xz` và `linux-X.Y.Z.tar.sign` về `build/`.
- Kiểm tra chữ ký: `xz -dc tar.xz | gpg --verify tar.sign -`. Key lấy qua `gpg --locate-keys torvalds@kernel.org gregkh@kernel.org`
  (cách kernel.org hướng dẫn). Chữ ký sai thì exit 1, không giải nén.
- Ghi số phiên bản vào `build/KVER` cho build.sh đọc.

## Task 3: Cấu hình + build kernel (`kernel/build.sh`, `kernel/config.fragment`)
- Lấy config gốc của Debian: chạy `apt-get download` gói `linux-image-*-amd64` mới nhất của trixie, rồi `dpkg-deb -x`
  để lấy `boot/config-*` làm `.config`. Config Debian đã có sẵn đủ driver cho phần cứng desktop phổ biến.
- `scripts/config --set-str SYSTEM_TRUSTED_KEYS "" --set-str SYSTEM_REVOCATION_KEYS ""`, vì cert của Debian không có trong cây kernel.org.
- `config.fragment` (giữ nhỏ, cái nào Debian đã có thì không ghi lại):
  ```
  CONFIG_LOCALVERSION="-vdtos"
  CONFIG_HZ_1000=y
  CONFIG_HZ=1000
  CONFIG_LRU_GEN=y
  CONFIG_LRU_GEN_ENABLED=y
  CONFIG_DEBUG_INFO_NONE=y
  # CONFIG_DEBUG_INFO_DWARF5 is not set
  # CONFIG_DEBUG_INFO_BTF is not set
  ```
  Preempt dùng `PREEMPT_DYNAMIC` (Debian đã bật) cộng tham số boot `preempt=full`, như vậy không phải sửa config.
  CPU để generic x86-64 nên máy mới hơn vẫn chạy được.
- `scripts/kconfig/merge_config.sh -m .config ../../kernel/config.fragment && make olddefconfig`.
  Sau đó dùng grep kiểm tra lại từng dòng trong fragment có thật trong `.config` không. Thiếu dòng nào thì exit 1,
  vì merge có thể lặng lẽ bỏ qua.
- `make -j$(nproc) bindeb-pkg`, rồi chép **chỉ** `linux-image-*-vdtos*.deb` vào `live/config/packages.chroot/`.

## Task 4: Cấu hình live-build (`live/auto/config`)
```sh
lb config noauto \
  --distribution trixie \
  --archive-areas "main contrib non-free non-free-firmware" \
  --linux-packages none \
  --apt-recommends false \
  --debian-installer live \
  --iso-volume VDTOS --image-name vdtos \
  --bootappend-live "boot=live components quiet splash preempt=full" \
  "${@}"
```
`--linux-packages none` để không kéo kernel của Debian vào. Kernel của mình vào qua `packages.chroot`.

`desktop.list.chroot`:
```
live-boot live-config live-config-systemd initramfs-tools sudo locales
xserver-xorg-core xserver-xorg-input-libinput xserver-xorg-video-intel
xfce4 xfce4-terminal thunar mousepad lightdm lightdm-gtk-greeter
network-manager-gnome pipewire-audio wireplumber pavucontrol
firefox-esr fonts-noto-core zram-tools intel-microcode
firmware-misc-nonfree firmware-realtek firmware-iwlwifi
```
Phần chỉnh để máy nhẹ hơn (`includes.chroot`):
- `etc/default/zramswap`: `ALGO=zstd` `PERCENT=25`
- `etc/sysctl.d/90-vdtos.conf`: `vm.swappiness=100` (swap ra zram rẻ hơn đọc lại từ HDD)
- `etc/udev/rules.d/60-iosched.rules`: ổ có `queue/rotational==1` thì đặt `scheduler=bfq`
- `xfwm4.xml`: `use_compositing=false`

## Task 5: Đo đạc khi test (`vdtos-report`)
- `vdtos-report.service`: `After=graphical.target`, `ConditionKernelCommandLine=vdtos.test`. Bản phát hành không bị ảnh hưởng.
- `/usr/local/bin/vdtos-report`: chạy `systemctl is-system-running --wait`, sau đó ghi ra `/dev/ttyS0`
  hai dòng `VDTOS-BOOT <giây tới graphical.target từ systemd-analyze>` và `VDTOS-MEM <MB used từ free -m>`.
- Hook `0100-enable-report.hook.chroot`: `systemctl enable vdtos-report.service`.

## Task 6: `tests/smoke.sh` + `Makefile`
- smoke.sh lấy `live/vmlinuz*` và `live/initrd.img*` ra khỏi ISO bằng `xorriso -osirrox on -extract`, rồi chạy:
  `timeout 300 qemu-system-x86_64 -accel kvm -accel tcg -cpu SandyBridge -smp 2 -m 8G -cdrom ISO -kernel … -initrd …
  -append "boot=live components console=ttyS0 vdtos.test preempt=full" -serial file:out/serial.log -display none`.
- grep `VDTOS-MEM`. Lớn hơn 700 hoặc không thấy dòng này thì FAIL. `VDTOS-BOOT` > 30 cũng FAIL, nhưng chỉ kiểm tra
  khi có `/dev/kvm`. Với TCG thì chỉ in cảnh báo, vì giả lập chậm nên đo thời gian không có ý nghĩa.
- Makefile: `kernel` (fetch + build), `iso` (`cd live && lb clean && lb config && sudo lb build`, log ghi vào `out/build.log`, ISO chép ra `out/`), `test`, `clean`.
- Mọi script dùng `set -euo pipefail`.

## Kiểm chứng
1. `make kernel` ra được file `.deb` có `-vdtos`. Chạy `dpkg-deb -c` trên file đó phải thấy `boot/vmlinuz-*-vdtos`.
2. `make iso`: trong log không có lỗi, và ISO chứa `live/vmlinuz-*-vdtos`. Đây là chỗ rủi ro nhất: chưa chắc
   `--linux-packages none` vẫn chép kernel từ chroot ra. Nếu không chép, sửa bằng một hook `binary` tự chép.
3. `make test` PASS.
4. Kiểm tra bằng tay qua QEMU có màn hình: Firefox mở trang web được, có tiếng (`-audiodev pa` / `-device intel-hda`), cài thử ra đĩa ảo bằng d-i rồi boot lại.
5. Nếu có máy i3 gen2 thật: boot từ USB rồi chạy lại `free -m` và `systemd-analyze`.

## Ngoài phạm vi
Kho apt riêng, branding, bản 32-bit, Secure Boot (bản đầu phải tắt Secure Boot), tự động cập nhật kernel, bộ gõ tiếng Việt
(nếu cần thì thêm `fcitx5-unikey` vào package list, chỉ một dòng).
