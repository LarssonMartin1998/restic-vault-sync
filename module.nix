{ self }:

{ config, lib, pkgs, ... }:

let
  cfg = config.services.resticVaultSync;
in
{
  options.services.resticVaultSync = {
    enable = lib.mkEnableOption "sync a restic repository from a remote vault";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.system}.restic-vault-sync;
      description = "Package providing the restic vault sync script.";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "systemd OnCalendar value for the sync timer.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "User account used to run the sync service.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "Group used to run the sync service.";
    };

    localRepoPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "List of local restic repository paths to sync to.";
    };

    remoteRepo = lib.mkOption {
      type = lib.types.str;
      description = "Remote restic repository URL (e.g. sftp:host:/path).";
    };

    passwordFile = lib.mkOption {
      type = lib.types.str;
      description = "Path to restic password file for non-interactive access.";
    };

  };

  config = lib.mkIf cfg.enable {
    systemd.services.restic-vault-sync = {
      description = "Sync restic repository from vault";
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${cfg.package}/bin/restic-vault-sync";
        Environment = [
          "LOCAL_REPO_PATHS=${lib.concatStringsSep ":" cfg.localRepoPaths}"
          "REMOTE_REPO=${cfg.remoteRepo}"
          "RESTIC_PASSWORD_FILE=${cfg.passwordFile}"
        ];
      };
    };

    systemd.timers.restic-vault-sync = {
      description = "Timer for restic vault sync";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
      };
    };
  };
}
