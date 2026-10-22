#!/usr/bin/env bash

# Sync files from the host to the VM.

set -euo pipefail

script_dir="$(dirname "$0")"

SOURCE_DIR="${1:-}"
TARGET_IP="${2:-}"
TARGET_DIR="${3:-}"

if [[ -z "$TARGET_DIR" ]]; then
  TARGET_DIR="/home/llm"
  echo "Target directory not specified. Defaulting to ${TARGET_DIR} on the VM."
fi

if [[ -z "$SOURCE_DIR" || -z "$TARGET_IP" ]]; then
    echo "Usage: $0 <source-dir> <target-ip> [<target-dir>]"
    exit 1
fi

SSH_CMD="ssh -i ${script_dir}/vm_llm -o IdentitiesOnly=yes"
RSYNC_DEST="llm@${TARGET_IP}:${TARGET_DIR}/"

echo "DDD running: rsync -avzn --delete-after -i -e $SSH_CMD $SOURCE_DIR/ $RSYNC_DEST"

deletions="$(rsync -avzn --delete-after -i -e "$SSH_CMD" "$SOURCE_DIR/" "$RSYNC_DEST" | grep '^\*deleting' || true)"

RSYNC_OPTS=(-avz --delete-after)
if [[ -n "$deletions" ]]; then
  echo "The following files will be deleted on the VM:"
  echo "$deletions"
  read -r -p "Proceed with deletion? [y/N] " confirm </dev/tty
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Skipping deletion. Files will still be synced."
    RSYNC_OPTS=(-avz)
  fi
fi

rsync "${RSYNC_OPTS[@]}" -e "$SSH_CMD" "$SOURCE_DIR/" "$RSYNC_DEST"
