{ config, lib, pkgs, ... }:

let
  cfg = config.services.resticVaultSync;
  defaultPackage = pkgs.callPackage ./restic-vault-sync.nix { };
in
{
  options.services.resticVaultSync = {
    enable = lib.mkEnableOption "sync a restic repository from a remote vault";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
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

    remotePath = lib.mkOption {
      type = lib.types.str;
      description = "Remote path to the restic repository on the vault.";
    };

    localPath = lib.mkOption {
      type = lib.types.str;
      description = "Local path where the repository will be synced.";
    };

    ssh = {
      host = lib.mkOption {
        type = lib.types.str;
        description = "SSH host entry from ssh config for the vault server.";
      };
    };

    rsyncExtraArgs = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Extra arguments passed to rsync (space-separated).";
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
          "SSH_HOST=${cfg.ssh.host}"
          "REMOTE_PATH=${cfg.remotePath}"
          "LOCAL_PATH=${cfg.localPath}"
        ]
        ++ lib.optionals (cfg.rsyncExtraArgs != "") [
          "RSYNC_EXTRA_ARGS=${cfg.rsyncExtraArgs}"
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
