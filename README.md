# VDTOS

Distro desktop nhẹ cho máy cũ (từ i3 gen2, 8GB RAM). Kernel longterm tự build từ kernel.org, userspace Debian 13, giao diện XFCE.

Thiết kế: [docs/superpowers/specs/2026-11-27-vdtos-design.md](docs/superpowers/specs/2026-11-27-vdtos-design.md)

## Build

Không build ở máy local. Mỗi lần push, GitHub Actions ([.github/workflows/build.yml](.github/workflows/build.yml)) tự chạy
test → build kernel → build ISO → boot thử ISO trong QEMU. ISO lấy ở artifact `iso` của lần chạy đó.
Mỗi tag `v*` sẽ tạo một GitHub Release kèm file ISO.
