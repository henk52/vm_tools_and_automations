#!/usr/bin/env bash

set -euo pipefail

script_dir="$(dirname "$0")"


source "${script_dir}/common_all.sh"

ACTUAL_VM_NAME="${1:-"llm_vm"}"

virsh domifaddr "$ACTUAL_VM_NAME"

guest_vm_ip=$(virsh domifaddr "$ACTUAL_VM_NAME" | awk '/ipv4/ {print $4}' | cut -d/ -f1)
if [[ -n "$guest_vm_ip" ]]; then
    ssh -i "${script_dir}/vm_llm" -o IdentitiesOnly=yes llm@${guest_vm_ip}
else
    echo "    SSH (once you know the IP): ssh -i "${script_dir}/vm_llm" -o IdentitiesOnly=yes llm@<ip>"
fi
