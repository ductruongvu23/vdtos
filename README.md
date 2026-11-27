# VDTOS

Distro desktop nhẹ cho máy cũ (từ i3 gen2, 8GB RAM). Kernel longterm tự build từ kernel.org, userspace Debian 13, giao diện XFCE.

Thiết kế: [docs/superpowers/specs/2026-11-27-vdtos-design.md](docs/superpowers/specs/2026-11-27-vdtos-design.md)

## Build (trong WSL2 Debian, repo đặt ở ~/New_os, không ở /mnt/c)

```sh
make kernel   # tải + kiểm chữ ký + build kernel .deb
make iso      # ra out/vdtos-amd64.hybrid.iso
make test     # boot ISO trong QEMU, kiểm RAM nhàn rỗi và thời gian boot
```
