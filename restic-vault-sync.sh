#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[$(date -Iseconds)] $*"
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    log "ERROR: Missing required env var: $name" >&2
    exit 1
  fi
}

require_env "REMOTE_REPO"
require_env "RESTIC_PASSWORD_FILE"
require_env "LOCAL_REPO_PATHS"

if [[ ! -f "$RESTIC_PASSWORD_FILE" ]]; then
  log "ERROR: Password file does not exist: $RESTIC_PASSWORD_FILE" >&2
  exit 1
fi

IFS=':' read -ra PATHS <<< "$LOCAL_REPO_PATHS"
if [[ ${#PATHS[@]} -eq 0 ]]; then
  log "ERROR: LOCAL_REPO_PATHS is empty" >&2
  exit 1
fi

log "Starting restic vault sync"
log "Remote repo: $REMOTE_REPO"
log "Local targets: ${PATHS[*]}"

STAGING_DIR="$(mktemp -d /var/tmp/restic-vault-sync.XXXXXXXXXX)"
trap 'log "Cleaning up staging dir"; rm -rf "$STAGING_DIR"' EXIT

log "Initializing staging repo at $STAGING_DIR"
restic -r "$STAGING_DIR" --password-file "$RESTIC_PASSWORD_FILE" init

log "Copying from remote repo into staging"
restic -r "$STAGING_DIR" --password-file "$RESTIC_PASSWORD_FILE" copy --from-repo "$REMOTE_REPO"

log "Verifying staging repo integrity"
restic -r "$STAGING_DIR" --password-file "$RESTIC_PASSWORD_FILE" check --read-data

for path in "${PATHS[@]}"; do
  log "Deploying to $path"
  rm -rf "$path"
  mkdir -p "$path"
  cp -a "$STAGING_DIR/." "$path"
  log "Deployed to $path"
done

log "Sync complete"

if [[ -n "${PING_ENDPOINT:-}" ]]; then
  log "Sending monitoring pulse"
  ping_auth_token=$(cat "$PING_TOKEN_FILE")
  if ! cmd_output=$(jq -n --arg service_name "$PING_SERVICE_NAME" '{service_name: $service_name}' | xh POST "$PING_ENDPOINT" Authorization:"Bearer $ping_auth_token" 2>&1); then
    log "WARNING: Monitoring pulse failed: $cmd_output"
  else
    log "Monitoring pulse sent"
  fi
fi
