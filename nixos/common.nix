{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
    "${modulesPath}/profiles/perlless.nix"
    "${modulesPath}/profiles/minimal.nix"
    "${modulesPath}/image/repart.nix"
  ];

  boot.initrd.systemd.emergencyAccess = true;

  boot.kernelParams =
    [ "console=tty0" ]
    ++ lib.optional pkgs.stdenv.hostPlatform.isAarch64 "console=ttyAMA0"
    ++ lib.optional pkgs.stdenv.hostPlatform.isx86_64 "console=ttyS0";

  # resize root partition and filesystem after switch-root
  # https://www.freedesktop.org/software/systemd/man/latest/repart.d.html#Flags=
  systemd.repart.enable = true;
  systemd.repart.partitions = {
    root = {
      Type = "root";
    };
  };

  services.getty.autologinUser = "root";

  # Disable nixpkgs defined dhcp
  networking.useDHCP = false;
  networking.firewall.enable = false;

  systemd.network.enable = true;
  systemd.network.wait-online.anyInterface = true;
  systemd.network.networks.ethernet-default-dhcp = {
    matchConfig.Name = "en*";
    networkConfig.DHCP = "yes";
  };

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMpaY3LyCW4HHqbp4SA4tnA+1Bkgwrtro2s/DEsBcPDe"
    ];
    shell = pkgs.fish;
  };

  programs.fish.enable = true;

  services.openssh = {
    enable = true;
    # NixOS automatically generate SSH host keys to /etc/ssh/
    # For immutable etc, manually set host keys to /var/lib/nixos
    hostKeys = [
      {
        path = "/var/lib/nixos/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings.PasswordAuthentication = false;
  };

  nix = {
    channel.enable = false;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
        "cgroups"
        "auto-allocate-uids"
      ];
      # experimental
      use-cgroups = true;
      auto-allocate-uids = true;
    };
  };

  environment.systemPackages = with pkgs; [
    gitMinimal
    fastfetch.minimal
    ghostty.terminfo
  ];

  fonts.fontconfig.enable = false;

  system.etc.overlay.mutable = false;

  system.stateVersion = lib.trivial.release;
  system.nixos-init.enable = true;
}
