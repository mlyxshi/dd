# NC tty
```
wget https://github.com/mlyxshi/dd/releases/download/$(uname -m)/busybox-kernel
cat > /boot/grub/custom.cfg <<EOF
menuentry "KernelBusyBox" --id KernelBusyBox {
  insmod ext2
  search -f /etc/hostname --set root
  linux /root/busybox-kernel console=tty0
}
set default="KernelBusyBox"
EOF
reboot
```

# NC serial
```
wget https://github.com/mlyxshi/dd/releases/download/$(uname -m)/busybox-kernel
cat > /boot/grub/custom.cfg <<EOF
menuentry "KernelBusyBox" --id KernelBusyBox {
  insmod ext2
  search -f /etc/hostname --set root
  linux /root/busybox-kernel console=ttyS0
}
set default="KernelBusyBox"
EOF
reboot
```


# ARM UEFI sda init
```
wget https://github.com/mlyxshi/dd/releases/download/$(uname -m)/busybox-kernel
cat > /boot/grub/custom.cfg <<EOF
menuentry "KernelBusyBox" --id KernelBusyBox {
  insmod ext2
  search -f /etc/hostname --set root
  linux /root/busybox-kernel console=tty0 device=/dev/sda url=https://github.com/mlyxshi/dd/releases/download/img/arm-init.raw.gz
}
set default="KernelBusyBox"
EOF
reboot
```

# x86_64 BIOS vda int
```
wget https://github.com/mlyxshi/dd/releases/download/$(uname -m)/busybox-kernel
cat > /boot/grub/custom.cfg <<EOF
menuentry "KernelBusyBox" --id KernelBusyBox {
  insmod ext2
  search -f /etc/hostname --set root
  linux /root/busybox-kernel console=tty0 device=/dev/vda url=https://github.com/mlyxshi/dd/releases/download/img/bios-init.raw.gz
}
set default="KernelBusyBox"
EOF
reboot
```


# x86_64 UEFI sda int
```
wget https://github.com/mlyxshi/dd/releases/download/$(uname -m)/busybox-kernel
cat > /boot/grub/custom.cfg <<EOF
menuentry "KernelBusyBox" --id KernelBusyBox {
  insmod ext2
  search -f /etc/hostname --set root
  linux /root/busybox-kernel console=tty0 device=/dev/sda url=https://github.com/mlyxshi/dd/releases/download/img/amd-init.raw.gz
}
set default="KernelBusyBox"
EOF
reboot
```

# Manual

```
wget -O - https://github.com/mlyxshi/dd/releases/download/img/bios-init.raw.gz | gunzip > /dev/vda

wget -O - https://github.com/mlyxshi/dd/releases/download/img/amd-init.raw.gz | gunzip > /dev/sda
```

```
wget https://github.com/mlyxshi/dd/releases/download/$(uname -m)/busybox-kernel
wget https://github.com/mlyxshi/dd/releases/download/$(uname -m)/kexec
chmod +x kexec
./kexec --load ./busybox-kernel --append="console=tty0"
systemctl kexec -i
```


```
wget https://github.com/mlyxshi/dd/releases/download/$(uname -m)/busybox-kernel
wget https://github.com/mlyxshi/dd/releases/download/$(uname -m)/kexec
chmod +x kexec
./kexec --load ./busybox-kernel --append="console=ttyS0"
systemctl kexec -i
```


# Oracle ARM UEFI sda init (Systemd 261)
```
wget -O /boot/busybox-kernel https://github.com/mlyxshi/dd/releases/download/$(uname -m)/busybox-kernel


mkdir -p /boot/loader/entries
cat > /boot/loader/entries/dd.conf <<'EOF'
title   dd installer
linux   /busybox-kernel
options device=/dev/sda url=https://github.com/mlyxshi/dd/releases/download/img/arm-init.raw.gz
EOF

bootctl list  
bootctl set-oneshot dd.conf
systemctl kexec -i
```


# IPXE
```
kernel https://github.com/mlyxshi/dd/releases/download/aarch64/busybox-kernel device=/dev/sda url=https://github.com/mlyxshi/dd/releases/download/img/arm-init.raw.gz
boot
```