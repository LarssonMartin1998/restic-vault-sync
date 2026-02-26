#!/usr/bin/env bash
set -euo pipefail

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required env var: $name" >&2
    exit 1
  fi
}

require_env "SSH_HOST"
require_env "REMOTE_PATH"
require_env "LOCAL_PATH"

: "${SSH_HOST:?}"
: "${REMOTE_PATH:?}"
: "${LOCAL_PATH:?}"

RSYNC_EXTRA_ARGS="${RSYNC_EXTRA_ARGS:-}"

ssh_cmd=(ssh)

rsync_cmd=(rsync)
if [[ -n "$RSYNC_EXTRA_ARGS" ]]; then
  read -r -a rsync_extra_array <<<"$RSYNC_EXTRA_ARGS"
  rsync_cmd+=("${rsync_extra_array[@]}")
else
  rsync_cmd+=(-a --delete)
fi

timestamp="$(date -u +"%Y%m%d%H%M%S")"
backup_path=""
sync_success=0

cleanup() {
  if [[ -n "$backup_path" && -e "$backup_path" ]]; then
    if [[ "$sync_success" -eq 1 ]]; then
      rm -rf "$backup_path"
    else
      if [[ -e "$LOCAL_PATH" ]]; then
        rm -rf "$LOCAL_PATH"
      fi
      mv "$backup_path" "$LOCAL_PATH"
    fi
  fi
}
trap cleanup EXIT

if [[ -e "$LOCAL_PATH" ]]; then
  backup_path="${LOCAL_PATH}.bak-${timestamp}"
  mv "$LOCAL_PATH" "$backup_path"
fi

mkdir -p "$LOCAL_PATH"

remote_path="${REMOTE_PATH%/}/"
local_path="${LOCAL_PATH%/}/"

rsync_cmd+=(-e "${ssh_cmd[*]}")
rsync_cmd+=("${SSH_HOST}:${remote_path}" "$local_path")

"${rsync_cmd[@]}"
sync_success=1
