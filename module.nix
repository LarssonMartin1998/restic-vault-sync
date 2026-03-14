{ self }:

{ config, lib, pkgs, ... }:

let
  cfg = config.services.resticVaultSync;

  instanceModule = lib.types.submodule {
    options = {
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
  };

  mkService = name: icfg: lib.mkIf icfg.enable {
    description = "Sync restic repository from vault (${name})";
    serviceConfig = {
      Type = "oneshot";
      User = icfg.user;
      Group = icfg.group;
      ExecStart = "${icfg.package}/bin/restic-vault-sync";
      Environment = [
        "HOME=${if icfg.user == "root" then "/root" else "/home/${icfg.user}"}"
        "LOCAL_REPO_PATHS=${lib.concatStringsSep ":" icfg.localRepoPaths}"
        "REMOTE_REPO=${icfg.remoteRepo}"
        "RESTIC_PASSWORD_FILE=${icfg.passwordFile}"
      ] ++ lib.optionals (icfg.monitoring.endpoint != null) [
        "PING_ENDPOINT=${icfg.monitoring.endpoint}"
        "PING_SERVICE_NAME=${icfg.monitoring.serviceName}"
        "PING_TOKEN_FILE=${icfg.monitoring.tokenFile}"
      ];
    };
  };

  mkTimer = name: icfg: lib.mkIf icfg.enable {
    description = "Timer for restic vault sync (${name})";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = icfg.schedule;
      Persistent = true;
    };
  };
in
{
  options.services.resticVaultSync = lib.mkOption {
    type = lib.types.attrsOf instanceModule;
    default = {};
    description = "Named restic vault sync instances.";
  };

  config = {
    systemd.services = lib.mapAttrs' (name: icfg:
      lib.nameValuePair "restic-vault-sync-${name}" (mkService name icfg)
    ) cfg;

    systemd.timers = lib.mapAttrs' (name: icfg:
      lib.nameValuePair "restic-vault-sync-${name}" (mkTimer name icfg)
    ) cfg;
  };
}
