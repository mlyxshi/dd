{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}:
{

  imports = [ "${modulesPath}/profiles/qemu-guest.nix" ];

  networking.hostName = "x86-64-bios-init";
  nixpkgs.hostPlatform = "x86_64-linux";

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

  boot.initrd.systemd.emergencyAccess = true;

  boot.loader.limine.enable = true;
  boot.loader.limine.biosSupport = true;
  boot.loader.limine.efiSupport = false;
  # Only the stage 2 bootloader will be installed, install stage1 separately manuanlly
  boot.loader.limine.biosDevice = "nodev";
  boot.loader.limine.maxGenerations = 2;
  boot.loader.timeout = 1;

  fileSystems."/boot" = {
    device = lib.mkDefault "/dev/vda2";
    fsType = "vfat";
  };

  fileSystems."/" = {
    device = lib.mkDefault "/dev/vda3";
    fsType = "ext4";
    autoResize = true; # grow fs
  };

  boot.growPartition = true; # grow partition

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

  # Very limited cloud-init network setup implementation. Only test on cloud provider I use (dmit.io)
  services.udev.extraRules = ''
    SUBSYSTEM=="block", ENV{ID_FS_LABEL}=="cidata", TAG+="systemd", ENV{SYSTEMD_WANTS}="cloud-init-network.service"
  '';

  systemd.services.cloud-init-network = {
    serviceConfig.Type = "oneshot";
    path = [
      pkgs.yq-go
      pkgs.util-linux
    ];

    script = ''
      mkdir -p /cloud-init
      mount /dev/disk/by-label/cidata /cloud-init
      mkdir -p /run/systemd/network/
      NETWORKD_CONF="/run/systemd/network/ethernet.network"
      CLOUD_INIT_CONF="/cloud-init/network-config"

      VERSION=$(yq .version $CLOUD_INIT_CONF)

      if [ "$VERSION" = "1" ]; then
        IP=$(yq .config[0].subnets[0].address $CLOUD_INIT_CONF)
        NETMASK=$(yq .config[0].subnets[0].netmask $CLOUD_INIT_CONF)
        GATEWAY=$(yq .config[0].subnets[0].gateway $CLOUD_INIT_CONF)

        if [ "$NETMASK" = "255.255.255.255" ]; then
          CIDR=32
        elif [ "$NETMASK" = "255.255.255.0" ]; then
          CIDR=24
        else
          echo "Unsupported netmask: $NETMASK"
          exit 1
        fi

        {
          echo "[Match]"
          echo "Name=en*"
          echo
          echo "[Network]"
          echo "Address=$IP/$CIDR"
          echo
          echo "[Route]"
          echo "Gateway=$GATEWAY"
          if [ "$CIDR" -eq 32 ]; then
            echo "GatewayOnLink=yes"
          fi
        } > $NETWORKD_CONF

      elif [ "$VERSION" = "2" ]; then
        IP=$(yq .ethernets.eth0.addresses[0] $CLOUD_INIT_CONF)
        GATEWAY4=$(yq .ethernets.eth0.gateway4 $CLOUD_INIT_CONF)
        
        if [ "$GATEWAY4" = "null" ]; then
          echo "IPV6 Only"
          GATEWAY6=$(yq '.ethernets.eth0.gateway6' $CLOUD_INIT_CONF)
          {
            echo "[Match]"
            echo "Name=en*"
            echo
            echo "[Network]"
            echo "Address=''${IP%%/*}/128"
            echo
            echo "[Route]"
            echo "Gateway=$GATEWAY6"
            echo "GatewayOnLink=yes"
          } > $NETWORKD_CONF
        else
          echo "Use IPV4"
          {
            echo "[Match]"
            echo "Name=en*"
            echo
            echo "[Network]"
            echo "Address=$IP"
            echo
            echo "[Route]"
            echo "Gateway=$GATEWAY4"
          } > $NETWORKD_CONF
          case "$IP" in
            */32)
              echo "CIDR is /32"
              echo "GatewayOnLink=yes" >> $NETWORKD_CONF
              ;;
            *)
              echo "CIDR is not /32"
              ;;
          esac

        fi
      fi

      systemctl reload-or-restart systemd-networkd.service
    '';
  };

}
