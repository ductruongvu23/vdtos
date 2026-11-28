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
.github/workflows/build.yml
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

## Task 0: Máy build là GitHub Actions
Máy dev không bật ảo hóa, nên không dùng WSL2, VM hay QEMU-KVM ở local. Mọi bước build và test chạy trên GitHub Actions,
cấu hình ở `.github/workflows/build.yml`, chạy mỗi lần push lên bất kỳ branch nào:
`unit` (`bash tests/run.sh` + `lb config` trong container `debian:trixie`) → `kernel` (`make kernel` trong docker, cache theo
phiên bản kernel và nội dung `kernel/**`) → `iso` (`make iso` trong docker `--privileged`) → `smoke` (`bash tests/smoke.sh`
trên runner có `/dev/kvm`) → `release` (chỉ chạy khi push tag `v*`, đăng ISO lên GitHub Releases).
Ở local chỉ sửa code và push. Muốn chạy test đơn vị trên máy thì dùng Git Bash, nếu có `jq`/`gpg`/`xz`; không có thì cứ để CI chạy.

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
  ```
  Không ghi dòng `# CONFIG_DEBUG_INFO_BTF is not set`: BTF phụ thuộc DEBUG_INFO, khi DEBUG_INFO_NONE thì dòng đó không xuất hiện trong `.config` nên check_fragment sẽ báo thiếu.
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
- `vdtos-report.service`: `Type=simple` (không dùng oneshot: unit oneshot nằm trong lượt boot, chạy `is-system-running --wait` sẽ tự chờ chính nó và treo mãi, còn `systemd-analyze` sẽ báo boot chưa xong), `After=graphical.target`, `ConditionKernelCommandLine=vdtos.test`. Bản phát hành không bị ảnh hưởng.
- `/usr/local/bin/vdtos-report`: chạy `systemctl is-system-running --wait`, sau đó ghi ra `/dev/ttyS0`
  hai dòng `VDTOS-BOOT <giây tới graphical.target từ systemd-analyze>` và `VDTOS-MEM <MB used từ free -m>`.
- Hook `0100-enable-report.hook.chroot`: `systemctl enable vdtos-report.service`.

## Task 6: `tests/smoke.sh` + `Makefile`
- smoke.sh lấy `live/vmlinuz*` và `live/initrd.img*` ra khỏi ISO bằng `xorriso -osirrox on -extract`, rồi chạy:
  `timeout 300 qemu-system-x86_64 -accel kvm -accel tcg -cpu SandyBridge -smp 2 -m 8G -cdrom ISO -kernel … -initrd …
  -append "boot=live components console=ttyS0 vdtos.test preempt=full" -serial file:out/serial.log -display none`.
- grep `VDTOS-MEM`. Lớn hơn 700 hoặc không thấy dòng này thì FAIL. `VDTOS-BOOT` > 30 cũng FAIL, nhưng chỉ kiểm tra
  khi có `/dev/kvm`. Với TCG thì chỉ in cảnh báo, vì giả lập chậm nên đo thời gian không có ý nghĩa.
- Makefile: `kernel` (fetch + build), `iso` (phải chạy bằng root, không dùng `sudo`: `cd live && lb clean && lb config && lb build`, log ghi vào `out/build.log`, ISO chép ra `out/`), `test`, `clean`.
- Mọi script dùng `set -euo pipefail`.

## Task 7: Kho apt, cập nhật tại chỗ (thêm 2026-11-28)
Máy đã cài nhận kernel mới và tinh chỉnh mới của VDTOS bằng `sudo apt update && sudo apt full-upgrade`, không cần cài lại.
- Kho: `https://ductruongvu23.github.io/vdtos` (GitHub Pages), suite `vdtos`, component `main`, chỉ `amd64`. Ký GPG
  (`InRelease` + `Release.gpg`). Chỉ giữ bản mới nhất của mỗi gói (Pages giới hạn 1GB).
- Gói `vdtos-base` (Architecture: all, Version = số phiên bản tag bỏ chữ `v`): chứa toàn bộ file đang nằm ở
  `live/config/includes.chroot/` (zramswap, sysctl, udev, xfwm4, vdtos-report + service), keyring
  `/usr/share/keyrings/vdtos-archive-keyring.asc` và `/etc/apt/sources.list.d/vdtos.sources` trỏ tới kho trên.
  `Depends: linux-image-vdtos, zram-tools`. `postinst` bật `vdtos-report.service` (thay hook 0100) và chạy `sysctl --system`.
- Gói meta `linux-image-vdtos` (Architecture: amd64, Version = `X.Y.Z`): `Depends: linux-image-X.Y.Z-vdtos`. Đây là lý do
  `apt full-upgrade` kéo được kernel mới dù tên gói kernel đổi theo phiên bản. Kernel cũ vẫn nằm lại làm lựa chọn trong GRUB.
- ISO cài `vdtos-base` và `linux-image-vdtos` qua `packages.chroot`; các file trong `includes.chroot` và hook 0100 bị bỏ,
  để mỗi file chỉ có một nguồn.
- CI (job `apt`, chạy khi push tag sau `release`): build hai gói, dựng kho bằng `apt-ftparchive`, ký bằng secret
  `APT_GPG_PRIVATE_KEY`, đẩy lên Pages. Public key nằm trong repo ở `apt/vdtos-archive-keyring.asc`.
- Máy đã cài từ v0.1.0 (chưa có `vdtos-base`): chỉ cần một lần tải `vdtos-base_*.deb` từ Release rồi `sudo apt install ./vdtos-base_*.deb`.

## Task 8: Giao diện hiện đại (thêm 2026-11-28)
Nhìn hiện đại nhưng vẫn giữ RAM nhàn rỗi < 700MB (smoke test vẫn kiểm). Toàn bộ nằm trong gói `vdtos-base`, để máy đã cài
nhận qua `apt full-upgrade`.
- Gói thêm vào `Depends` của `vdtos-base`: `materia-gtk-theme papirus-icon-theme fonts-inter fonts-jetbrains-mono
  xfce4-whiskermenu-plugin xfce4-docklike-plugin`. Trước khi dùng tên nào, kiểm tra nó có trong trixie (`apt-cache show`).
- Không đè file của gói Debian nào: mọi cấu hình đặt dưới `/etc/xdg/vdtos/` (cùng cấu trúc với `/etc/xdg/`), và
  `/etc/X11/Xsession.d/55vdtos-xdg` đặt `XDG_CONFIG_DIRS=/etc/xdg/vdtos:${XDG_CONFIG_DIRS:-/etc/xdg}`.
  `xfwm4.xml` hiện có chuyển sang đây.
- xfconf mặc định (`/etc/xdg/vdtos/xfce4/xfconf/xfce-perchannel-xml/`):
  - `xsettings.xml`: theme `Materia-dark-compact`, icon `Papirus-Dark`, font `Inter 10`, font mono `JetBrains Mono 10`,
    bật antialias + hinting slight.
  - `xfwm4.xml`: theme `Materia-dark-compact`, `use_compositing=true`, bóng đổ dưới cửa sổ thường bật, bóng đổ dock tắt,
    mọi độ trong suốt (`frame_opacity`, `inactive_opacity`, `move_opacity`, `resize_opacity`, `popup_opacity`) = 100.
  - `xfce4-desktop.xml`: hình nền `/usr/share/backgrounds/vdtos/default.svg`, chế độ zoom; tắt icon trên desktop.
  - Panel: `/etc/xdg/vdtos/xfce4/panel/default.xml`. Thanh trên cao 28px: whiskermenu trái, separator giãn, đồng hồ giữa
    (định dạng `%a %d %b  %H:%M`), separator giãn, systray + pulseaudio/âm lượng + power-manager + nút thoát bên phải.
    Dock dưới: panel giữa màn hình, tự co theo nội dung, cao 48px, chỉ có plugin docklike, tự ẩn thông minh (intellihide).
- LightDM: `/etc/lightdm/lightdm-gtk-greeter.conf.d/50-vdtos.conf` (thư mục `.conf.d` không thuộc gói nào): cùng theme,
  icon, font, hình nền.
- Hình nền: `/usr/share/backgrounds/vdtos/default.svg`, tự vẽ (dải gradient tối + chữ VDTOS mờ), giấy phép MIT như repo.
  Không lấy ảnh từ nơi khác.
- NOTICE.md thêm: Materia (GPL-2.0), Papirus (GPL-3.0), Inter và JetBrains Mono (OFL-1.1), các plugin XFCE (GPL-2.0+).

## Task 9: Wi-Fi (thêm 2026-11-28)
Máy thật boot được nhưng menu mạng chỉ có Ethernet. Nguyên nhân dự đoán: `--apt-recommends false` làm thiếu `wpasupplicant`
(NetworkManager cần nó để quét Wi-Fi), và thiếu firmware Atheros/Broadcom.
- File danh sách mới `live/config/package-lists/wifi.list.chroot`:
  `wpasupplicant iw rfkill wireless-regdb firmware-atheros firmware-brcm80211 firmware-libertas firmware-mediatek`.
- `tests/test_packages.sh` kiểm tra mọi `*.list.chroot`, bỏ qua gói build trong repo (`vdtos-*`, `linux-image-vdtos`,
  `linux-image-*-vdtos`).
- NOTICE.md thêm các gói firmware mới vào dòng firmware non-free.

## Kiểm chứng
1. Job `kernel` trên CI xanh, artifact `kernel-deb` có file `.deb` chứa `boot/vmlinuz-*-vdtos`.
2. Job `iso` xanh, và ISO chứa `live/vmlinuz-*-vdtos`. Đây là chỗ rủi ro nhất: chưa chắc
   `--linux-packages none` vẫn chép kernel từ chroot ra. Nếu không chép, sửa bằng một hook `binary` tự chép.
3. Job `smoke` xanh (log ở artifact `serial-log`).
4. Kiểm tra bằng tay: tải ISO từ artifact hoặc Release, ghi ra USB, boot trên máy thật. Firefox mở trang web được, có tiếng,
   cài ra ổ đĩa rồi boot lại. (Không có máy thử thì có thể dùng QEMU cho Windows ở chế độ TCG, không cần ảo hóa nhưng rất chậm.)
5. Nếu có máy i3 gen2 thật: boot từ USB rồi chạy lại `free -m` và `systemd-analyze`.

## Ngoài phạm vi
Branding, bản 32-bit, Secure Boot (bản đầu phải tắt Secure Boot), tự cập nhật không cần người bấm (unattended-upgrades), bộ gõ tiếng Việt
(nếu cần thì thêm `fcitx5-unikey` vào package list, chỉ một dòng).
