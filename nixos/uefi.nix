# https://github.com/NixOS/nixpkgs/pull/351699
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

  networking.hostName = lib.mkDefault "arm-init";
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  boot.loader.systemd-boot.enable = true;
  boot.loader.timeout = 1;

  boot.initrd.systemd.root = "gpt-auto";
  boot.initrd.supportedFilesystems = [ "ext4" ];

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

            "/EFI/netbootxyz.efi".source = "${pkgs.netbootxyz-efi}"; # emergency rescue
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
