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
  linux /root/busybox-kernel console=tty0 device=/dev/sda url=https://dd.mlyxshi.com/arm-init.raw
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
  linux /root/busybox-kernel console=tty0 device=/dev/vda url=https://dd.mlyxshi.com/bios-init.raw
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
  linux /root/busybox-kernel console=tty0 device=/dev/sda url=https://dd.mlyxshi.com/amd-init.raw
}
set default="KernelBusyBox"
EOF
reboot
```

# Manual

```
wget -qO /dev/sda https://dd.mlyxshi.com/arm-init.raw 
wget -qO /dev/vda https://dd.mlyxshi.com/bios-init.raw
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


# Oracle ARM UEFI sda init
```
wget https://github.com/mlyxshi/dd/releases/download/$(uname -m)/busybox-kernel
wget https://github.com/mlyxshi/dd/releases/download/$(uname -m)/kexec
chmod +x kexec
./kexec --load ./busybox-kernel --append="device=/dev/sda url=https://dd.mlyxshi.com/arm-init.raw"
systemctl kexec -i
```


# IPXE
```
kernel https://github.com/mlyxshi/dd/releases/download/aarch64/busybox-kernel device=/dev/sda url=https://dd.mlyxshi.com/arm-init.raw
boot
```