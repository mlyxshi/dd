# https://github.com/NixOS/nixpkgs/pull/351699
{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}:
let
  closureInfo = pkgs.closureInfo {
    rootPaths = [ config.system.build.toplevel ];
  };

  nixState = pkgs.runCommand "nix-state" { nativeBuildInputs = [ pkgs.buildPackages.nix ]; } ''
    mkdir -p $out/profiles
    ln -s ${config.system.build.toplevel} $out/profiles/system-1-link
    ln -s /nix/var/nix/profiles/system-1-link $out/profiles/system

    export NIX_STATE_DIR=$out
    nix-store --load-db < ${closureInfo}/registration
  '';
in
{

  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
    "${modulesPath}/image/repart.nix"
  ];

  networking.hostName = lib.mkDefault "arm-init";
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  services.getty.autologinUser = "root";

  networking.useDHCP = false;
  networking.firewall.enable = false;

  systemd.network.enable = true;
  systemd.network.wait-online.anyInterface = true;
  systemd.network.networks.ethernet-default-dhcp = {
    matchConfig.Name = "en*";
    networkConfig.DHCP = "yes";
  };

  boot.initrd.systemd.emergencyAccess = true;

  boot.initrd.systemd.root = "gpt-auto";
  boot.initrd.supportedFilesystems = [ "ext4" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.timeout = 1;

  environment.etc = {
    "ssh/ssh_host_ed25519_key.pub" = {
      text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBWcxb/Blaqt1auOtE+F8QUWrUotiC5qBJ+UuEWdVCb";
      mode = "0400";
    };
    "ssh/ssh_host_ed25519_key" = {
      text = ''
        -----BEGIN OPENSSH PRIVATE KEY-----
        b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
        QyNTUxOQAAACCQVnMW/wZWqrdWrjrRPhfEFFq1KLYguagSflLhFnVQmwAAAJASuMMnErjD
        JwAAAAtzc2gtZWQyNTUxOQAAACCQVnMW/wZWqrdWrjrRPhfEFFq1KLYguagSflLhFnVQmw
        AAAEDIN2VWFyggtoSPXcAFy8dtG1uAig8sCuyE21eMDt2GgJBWcxb/Blaqt1auOtE+F8QU
        WrUotiC5qBJ+UuEWdVCbAAAACnJvb3RAbml4b3MBAgM=
        -----END OPENSSH PRIVATE KEY-----
      '';
      mode = "0400";
    };
    "machine-id" = {
      text = "6a9857a393724b7a981ebb5b8495b9ea"; # make systemd happy
      mode = "0444";
    };
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
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
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
  ];

  fonts.fontconfig.enable = false;

  # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/profiles/minimal.nix
  xdg = {
    autostart.enable = false;
    icons.enable = false;
    mime.enable = false;
    sounds.enable = false;
  };

  documentation = {
    enable = false;
    doc.enable = false;
    info.enable = false;
    man.enable = false;
    nixos.enable = false;
  };

  system.stateVersion = lib.trivial.release;
  system.nixos-init.enable = true;
  # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/profiles/perlless.nix
  systemd.sysusers.enable = true;
  system.etc.overlay.enable = true;
  system.etc.overlay.mutable = false;

  system.tools.nixos-generate-config.enable = false;
  environment.defaultPackages = [ ];
  system.forbiddenDependenciesRegexes = [ "perl" ];

  # resize root partition and filesystem after switch-root
  # https://www.freedesktop.org/software/systemd/man/latest/repart.d.html#Flags=
  systemd.repart.enable = true;
  systemd.repart.partitions = {
    root = {
      Type = "root";
    };
  };

  image.repart = {
    name = config.networking.hostName;
    partitions = {
      "esp" = {
        contents =
          let
            efiArch = config.nixpkgs.hostPlatform.efiArch;
          in
          {
            "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
              "${config.systemd.package}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";

            "/EFI/systemd/systemd-boot${efiArch}.efi".source =
              "${config.systemd.package}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";

            "/EFI/Linux/${config.system.boot.loader.ukiFile}".source =
              "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";

            "/EFI/netbootxyz.efi".source = "${pkgs.netbootxyz-efi}"; # emergency rescue on oracle arm
          };
        repartConfig = {
          Type = "esp";
          Format = "vfat";
          SizeMinBytes = "300M";
        };
      };
      "root" = {
        storePaths = [ config.system.build.toplevel ];
        contents = {
          "/nix/var/nix".source = nixState;
        };
        repartConfig = {
          Type = "root";
          Format = "ext4";
          Minimize = "guess";
        };
      };
    };
  };

}
