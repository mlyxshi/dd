{
  inputs = {
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs.git?ref=nixos-unstable-small&shallow=1";
  };

  outputs =
    { self, nixpkgs }:
    {
      nixosConfigurations = {
        # UEFI 
        arm-init = nixpkgs.lib.nixosSystem { modules = [ ./nixos/uefi.nix ]; };
        
        amd-init = nixpkgs.lib.nixosSystem {
          modules = [
            ./nixos/uefi.nix
            {
              networking.hostName = "amd-init";
              nixpkgs.hostPlatform = "x86_64-linux";
            }
          ];
        };

        # BIOS
        bios-init = nixpkgs.lib.nixosSystem { modules = [ ./nixos/bios.nix ]; };
      };
    };
}
