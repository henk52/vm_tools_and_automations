#!/usr/bin/env bash
set -euo pipefail

# This script adds a host directory as a virtiofs share to a stopped VM.

VM_NAME="${1:-dev_gui_vm}"
HOST_DIRECTORY="${2:-$HOME/workspace}"
TAG="hostshare"

SRC_DIRECTORY="$(realpath -m "$HOST_DIRECTORY")"   # libvirt needs an absolute path
if [ ! -d "$SRC_DIRECTORY" ]; then
  echo "Source directory does not exist: $SRC_DIRECTORY"
  exit 1
fi

# Shut down VM if running
if [ "$(sudo virsh domstate "$VM_NAME")" != "shut off" ]; then
  echo "You need to shut down the VM before adding a host share. Please shut down the VM: $VM_NAME"
  while [ "$(sudo virsh domstate "$VM_NAME")" != "shut off" ]; do sleep 10; done
fi

# Shared memory (required by virtiofs)
sudo virt-xml "$VM_NAME" --edit --memorybacking source.type=memfd,access.mode=shared

# Add rw virtiofs share, unless the tag already exists
if ! sudo virsh dumpxml --inactive "$VM_NAME" | grep -q "<target dir='$TAG'/>"; then
  sudo virt-xml "$VM_NAME" --add-device \
    --filesystem source.dir="$SRC_DIRECTORY",target.dir="$TAG",driver.type=virtiofs
fi

LINE='hostshare  /home/devops/workspace  virtiofs  defaults,nofail  0 0'

# Only add the line if it's not already there
if ! sudo virt-cat -d "$VM_NAME" /etc/fstab | grep -q '^hostshare'; then
  sudo virt-customize -d "$VM_NAME" \
    --mkdir /home/devops/workspace \
    --append-line "/etc/fstab:$LINE" \
    --run-command 'chown devops:devops /home/devops/workspace' \
    --selinux-relabel
fi

echo "You can start the VM now: sudo virsh start $VM_NAME"
echo "In guest: sudo mount -t virtiofs $TAG /mnt/$TAG"
echo "or put it in /etc/fstab for automatic mounting on boot:"
echo "$TAG /mnt/$TAG virtiofs defaults 0 0"
echo "sudo systemctl daemon-reload"
echo "sudo mount -a"