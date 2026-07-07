#!/usr/bin/env bash



set -euo pipefail

source "$(dirname "$0")/common_all.sh"
source "$(dirname "$0")/common_base_vm.sh"

ACTUAL_VM_NAME="${1:-$VM_NAME}"

virsh start "$ACTUAL_VM_NAME"

echo
echo "==> Waiting for start to complete"
while true; do
    state=$(virsh domstate "$ACTUAL_VM_NAME" 2>/dev/null || echo "unknown")
    [[ "$state" == "running" ]] && break
    echo "    VM state: $state — waiting 10s..."
    sleep 10
done

# wait for it to be stable to get the IP address.
sleep 10

echo
echo "==> VM '$ACTUAL_VM_NAME' is running."
echo "    Connect to serial console : virsh console $ACTUAL_VM_NAME"
echo "    Find its IP               : virsh domifaddr $ACTUAL_VM_NAME"
guest_vm_ip=$(virsh domifaddr "$ACTUAL_VM_NAME" | awk '/ipv4/ {print $4}' | cut -d/ -f1)
if [[ -n "$guest_vm_ip" ]]; then
    echo "    SSH (once you know the IP): ssh -i vm_devops -o IdentitiesOnly=yes devops@${guest_vm_ip}"
else
    echo "    SSH (once you know the IP): ssh -i vm_devops -o IdentitiesOnly=yes devops@<ip>"
fi
echo "    When done run: virsh destroy $ACTUAL_VM_NAME"
