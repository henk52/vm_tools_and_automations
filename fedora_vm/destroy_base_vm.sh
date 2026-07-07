#!/usr/bin/env bash

# destroy the vm created by create_vm_sh.sh

source "$(dirname "$0")/common_all.sh"
source "$(dirname "$0")/common_base_vm.sh"

VM_NAME_TO_DESTROY="${1:-$VM_NAME}"

echo "III destroy vm"
virsh destroy "$VM_NAME_TO_DESTROY"
echo "III remove storage and undefine vm"
virsh undefine "$VM_NAME_TO_DESTROY" --remove-all-storage
