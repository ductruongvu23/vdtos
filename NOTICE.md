# Bản quyền và giấy phép

VDTOS là một bản phối lại (remix) không chính thức của Debian. VDTOS **không** do Debian Project, kernel.org hay
Mozilla phát triển, bảo trợ hay xác nhận. "Debian" là thương hiệu của Software in the Public Interest, Inc.;
"Linux" là thương hiệu đã đăng ký của Linus Torvalds; "Firefox" là thương hiệu của Mozilla Foundation.

## Mã nguồn trong repo này
Các script, file cấu hình và test trong repo do chủ repo viết, phát hành theo giấy phép MIT ([LICENSE](LICENSE)).
Giấy phép MIT chỉ áp dụng cho code trong repo này, không áp dụng cho các thành phần bên thứ ba trong ISO liệt kê bên dưới.

## Thành phần bên thứ ba trong ISO
ISO được build từ các gói Debian 13 (trixie) chính thức, không sửa đổi, cộng với một kernel tự build.
Văn bản giấy phép đầy đủ của từng gói nằm trong ISO, ở `/usr/share/doc/<gói>/copyright`.

| Thành phần | Nguồn | Giấy phép | Ghi chú |
|---|---|---|---|
| Linux kernel 6.18.65 | kernel.org, tarball gốc không vá | GPL-2.0 (có ngoại lệ syscall) | Chỉ đổi cấu hình: config Debian + [kernel/config.fragment](kernel/config.fragment) |
| Userspace Debian (live-boot, systemd, Xorg, XFCE, LightDM, NetworkManager, PipeWire, …) | Kho `main` của Debian | Nhiều giấy phép tự do (GPL, LGPL, MIT, BSD, …) đạt chuẩn DFSG | |
| Firefox ESR | Gói `firefox-esr` của Debian | MPL-2.0 | Dùng nguyên gói Debian, không sửa; tên và logo Firefox theo chính sách thương hiệu của Mozilla |
| Font Noto | Gói `fonts-noto-core` | SIL Open Font License 1.1 | |
| Debian Installer, logo Debian | Debian | GPL / Debian Open Use Logo License | |
| `intel-microcode` | Kho `non-free-firmware` | Giấy phép riêng của Intel: **không phải mã nguồn mở**, cho phép phân phối lại nguyên bản | |
| `firmware-misc-nonfree`, `firmware-realtek`, `firmware-iwlwifi` | Kho `non-free-firmware` | Giấy phép riêng của từng hãng: **không phải mã nguồn mở**, cho phép phân phối lại nguyên bản | Cần cho Wi-Fi, mạng và GPU trên máy thật |

Các firmware non-free được phép phân phối lại đúng như Debian đang làm trong ảnh cài đặt chính thức, với điều kiện
giữ nguyên file và kèm giấy phép (đã có trong `/usr/share/doc/<gói>/copyright`). Không được sửa đổi hay dịch ngược chúng.

## Mã nguồn tương ứng (GPL)
- Kernel: mỗi GitHub Release đính kèm đúng mã nguồn đã dùng: `linux-X.Y.Z.tar.xz` (tarball gốc kernel.org, không vá),
  chữ ký `linux-X.Y.Z.tar.sign`, file cấu hình `config-X.Y.Z-vdtos` và gói `linux-image-*.deb` đã build.
  Build lại: giải nén tarball, chép file config thành `.config`, chạy `make olddefconfig && make bindeb-pkg`.
- Các gói Debian: mã nguồn đúng phiên bản có ở <https://sources.debian.org> và <https://snapshot.debian.org>.
