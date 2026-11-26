{
  description = "NixOS configuration for the Raspberry Pi music appliance";

  inputs = {
    # Stable release for an unattended host; updated deliberately via flake.lock.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Only for packages that are too old on stable (sendspin).
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Raspberry Pi 4 board profile: firmware partition, config.txt, onboard audio.
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      deploy-rs,
      ...
    }@inputs:
    let
      # The laptop that builds and deploys.
      devSystem = "x86_64-linux";
      devPkgs = nixpkgs.legacyPackages.${devSystem};
      # deploy-rs's library, but with nixpkgs' deploy-rs binary, which is in the
      # binary cache (deploy-rs's own package would compile from source).
      # Pattern from the deploy-rs README.
      deployPkgs = import nixpkgs {
        system = "aarch64-linux";
        overlays = [
          deploy-rs.overlays.default
          (_final: prev: {
            deploy-rs = {
              inherit (nixpkgs.legacyPackages.aarch64-linux) deploy-rs;
              inherit (prev.deploy-rs) lib;
            };
          })
        ];
      };
    in
    {
      nixosConfigurations.rpi = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/rpi ];
      };

      # `nix build .#sd-image` -> result/sd-image/*.img.zst, flashable to an SD card.
      packages.${devSystem}.sd-image = self.nixosConfigurations.rpi.config.system.build.sdImage;

      # `deploy .#rpi` (dev shell): build on the laptop, copy, activate; rolls back automatically
      # if the Pi cannot be reached over SSH after activation.
      deploy.nodes.rpi = {
        hostname = "rpi.local";
        sshUser = "pi";
        user = "root";
        profiles.system.path = deployPkgs.deploy-rs.lib.activate.nixos self.nixosConfigurations.rpi;
      };

      checks.${devSystem}.deploy-schema =
        (deploy-rs.lib.${devSystem}.deployChecks self.deploy).deploy-schema;

      devShells.${devSystem}.default = devPkgs.mkShell {
        packages = [
          devPkgs.deploy-rs
          devPkgs.zstd
        ];
      };

      formatter.${devSystem} = devPkgs.nixfmt-tree;
    };
}
