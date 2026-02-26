{ pkgs }:

pkgs.writeShellApplication {
  name = "restic-vault-sync";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.openssh
    pkgs.rsync
  ];
  text = builtins.readFile ../scripts/restic-vault-sync.sh;
}
