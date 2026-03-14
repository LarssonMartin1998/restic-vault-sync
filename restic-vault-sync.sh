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
restic -r "$STAGING_DIR" --password-file "$RESTIC_PASSWORD_FILE" copy --from-repo "$REMOTE_REPO" --from-password-file "$RESTIC_PASSWORD_FILE"

log "Verifying staging repo integrity"
restic -r "$STAGING_DIR" --password-file "$RESTIC_PASSWORD_FILE" check --read-data

staging_count=$(restic -r "$STAGING_DIR" --password-file "$RESTIC_PASSWORD_FILE" snapshots --json | jq 'length')
log "Staging repo has $staging_count snapshot(s)"

for path in "${PATHS[@]}"; do
  if [[ -d "$path" ]]; then
    local_count=$(restic -r "$path" --password-file "$RESTIC_PASSWORD_FILE" snapshots --json | jq 'length')
    log "Local repo $path has $local_count snapshot(s)"
    if [[ "$staging_count" -lt "$local_count" ]]; then
      log "ERROR: Staging has fewer snapshots ($staging_count) than local repo $path ($local_count), aborting to protect local data" >&2
      exit 1
    fi
  fi

  log "Deploying to $path"
  target_dir="$(dirname "$path")"
  target_name="$(basename "$path")"
  new_path="${target_dir}/${target_name}.new"
  old_path="${target_dir}/${target_name}.old"

  rm -rf "$new_path"
  mkdir -p "$new_path"
  cp -a "$STAGING_DIR/." "$new_path"

  rm -rf "$old_path"
  if [[ -d "$path" ]]; then
    mv "$path" "$old_path"
  fi
  mv "$new_path" "$path"
  rm -rf "$old_path"

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
