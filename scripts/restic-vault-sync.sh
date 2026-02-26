#!/usr/bin/env bash
set -euo pipefail

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required env var: $name" >&2
    exit 1
  fi
}

require_env "LOCAL_REPO"
require_env "REMOTE_REPO"
require_env "RESTIC_PASSWORD_FILE"

if [[ ! -e "$LOCAL_REPO/config" ]]; then
  restic -r "$LOCAL_REPO" init
fi

restic -r "$LOCAL_REPO" copy --from-repo "$REMOTE_REPO"
