#!/usr/bin/env bash

# This script cleans a qcow2 image so the image can be used as a base image for virtual machines.
#  One important act is to empty the /etc/machine-id, so a unique id is generated when the vm is deployed.
#  The source disk is located directly from the existing libvirt VM named SOURCE_VM_NAME, so there
#  is no need to manually qemu-img convert the disk out of /var/lib/libvirt/images first.

# usage: ./virt-cloud-builder.sh ks_centos10_minimal base_centos10_minimal

set -o errexit
set -o pipefail

source "$(dirname "$0")/common_all.sh"

# original: https://gist.github.com/nkabir/71bf64e45013dcd965374fdaec95613d
# To get the tools
# sudo apt install guestfs-tools

readonly KVM_IMAGE_DESTINATION_DIRECTORY="${HOME}/tmp"
readonly KVM_IMAGE_FORMAT="qcow2"

SOURCE_VM_NAME="$1"
if [[ -z "${SOURCE_VM_NAME}" ]]; then
  echo "ERROR: SOURCE_VM_NAME is empty or not set"
  exit 1
fi

IMAGE_NAME="$2"
if [[ -z "${IMAGE_NAME}" ]]; then
  echo "ERROR: IMAGE_NAME is empty or not set"
  exit 1
fi

# absolute path to virtbuilder file
readonly VB_FA="${KVM_IMAGE_DESTINATION_DIRECTORY:?}/${IMAGE_NAME:?}.${KVM_IMAGE_FORMAT:?}"

# Resolves the qcow2 disk path of an existing libvirt VM by name.
resolve_source_disk_path() {
  local vm_name="$1"

  virsh dominfo "${vm_name}" &>/dev/null \
    || { echo "ERROR: VM '${vm_name}' not found (checked ${LIBVIRT_DEFAULT_URI:-the default libvirt URI})" >&2; exit 1; }

  local disk_path
  disk_path="$(virsh domblklist "${vm_name}" --details | awk '$2=="disk"{print $4; exit}')"

  [[ -n "${disk_path}" && -f "${disk_path}" ]] \
    || { echo "ERROR: could not resolve a disk file for VM '${vm_name}'" >&2; exit 1; }

  echo "${disk_path}"
}

SOURCE_DISK_PATH="$(resolve_source_disk_path "${SOURCE_VM_NAME}")"
readonly SOURCE_DISK_PATH

mkdir -p "${KVM_IMAGE_DESTINATION_DIRECTORY:?}"

# Copies the VM's disk out of /var/lib/libvirt/images so it can be cleaned without touching the original.
sudo qemu-img convert -p -O "${KVM_IMAGE_FORMAT:?}" "${SOURCE_DISK_PATH:?}" "${VB_FA:?}"

# If you need to debug the process_
# export LIBGUESTFS_DEBUG=1 LIBGUESTFS_TRACE=1

# TODO make it optional to change the hostname?    --hostname "${SOURCE_VM_NAME:?}" \

# generates <name>-vb.qcow2
sudo virt-customize -v\
    --format "${KVM_IMAGE_FORMAT:?}" \
    --no-network \
    --run-command "truncate -s 0 /etc/machine-id" \
    --firstboot-command "sync" \
    -a "${VB_FA:?}"

