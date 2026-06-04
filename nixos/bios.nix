{
  config,
  pkgs,
  lib,
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
    ./common.nix
  ];

  # https://en.wikipedia.org/wiki/BIOS_boot_partition
  # https://github.com/Limine-Bootloader/Limine/blob/v12.x/USAGE.md#biosgpt
  # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/image/repart-image.nix
  system.build.image = lib.mkForce (
    config.image.repart.image.overrideAttrs (old: {
      nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.limine ];
      postBuild = ''
        limine bios-install ${config.image.baseName}.raw
      '';
    })
  );

  image.repart = {
    name = config.networking.hostName;
    partitions = {
      "bios" = {
        repartConfig = {
          Type = "21686148-6449-6E6F-744E-656564454649"; # BIOS boot partition Type UUID
          SizeMinBytes = "1M";
        };
      };
      "esp" = {
        contents = {
          "/limine/limine-bios.sys".source = "${pkgs.limine}/share/limine/limine-bios.sys";
          "/limine/limine.conf".source = pkgs.writeText "limine.conf" ''
            timeout: 1
            default_entry: 1

            /NixOS
                protocol: linux
                kernel_path: boot():/limine/kernels/kernel
                module_path: boot():/limine/kernels/initrd
                cmdline: init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}
          '';
          "/limine/kernels/initrd".source =
            "${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}";
          "/limine/kernels/kernel".source =
            "${config.system.build.kernel}/${config.system.boot.loader.kernelFile}";
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

  networking.hostName = "bios-init";
  nixpkgs.hostPlatform = "x86_64-linux";

  boot.loader.limine.enable = true;

  fileSystems."/boot" = {
    device = lib.mkDefault "/dev/vda2";
    fsType = "vfat";
  };

  fileSystems."/" = {
    device = lib.mkDefault "/dev/vda3";
    fsType = "ext4";
  };

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
      mount -r /dev/disk/by-label/cidata /cloud-init
      mkdir -p /run/systemd/network/
      NETWORKD_CONF="/run/systemd/network/10-cloud-init.network"
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
