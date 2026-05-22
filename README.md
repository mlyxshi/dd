# Create UEFI GPT aarch64 nixos raw disk image
nix build --no-link --print-out-paths .#nixosConfigurations.arm-init.config.system.build.image



# Create LegacyBios GPT x86-64 nixos raw disk image
```
fallocate -l 3G bios-init.raw
losetup -fP --show bios-init.raw

# limine require this partition for bios compatibility under gpt
sgdisk -n 0:0:+1M -t 0:ef02 /dev/loop1

sgdisk -n 0:0:+200M /dev/loop1
sgdisk -n 0:0:0 /dev/loop1

mkfs.fat -F 32 /dev/loop1p2
mkfs.ext4 /dev/loop1p3
mkdir -p /mnt
mount /dev/loop1p3 /mnt
mount --mkdir /dev/loop1p2 /mnt/boot

# nixos-install 
outPath=$(nix build --store /mnt --no-link --print-out-paths /flake#nixosConfigurations.bios-vda-init.config.system.build.toplevel)
nix-env --store /mnt -p /mnt/nix/var/nix/profiles/system --set $outPath

# nixos-enter
mkdir -p /mnt/dev /mnt/sys /mnt/proc
chmod 0755 /mnt/dev /mnt/sys /mnt/proc
mount --rbind /dev /mnt/dev
mount --rbind /sys /mnt/sys
mount --rbind /proc /mnt/proc

mkdir /mnt/etc
chroot /mnt /nix/var/nix/profiles/system/activate
chroot /mnt /nix/var/nix/profiles/system/bin/switch-to-configuration boot

nix run nixpkgs#limine bios-install /dev/loop1

umount -Rl /mnt/dev
umount -Rl /mnt/sys
umount -Rl /mnt/proc
umount -Rl /mnt/run
umount -Rl /mnt/etc


umount /dev/loop1p2
umount /dev/loop1p3
losetup -d /dev/loop1
```


# NC tty
```
wget https://github.com/mlyxshi/flake/releases/download/$(uname -m)/busybox-kernel
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
wget https://github.com/mlyxshi/flake/releases/download/$(uname -m)/busybox-kernel
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
wget https://github.com/mlyxshi/flake/releases/download/$(uname -m)/busybox-kernel
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
wget https://github.com/mlyxshi/flake/releases/download/$(uname -m)/busybox-kernel
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
wget https://github.com/mlyxshi/flake/releases/download/$(uname -m)/busybox-kernel
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


```
wget -qO /dev/sda https://dd.mlyxshi.com/arm-init.raw 
wget -qO /dev/vda https://dd.mlyxshi.com/bios-vda-init.raw
```

```
wget https://github.com/mlyxshi/flake/releases/download/$(uname -m)/busybox-kernel
wget https://github.com/mlyxshi/flake/releases/download/$(uname -m)/kexec
chmod +x kexec
./kexec --load ./busybox-kernel --append="console=tty0"
systemctl kexec -i
```
