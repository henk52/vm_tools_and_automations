#!/usr/bin/env bash

# Sync files from the guest to the host.

set -euo pipefail

script_dir="$(dirname "$0")"

SOURCE_IP="${1:-}"
SOURCE_DIR="${2:-}"
DESTINATION_DIR="${3:-}"

if [[ -z "$DESTINATION_DIR" ]]; then
  DESTINATION_DIR="./"
  echo "Destination directory not specified. Defaulting to ${DESTINATION_DIR} on the VM."
fi

if [[ -z "$SOURCE_DIR" || -z "$SOURCE_IP" ]]; then
    echo "Usage: $0 <source-dir> <target-ip> [<target-dir>]"
    exit 1
fi

SSH_CMD="ssh -i ${script_dir}/vm_llm -o IdentitiesOnly=yes"
RSYNC_SRC="llm@${SOURCE_IP}:${SOURCE_DIR}/"

deletions="$(rsync -avzn --delete-after -i -e "$SSH_CMD" "$RSYNC_SRC" "${DESTINATION_DIR}/" | grep '^\*deleting' || true)"

RSYNC_OPTS=(-avz --delete-after)
if [[ -n "$deletions" ]]; then
  echo "The following files will be deleted on the host:"
  echo "$deletions"
  read -r -p "Proceed with deletion? [y/N] " confirm </dev/tty
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Skipping deletion. Files will still be synced."
    RSYNC_OPTS=(-avz)
  fi
fi

rsync "${RSYNC_OPTS[@]}" -e "$SSH_CMD" "$RSYNC_SRC" "${DESTINATION_DIR}/"
