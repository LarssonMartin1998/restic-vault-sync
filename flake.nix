{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = {
          restic-vault-sync = pkgs.callPackage ./nix/restic-vault-sync.nix { };
          default = self.packages.${system}.restic-vault-sync;
        };
      })
    // {
      nixosModules.restic-vault-sync = import ./nix/restic-vault-sync-module.nix;
    };
}
