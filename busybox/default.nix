{
  pkgs ? import <nixpkgs> {
    system = "aarch64-linux";
    # system = "x86_64-linux";
  },
  pkgs-macos ? import <nixpkgs> { },
}:
rec {
  inherit (pkgs)
    stdenv
    pkgsStatic
    ;

  arch = stdenv.hostPlatform.linuxArch;
  target = if stdenv.hostPlatform.isAarch64 then "vmlinuz.efi" else "bzImage";
  bootDir = if stdenv.hostPlatform.isAarch64 then "arch/arm64/boot" else "arch/x86/boot";

  kernel = stdenv.mkDerivation {
    name = "kernel";
    inherit (pkgs.linuxPackages_latest.kernel) src;
    nativeBuildInputs = with pkgs; [
      bison
      flex
      bc
      perl
      elfutils
      hexdump
      zstd
    ];
    # https://github.com/torvalds/linux/blob/master/usr/gen_init_cpio.c
    initrd_cpio_list = pkgs.writeText "initrd_cpio_list" ''
      dir /dev 0755 0 0
      nod /dev/console 0600 0 0 c 5 1
      dir /bin 0755 0 0
      file /init ${./init} 0755 0 0
      file /bin/busybox ${busybox}/bin/busybox 0755 0 0
    '';
    # https://kernel.org/doc/Documentation/kbuild/kconfig.txt
    configurePhase = ''
      cat ${kernel-config/common} ${kernel-config/${arch}} > mini.config
      make ARCH=${arch} KCONFIG_ALLCONFIG=mini.config allnoconfig
    '';
    buildPhase = "make ARCH=${arch} CONFIG_INITRAMFS_SOURCE=$initrd_cpio_list -j$NIX_BUILD_CORES ${target}";
    installPhase = "install -Dm444 ${bootDir}/${target} $out/${target}";
  };

  busybox = pkgsStatic.stdenv.mkDerivation {
    name = "busybox";
    inherit (pkgs.busybox) src;
    depsBuildBuild = [ pkgs.buildPackages.stdenv.cc ];
    configurePhase = ''
      cp ${./cloud_init_networkcfg.c} miscutils/cloud_init_networkcfg.c
      make allnoconfig
      for opt in $(grep '^CONFIG_.*' ${./busybox.config}); do sed -i "s|^# $opt is not set|$opt=y|" .config; done
    '';
    buildPhase = "make CROSS_COMPILE=${pkgsStatic.stdenv.cc.targetPrefix} busybox -j$NIX_BUILD_CORES";
    installPhase = "install -Dm755 busybox $out/bin/busybox";
  };

  test-arm64 = pkgs-macos.writeShellScriptBin "aarch64-initramfs-test" ''
    ls -lh ${kernel}/vmlinuz.efi | awk '{print $5}'
    ls -lh ${busybox}/bin/busybox | awk '{print $5}'
    /opt/homebrew/bin/qemu-system-aarch64 -machine virt -cpu host -accel hvf -serial stdio -display none -m 256M \
      -kernel ${kernel}/vmlinuz.efi -append "earlycon=pl011,mmio32,0x9000000"\
      -device "virtio-net-pci,netdev=net0" -netdev "user,id=net0,hostfwd=tcp::8022-:23333" \
      -drive if=pflash,format=raw,readonly=on,file=/Users/dominic/vfkit/edk2-aarch64-code.fd \
      -drive if=pflash,format=raw,file=/Users/dominic/vfkit/edk2-arm-vars.fd \
      -device "virtio-scsi-pci,id=scsi0" -drive "file=/Users/dominic/flake/test/disk-scsi.img,if=none,format=qcow2,id=drive0" -device "scsi-hd,drive=drive0,bus=scsi0.0" \
      -device "virtio-blk-pci,drive=hd0" -drive "file=/Users/dominic/flake/test/disk-blk.img,if=none,format=qcow2,id=hd0"
  '';

  tty = pkgs-macos.writeShellScriptBin "aarch64-initramfs-test" ''
    ls -lh ${kernel}/vmlinuz.efi | awk '{print $5}'
    ls -lh ${busybox}/bin/busybox | awk '{print $5}'
    /opt/homebrew/bin/qemu-system-aarch64 -machine virt -cpu host -accel hvf -m 256M \
      -kernel ${kernel}/vmlinuz.efi -append "console=ttyAMA0 console=tty0" \
      -device virtio-gpu-pci \
      -display cocoa,zoom-to-fit=on -serial stdio \
      -device qemu-xhci,id=xhci -device usb-kbd,bus=xhci.0 \
      -device "virtio-net-pci,netdev=net0" -netdev "user,id=net0,hostfwd=tcp::8022-:23333" \
      -drive if=pflash,format=raw,readonly=on,file=/Users/dominic/vfkit/edk2-aarch64-code.fd \
      -drive if=pflash,format=raw,file=/Users/dominic/vfkit/edk2-arm-vars.fd \
      -device "virtio-scsi-pci,id=scsi0" -drive "file=/Users/dominic/flake/test/disk-scsi.img,if=none,format=qcow2,id=drive0" -device "scsi-hd,drive=drive0,bus=scsi0.0" \
      -device "virtio-blk-pci,drive=hd0" -drive "file=/Users/dominic/flake/test/disk-blk.img,if=none,format=qcow2,id=hd0"
  '';

  test-x86-64 = pkgs-macos.writeShellScriptBin "x86-64-initramfs-test" ''
    ls -lh ${kernel}/bzImage  | awk '{print $5}'
    /opt/homebrew/bin/qemu-system-x86_64 -cpu qemu64 -m 256M \
      -kernel ${kernel}/bzImage -append "console=ttyS0 console=tty0" \
      -vga std \
      -display cocoa,zoom-to-fit=on -serial stdio \
      -device "virtio-net-pci,netdev=net0" -netdev "user,id=net0,hostfwd=tcp::8022-:23333" \
      -device "virtio-scsi-pci,id=scsi0" -drive "file=/Users/dominic/flake/test/disk-scsi.img,if=none,format=qcow2,id=drive0" -device "scsi-hd,drive=drive0,bus=scsi0.0" \
      -device "virtio-blk-pci,drive=hd0" -drive "file=/Users/dominic/flake/test/disk-blk.img,if=none,format=qcow2,id=hd0"
  '';

  test = if stdenv.hostPlatform.system == "x86_64-linux" then test-x86-64 else test-arm64;
}
