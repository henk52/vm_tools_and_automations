#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/common_all.sh"

BASE_VM_NAME="${1:-}"
NEW_VM_NAME="${2:-}"
NEW_DISK_GB="${3:-}"   # empty = keep the base VM's disk size

# Partition / LV layout created by ks.cfg (vda3 = LVM PV, VG "cs", LV "root").
# virt-resize sees the disk as /dev/sda.
ROOT_PV_PART="/dev/sda3"
ROOT_LV="/dev/cs/root"

# The "devops" account and its key are baked into the base image by ks.cfg.
# Not needed by this script (cloud-init completion is verified without
# booting - see below), but handy for manually logging in to troubleshoot.
DEVOPS_SSH_KEY="$(dirname "$0")/vm_devops"
LLM_SSH_KEY="$(dirname "$0")/vm_llm"


if [[ -z "$NEW_VM_NAME" || -z "$BASE_VM_NAME" ]]; then
    echo "Usage: $0 <base-vm-name> <new-vm-name> [disk-size-gb (default: base VM size)]"
    exit 1
fi

if [[ -n "$NEW_DISK_GB" ]] && ! [[ "$NEW_DISK_GB" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: disk size must be a positive integer (GB), got '$NEW_DISK_GB'."
    exit 1
fi

for cmd in virsh virt-clone virt-resize qemu-img; do
    command -v "$cmd" &>/dev/null || { echo "Error: $cmd not found (virt-resize: dnf install guestfs-tools)."; exit 1; }
done

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

# Grow the clone's disk, partition, LVM PV, root LV and ext4 filesystem offline.
DISK_PATH="$(virsh domblklist "$NEW_VM_NAME" --details | awk '$2=="disk"{print $4; exit}')"
if [[ -z "$DISK_PATH" ]] || ! sudo test -f "$DISK_PATH"; then
    echo "Error: could not locate disk image for '$NEW_VM_NAME'."
    exit 1
fi

CURRENT_BYTES="$(sudo qemu-img info --output=json "$DISK_PATH" | awk -F': *' '/"virtual-size"/{gsub(/[^0-9]/,"",$2); print $2; exit}')"
if [[ -n "$NEW_DISK_GB" ]]; then
    TARGET_BYTES=$(( NEW_DISK_GB * 1024 * 1024 * 1024 ))
else
    TARGET_BYTES="$CURRENT_BYTES"
fi

if (( TARGET_BYTES < CURRENT_BYTES )); then
    echo "Error: requested ${NEW_DISK_GB} GB is smaller than current disk ($(( CURRENT_BYTES / 1024 / 1024 / 1024 )) GB); shrinking not supported."
    exit 1
elif (( TARGET_BYTES > CURRENT_BYTES )); then
    TMP_DISK="${DISK_PATH%.qcow2}.resize.qcow2"
    trap 'sudo rm -f "$TMP_DISK"' EXIT

    echo "==> Resizing disk to ${NEW_DISK_GB} GB: $DISK_PATH"
    sudo qemu-img create -q -f qcow2 "$TMP_DISK" "${NEW_DISK_GB}G"
    sudo virt-resize --expand "$ROOT_PV_PART" --LV-expand "$ROOT_LV" "$DISK_PATH" "$TMP_DISK"

    # Preserve the original image's ownership, mode and SELinux label.
    sudo chown --reference="$DISK_PATH" "$TMP_DISK"
    sudo chmod --reference="$DISK_PATH" "$TMP_DISK"
    sudo chcon --reference="$DISK_PATH" "$TMP_DISK" 2>/dev/null || true
    sudo mv -f "$TMP_DISK" "$DISK_PATH"
    trap - EXIT
else
    echo "==> Keeping base VM disk size, skipping resize."
fi

echo
echo "==> VM '$NEW_VM_NAME' is provisioned and shut off, ready to transfer."
echo "    Disk       : $DISK_PATH ($(( TARGET_BYTES / 1024 / 1024 / 1024 )) GB)"
echo "    Start it   : virsh start $NEW_VM_NAME"
echo "    Find its IP: virsh domifaddr $NEW_VM_NAME"
echo "    SSH        : ssh -i $LLM_SSH_KEY -o IdentitiesOnly=yes devops@<ip>"
echo "    Rescue SSH : ssh -i $DEVOPS_SSH_KEY -o IdentitiesOnly=yes devops@<ip>"
