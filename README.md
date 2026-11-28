# VDTOS

Distro desktop nhẹ cho máy cũ (từ i3 gen2, 8GB RAM). Kernel longterm tự build từ kernel.org, userspace Debian 13, giao diện XFCE.

Thiết kế: [docs/superpowers/specs/2026-11-27-vdtos-design.md](docs/superpowers/specs/2026-11-27-vdtos-design.md)

## Build

Không build ở máy local. Mỗi lần push, GitHub Actions ([.github/workflows/build.yml](.github/workflows/build.yml)) tự chạy
test → build kernel → build ISO → boot thử ISO trong QEMU. ISO lấy ở artifact `iso` của lần chạy đó.
Mỗi tag `v*` sẽ tạo một GitHub Release kèm file ISO.

## Bản quyền và giấy phép

VDTOS là bản phối lại không chính thức của Debian, không liên kết với Debian Project hay kernel.org.
ISO gồm kernel Linux (GPL-2.0), các gói Debian tự do và một số firmware non-free được phép phân phối lại nguyên bản.
Chi tiết từng thành phần và nơi lấy mã nguồn: [NOTICE.md](NOTICE.md).
Mã trong repo này chưa có file LICENSE, nên mọi quyền được bảo lưu.
