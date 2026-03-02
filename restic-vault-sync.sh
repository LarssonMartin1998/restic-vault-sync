#!/usr/bin/env bash
set -euo pipefail

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required env var: $name" >&2
    exit 1
  fi
}

require_env "REMOTE_REPO"
require_env "RESTIC_PASSWORD_FILE"
require_env "LOCAL_REPO_PATHS"

if [[ ! -f "$RESTIC_PASSWORD_FILE" ]]; then
  echo "Password file does not exist: $RESTIC_PASSWORD_FILE" >&2
  exit 1
fi

IFS=':' read -ra PATHS <<< "$LOCAL_REPO_PATHS"
if [[ ${#PATHS[@]} -eq 0 ]]; then
  echo "LOCAL_REPO_PATHS is empty" >&2
  exit 1
fi

STAGING_DIR="$(mktemp -d /var/tmp/restic-vault-sync.XXXXXXXXXX)"
trap 'rm -rf "$STAGING_DIR"' EXIT

echo "Initializing staging repo at $STAGING_DIR"
restic -r "$STAGING_DIR" --password-file "$RESTIC_PASSWORD_FILE" init

echo "Copying from remote repo into staging"
restic -r "$STAGING_DIR" --password-file "$RESTIC_PASSWORD_FILE" copy --from-repo "$REMOTE_REPO"

echo "Verifying staging repo integrity"
restic -r "$STAGING_DIR" --password-file "$RESTIC_PASSWORD_FILE" check --read-data

for path in "${PATHS[@]}"; do
  echo "Deploying to $path"
  rm -rf "$path"
  mkdir -p "$path"
  cp -a "$STAGING_DIR/." "$path"
done

echo "Sync complete"
