#!/usr/bin/env bash

# Create a GUI (GNOME) VM for LLM development.
# Same as create_llm_base_vm.sh, plus:
#   - SPICE graphics + virtio video in the guest configuration
#   - ansible/gnome-desktop.yml shipped via cloud-init and run locally in the guest

# Example: ./create_dev_gui_vm.sh llm_fedora_gui llm_fedora_base.qcow2

set -euo pipefail

source "$(dirname "$0")/common_all.sh"
source "$(dirname "$0")/common_base_vm.sh"

NEW_VM_NAME="${1:-}"
SOURCE_QCOW_FILE="${2:-}"

if [[ -z "$NEW_VM_NAME" || -z "$SOURCE_QCOW_FILE" ]]; then
    echo "Usage: $0 <new-vm-name> <source-qcow-file>" >&2
    echo "  <source-qcow-file> may be a full path, or a base image name (as produced by virt-cloud-builder.sh)" >&2
    exit 1
fi

if [[ "$SOURCE_QCOW_FILE" == *"/"* ]]; then
    BASE_IMAGE_PATH="${SOURCE_QCOW_FILE/#\~/$HOME}"
elif [[ "$SOURCE_QCOW_FILE" == *.qcow2 ]]; then
    BASE_IMAGE_PATH="$HOME/tmp/${SOURCE_QCOW_FILE}"
else
    BASE_IMAGE_PATH="$HOME/tmp/${SOURCE_QCOW_FILE}.qcow2"
fi

# ── Adjust these variables ──────────────────────────────────────
LLM_VM_NAME="${NEW_VM_NAME}"
VCPUS=2
MEM_MB=8192
DISK_PATH="/var/lib/libvirt/images/${LLM_VM_NAME}.qcow2"
CLOUDINIT_ISO="/var/lib/libvirt/images/${LLM_VM_NAME}-cloudinit.iso"
LLM_SSH_KEY="$(dirname "$0")/vm_llm"
LLM_SSH_PUB="${LLM_SSH_KEY}.pub"
PLAYBOOK="$(dirname "$0")/playbooks/gnome-desktop.yml"

# Verify prerequisites
for cmd in virt-install virsh xorriso qemu-img virt-cat zip; do
    command -v "$cmd" &>/dev/null || { echo "ERROR: $cmd not found."; exit 1; }
done
[[ -f "$BASE_IMAGE_PATH" ]] || { echo "ERROR: base image not found: $BASE_IMAGE_PATH (run create_base_vm.sh + virt-cloud-builder.sh first)"; exit 1; }
[[ -f "$PLAYBOOK" ]] || { echo "ERROR: playbook not found: $PLAYBOOK"; exit 1; }

set_valid_os_variant

if [[ ! -f "$LLM_SSH_KEY" ]]; then
    echo "==> Generating SSH keypair for the llm user: $LLM_SSH_KEY"
    ssh-keygen -q -N "" -t ed25519 -f "$LLM_SSH_KEY" -C "llm account for $LLM_VM_NAME"
fi

echo "==> Packaging extra_llm_files for the llm user"
EXTRA_LLM_FILES_DIR="$(dirname "$0")/extra_llm_files"
EXTRA_LLM_FILES_B64="$(cd "$EXTRA_LLM_FILES_DIR" && zip -qr - . | base64 -w0)"

echo "==> Packaging Ansible playbook: $PLAYBOOK"
PLAYBOOK_B64="$(base64 -w0 < "$PLAYBOOK")"

echo "==> Copying base image"
echo "    Source: $BASE_IMAGE_PATH"
echo "    Dest  : $DISK_PATH"
sudo qemu-img convert -p -O qcow2 "$BASE_IMAGE_PATH" "$DISK_PATH"

# ── Build the cloud-init NoCloud seed ISO ───────────────────────
CLOUD_INIT_DIR="$(mktemp -d)"
trap 'rm -rf "$CLOUD_INIT_DIR"' EXIT

cat > "$CLOUD_INIT_DIR/meta-data" <<EOF
instance-id: ${LLM_VM_NAME}
local-hostname: ${LLM_VM_NAME}
EOF

cat > "$CLOUD_INIT_DIR/user-data" <<EOF
#cloud-config
users:
  - name: llm
    lock_passwd: true
    shell: /bin/bash
    sudo: false
    ssh_authorized_keys:
      - $(cat "$LLM_SSH_PUB")

write_files:
  # Written to /root: write_files runs before the llm user exists.
  - path: /root/extra_llm_files.zip
    encoding: b64
    permissions: '0600'
    content: ${EXTRA_LLM_FILES_B64}
  - path: /root/gnome-desktop.yml
    encoding: b64
    permissions: '0600'
    content: ${PLAYBOOK_B64}

runcmd:
  # GNOME desktop via Ansible (output also lands in /var/log/cloud-init-output.log)
  - dnf install -y ansible-core python3-libdnf5
  - ansible-playbook -i localhost, -c local /root/gnome-desktop.yml 2>&1 | tee /var/log/ansible-gnome-desktop.log
  - curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip -q awscliv2.zip && ./aws/install --update
  - curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  - cp /root/extra_llm_files.zip /home/llm/extra_llm_files.zip && chown llm:llm /home/llm/extra_llm_files.zip
  - sudo -u llm -i bash -c "unzip -o -q ~/extra_llm_files.zip -d ~ && rm -f ~/extra_llm_files.zip"
  - sudo -u llm -i bash -c "curl -fsSL https://claude.ai/install.sh | bash"
  - sudo -u llm -i bash -c "curl -fsSL https://antigravity.google/cli/install.sh | bash"
  - sudo -u llm -i bash -c "cp ~/.claude/CLAUDE.md ~/.gemini/GEMINI.md"

power_state:
  mode: poweroff
  condition: true
EOF

mkdir -p "$HOME/tmp"
LOCAL_CLOUDINIT_ISO="$HOME/tmp/${LLM_VM_NAME}-cloudinit.iso"

echo "==> Building cloud-init ISO: $LOCAL_CLOUDINIT_ISO"
xorriso -as genisoimage \
    -output "$LOCAL_CLOUDINIT_ISO" \
    -volid cidata \
    -joliet -rock \
    "$CLOUD_INIT_DIR/user-data" "$CLOUD_INIT_DIR/meta-data"

echo "==> Installing cloud-init ISO into place: $CLOUDINIT_ISO"
sudo cp "$LOCAL_CLOUDINIT_ISO" "$CLOUDINIT_ISO"
rm -f "$LOCAL_CLOUDINIT_ISO"

echo "==> Creating VM: $LLM_VM_NAME"
echo "    Disk     : $DISK_PATH"
echo "    Cloudinit: $CLOUDINIT_ISO"
echo "    OS hint  : $OS_VARIANT"

# SPICE + virtio video for the GNOME desktop; serial console kept for debugging.
virt-install \
    --connect      "${LIBVIRT_DEFAULT_URI}" \
    --name         "$LLM_VM_NAME" \
    --vcpus        "$VCPUS" \
    --memory       "$MEM_MB" \
    --os-variant   "$OS_VARIANT" \
    --import \
    --disk         "path=${DISK_PATH},format=qcow2,bus=virtio" \
    --disk         "path=${CLOUDINIT_ISO},device=cdrom" \
    --network      default \
    --graphics     spice \
    --video        virtio \
    --console      "pty,target_type=serial" \
    --noautoconsole

echo
echo "==> Waiting for cloud-init to finish provisioning and '$LLM_VM_NAME' to shut off..."
while true; do
    state=$(virsh domstate "$LLM_VM_NAME" 2>/dev/null || echo "unknown")
    [[ "$state" == "shut off" ]] && break
    echo "    VM state: $state — waiting 10s..."
    sleep 10
done

echo "==> Verifying cloud-init completed successfully..."
CLOUD_INIT_RESULT="$(sudo virt-cat -d "$LLM_VM_NAME" /var/lib/cloud/data/result.json 2>/dev/null || true)"
if [[ -z "$CLOUD_INIT_RESULT" ]]; then
    echo "WARNING: could not read cloud-init result.json; inspect with: sudo virt-cat -d $LLM_VM_NAME /var/log/cloud-init-output.log"
elif grep -qE '"errors":[[:space:]]*\[\]' <<< "$CLOUD_INIT_RESULT"; then
    echo "    cloud-init finished with no errors."
else
    echo "WARNING: cloud-init reported errors: $CLOUD_INIT_RESULT"
    echo "         Inspect with: sudo virt-cat -d $LLM_VM_NAME /var/log/cloud-init-output.log"
fi

echo "==> Ansible result (last lines):"
sudo virt-cat -d "$LLM_VM_NAME" /var/log/ansible-gnome-desktop.log 2>/dev/null | tail -n 5 || \
    echo "WARNING: could not read /var/log/ansible-gnome-desktop.log"

echo "==> eject iso"
virsh change-media "$LLM_VM_NAME" sda --eject --config

echo "==> clean vm to be ready for cloning"
sudo virt-sysprep --domain "$LLM_VM_NAME" --operations defaults,-ssh-userdir
