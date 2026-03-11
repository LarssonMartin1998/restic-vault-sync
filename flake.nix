{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = {
          restic-vault-sync = pkgs.writeShellApplication {
            name = "restic-vault-sync";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.openssh
              pkgs.restic
              pkgs.jq
              pkgs.xh
            ];
            text = builtins.readFile ./restic-vault-sync.sh;
          };
          default = self.packages.${system}.restic-vault-sync;
        };
      }
    )
    // {
      nixosModules.default = import ./module.nix { inherit self; };
    };
}
