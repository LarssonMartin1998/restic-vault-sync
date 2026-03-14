# restic-vault-sync

NixOS module for syncing remote restic repos to local paths. Copies through a staging repo, verifies integrity, and only deploys if the snapshot count hasn't decreased. Supports multiple named instances.

## Usage

Add the flake and import the module, then configure your instances:

```nix
services.resticVaultSync = {
  photos-nas = {
    enable = true;
    remoteRepo = "sftp:nas:/volume1/restic/photos";
    localRepoPaths = [ "/mnt/backups/photos" ];
    passwordFile = "/run/secrets/photos-password";
    schedule = "daily";
  };
  documents-offsite = {
    enable = true;
    remoteRepo = "sftp:offsite:/backup/documents";
    localRepoPaths = [ "/mnt/backups/documents" "/mnt/usb/documents" ];
    passwordFile = "/run/secrets/documents-password";
    schedule = "weekly";
  };
};
```

Each instance gets its own systemd service and timer, e.g. `restic-vault-sync-photos-nas.service`.

## Options

| Option | Type | Default | Description |
|---|---|---|---|
| `enable` | bool | `false` | Enable this sync instance |
| `remoteRepo` | string | required | Remote restic repo URL (e.g. `sftp:host:/path`) |
| `localRepoPaths` | list of strings | required | Local paths to sync to |
| `passwordFile` | string | required | Path to the restic password file |
| `schedule` | string | `"daily"` | systemd OnCalendar value |
| `user` | string | `"root"` | User to run the service |
| `group` | string | `"root"` | Group to run the service |
| `monitoring.endpoint` | string or null | `null` | URL to POST a pulse to on success |
| `monitoring.serviceName` | string | `"restic-vault-sync"` | Service name in the monitoring payload |
| `monitoring.tokenFile` | string or null | `null` | Bearer token file for monitoring |
