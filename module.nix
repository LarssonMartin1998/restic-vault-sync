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

    monitoring = {
      endpoint = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "URL to POST a pulse to on successful sync.";
      };

      serviceName = lib.mkOption {
        type = lib.types.str;
        default = "restic-vault-sync";
        description = "Service name sent in the monitoring pulse payload.";
      };

      tokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to file containing the bearer token for monitoring.";
      };
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
        ] ++ lib.optionals (cfg.monitoring.endpoint != null) [
          "PING_ENDPOINT=${cfg.monitoring.endpoint}"
          "PING_SERVICE_NAME=${cfg.monitoring.serviceName}"
          "PING_TOKEN_FILE=${cfg.monitoring.tokenFile}"
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
