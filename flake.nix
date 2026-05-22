{
  inputs = {
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs.git?ref=nixos-unstable-small&shallow=1";
  };

  outputs =
    { self, nixpkgs }:
    {
      nixosConfigurations = {
        # UEFI 
        arm-init = nixpkgs.lib.nixosSystem { modules = [ ./arm.nix ]; };
        
        amd-init = nixpkgs.lib.nixosSystem {
          modules = [
            ./arm.nix
            {
              networking.hostName = "amd-init";
              nixpkgs.hostPlatform = "x86_64-linux";
            }
          ];
        };

        # BIOS
        bios-init = nixpkgs.lib.nixosSystem { modules = [ ./bios.nix ]; };
      };

      packages.x86_64-linux.limine = nixpkgs.legacyPackages.x86_64-linux.limine;

    };
}
