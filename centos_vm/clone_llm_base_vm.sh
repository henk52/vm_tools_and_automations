#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/common_all.sh"

NEW_VM_NAME="${1:-}"
BASE_VM_NAME="${2:-}"

# The "devops" account and its key are baked into the base image by ks.cfg.
# Not needed by this script (cloud-init completion is verified without
# booting - see below), but handy for manually logging in to troubleshoot.
DEVOPS_SSH_KEY="$(dirname "$0")/vm_devops"
LLM_SSH_KEY="$(dirname "$0")/vm_llm"


if [[ -z "$NEW_VM_NAME" || -z "$BASE_VM_NAME" ]]; then
    echo "Usage: $0 <new-vm-name> <base-vm-name>"
    exit 1
fi

# Verify the base VM exists and is shut off
if ! virsh domstate "$BASE_VM_NAME" 2>/dev/null | grep -q "shut off"; then
    echo "Error: Base VM '$BASE_VM_NAME' does not exist or is not shut off."
    exit 1
fi

# verify that the new VM name does not already exist
if virsh domstate "$NEW_VM_NAME" 2>/dev/null | grep -q "running\|shut off"; then
    echo "Error: VM '$NEW_VM_NAME' already exists."
    exit 1
fi

virt-clone --original "$BASE_VM_NAME" --name "$NEW_VM_NAME" --auto-clone

echo
echo "==> VM '$NEW_VM_NAME' is provisioned and shut off, ready to transfer."
#echo "    Disk       : $DISK_PATH"
echo "    Start it   : virsh start $NEW_VM_NAME"
echo "    Find its IP: virsh domifaddr $NEW_VM_NAME"
echo "    SSH        : ssh -i $LLM_SSH_KEY -o IdentitiesOnly=yes llm@<ip>"
echo "    Rescue SSH : ssh -i $DEVOPS_SSH_KEY -o IdentitiesOnly=yes devops@<ip>"
