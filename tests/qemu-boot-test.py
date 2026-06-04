#!/usr/bin/env python3
"""Boot a built raw disk image in QEMU and assert it boots successfully.

Usage: qemu-boot-test.py <image-name> <path-to.raw>
  image-name: bios-init | amd-init | arm-init
"""
import os
import shutil
import sys
import tempfile

import pexpect

FAIL_PATTERNS = [
    "Kernel panic",
    "Entering emergency mode",
    "You are in emergency mode",
]


def prepare_disk(raw):
    """nix-store image is read-only; copy to a writable disk for QEMU."""
    fd, disk = tempfile.mkstemp(suffix=".raw", dir=os.getcwd())
    os.close(fd)
    shutil.copyfile(raw, disk)
    os.chmod(disk, 0o644)
    return disk


def pflash(code, vars_src, nvram):
    shutil.copyfile(vars_src, nvram)
    os.chmod(nvram, 0o644)
    return ["-drive", f"if=pflash,format=raw,readonly=on,file={code}",
            "-drive", f"if=pflash,format=raw,file={nvram}"]


def build_cmd(name, disk):
    # x86_64: hardware-accelerated (runners expose /dev/kvm)
    # arm:    emulated with cortex-a57 (no KVM on arm runners)
    disk_drive = ["-drive", f"file={disk},format=raw,if=virtio"]

    if name == "bios-init":                        # x86_64 BIOS (SeaBIOS)
        return ["qemu-system-x86_64", "-m", "1G", "-nographic",
                "-cpu", "host", "-accel", "kvm", *disk_drive]

    if name == "amd-init":                         # x86_64 UEFI
        fw = pflash("/usr/share/OVMF/OVMF_CODE_4M.fd",
                    "/usr/share/OVMF/OVMF_VARS_4M.fd",
                    "OVMF_VARS.local.fd")
        return ["qemu-system-x86_64", "-m", "1G", "-nographic",
                "-cpu", "host", "-accel", "kvm", *disk_drive, *fw]

    if name == "arm-init":                          # aarch64 UEFI
        fw = pflash("/usr/share/AAVMF/AAVMF_CODE.no-secboot.fd",
                    "/usr/share/AAVMF/AAVMF_VARS.fd",
                    "AAVMF_VARS.local.fd")
        return ["qemu-system-aarch64", "-machine", "virt", "-m", "1G",
                "-nographic", "-cpu", "cortex-a57", "-accel", "tcg",
                *disk_drive, *fw]

    sys.exit(f"unknown image name: {name}")


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    name, raw = sys.argv[1], sys.argv[2]

    boot_timeout = 900 if name == "arm-init" else 180  # emulated arm is slow

    disk = prepare_disk(raw)
    cmd = build_cmd(name, disk)
    print("BOOT:", " ".join(cmd), flush=True)

    child = pexpect.spawn(cmd[0], cmd[1:], encoding="utf-8", timeout=boot_timeout)
    child.logfile = sys.stdout

    try:
        # Boot success: detected passively from the console (no shell typing).
        # The autologin banner means userspace came up cleanly.
        idx = child.expect(["automatic login", *FAIL_PATTERNS],
                           timeout=boot_timeout)
        if idx != 0:
            sys.exit("FAIL: boot error detected on console")
    finally:
        child.terminate(force=True)

    print("\n>>> boot OK\nPASS")


if __name__ == "__main__":
    main()
