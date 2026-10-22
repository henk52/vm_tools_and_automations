#!/usr/bin/env bash

# create-centos10-vm.sh
# Hands-off KVM guest install of CentOS Stream 10 (minimal + sshd)
# via virt-install + kickstart injected directly into the initrd.
#
# Requirements on the HOST:
#   dnf install virt-install libvirt qemu-kvm   (RHEL/CentOS/Fedora)
#   apt install virtinst libvirt-daemon-system  (Debian/Ubuntu)
#   systemctl enable --now libvirtd
#
# Usage:  sudo bash create-centos10-vm.sh
# ---------------------------------------------------------------

set -euo pipefail

source "$(dirname "$0")/common_all.sh"
source "$(dirname "$0")/common_base_vm.sh"

# ── Adjust these variables ──────────────────────────────────────
VCPUS=2
MEM_MB=8192
DISK_GB=20
DISK_PATH="/var/lib/libvirt/images/${VM_NAME}.qcow2"
BRIDGE="virbr0"           # or your custom bridge, e.g. br0
#ISO="/var/lib/libvirt/images/CentOS-Stream-10-latest-x86_64-dvd1.iso"
ISO="$HOME/Downloads/CentOS-Stream-10-latest-x86_64-dvd1.iso"
KS_FILE="$(dirname "$0")/ks.cfg"   # path to the kickstart file
# ────────────────────────────────────────────────────────────────

# Verify prerequisites
for cmd in virt-install virsh; do
    command -v "$cmd" &>/dev/null || { echo "ERROR: $cmd not found. Install virt-install/libvirt."; exit 1; }
done
[[ -f "$ISO"     ]] || { echo "ERROR: ISO not found: $ISO";     exit 1; }
[[ -f "$KS_FILE" ]] || { echo "ERROR: Kickstart not found: $KS_FILE"; exit 1; }

# Resolve the correct --os-variant for CentOS Stream 10.
# Try the exact name first; fall back to centos-stream9 if osinfo-db is older.
OS_VARIANT="centos-stream10"
# TODO sudo apt install libosinfo-bin
# TODO test the osinfor-query exists
if ! osinfo-query os short-id="$OS_VARIANT" &>/dev/null 2>&1; then
    echo "WARNING: osinfo-db does not know '$OS_VARIANT'; falling back to centos-stream9."
    echo "         Run: sudo osinfo-db-import --local \$(osinfo-db-tools --version) to update."
    OS_VARIANT="centos-stream9"
fi

echo "==> Creating VM: $VM_NAME"
echo "    ISO      : $ISO"
echo "    Kickstart: $KS_FILE"
echo "    Disk     : $DISK_PATH (${DISK_GB} GB)"
echo "    OS hint  : $OS_VARIANT"
echo
echo "    ETA 9-12 minutes for installation, then the VM will shut off automatically."

#    --network      "bridge=${BRIDGE},model=virtio" \

#     --connect      qemu:///system \
#    puts it in the sudo space.

# Puts it in the user space.
#    --connect      qemu:///session \


virt-install \
    --connect      ${LIBVIRT_DEFAULT_URI} \
    --name         "$VM_NAME" \
    --vcpus        "$VCPUS" \
    --memory       "$MEM_MB" \
    --os-variant   "$OS_VARIANT" \
    --location     "$ISO" \
    --disk         "path=${DISK_PATH},size=${DISK_GB},format=qcow2,bus=virtio" \
    --network      default \
    --graphics     none \
    --console      "pty,target_type=serial" \
    --initrd-inject "$KS_FILE" \
    --extra-args   "inst.ks=file:/ks.cfg console=tty0 console=ttyS0,115200n8" \
    --noautoconsole \
    --noreboot


# Wait for the installer to finish and the VM to shut off (--noreboot ensures this)
echo
echo "==> Waiting for installation to complete (VM will shut off when done)..."
while true; do
    state=$(virsh domstate "$VM_NAME" 2>/dev/null || echo "unknown")
    [[ "$state" == "shut off" ]] && break
    echo "    VM state: $state — waiting 10s..."
    sleep 10
done

echo "==> Installation complete."
