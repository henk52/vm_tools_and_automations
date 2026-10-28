#!/usr/bin/env bash

# Create a base VM for LLM development.

# Example: ./create_llm_base_vm.sh llm_fedora ks_fedora_minimal.qcow2

# Uses the VM defined in common_base_vm.sh
#  generates an .iso file with the instructions to install the required tools.
#  Then starts the VM and runs the installation via the cloud-init.

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
    # Looks like a path (absolute, "~/...", or relative) rather than a bare image name.
    BASE_IMAGE_PATH="${SOURCE_QCOW_FILE/#\~/$HOME}"
elif [[ "$SOURCE_QCOW_FILE" == *.qcow2 ]]; then
    BASE_IMAGE_PATH="$HOME/tmp/${SOURCE_QCOW_FILE}"   # produced by virt-cloud-builder.sh
else
    BASE_IMAGE_PATH="$HOME/tmp/${SOURCE_QCOW_FILE}.qcow2"   # produced by virt-cloud-builder.sh
fi

# ── Adjust these variables ──────────────────────────────────────
LLM_VM_NAME="${NEW_VM_NAME}"
VCPUS=2
MEM_MB=8192
DISK_PATH="/var/lib/libvirt/images/${LLM_VM_NAME}.qcow2"
CLOUDINIT_ISO="/var/lib/libvirt/images/${LLM_VM_NAME}-cloudinit.iso"
LLM_SSH_KEY="$(dirname "$0")/vm_llm"
LLM_SSH_PUB="${LLM_SSH_KEY}.pub"



# Verify prerequisites
for cmd in virt-install virsh xorriso qemu-img virt-cat zip; do
    command -v "$cmd" &>/dev/null || { echo "ERROR: $cmd not found."; exit 1; }
done
[[ -f "$BASE_IMAGE_PATH" ]] || { echo "ERROR: base image not found: $BASE_IMAGE_PATH (run create_base_vm.sh + virt-cloud-builder.sh first)"; exit 1; }

set_valid_os_variant

# Generate a dedicated keypair for the unprivileged "llm" user, if missing.
if [[ ! -f "$LLM_SSH_KEY" ]]; then
    echo "==> Generating SSH keypair for the llm user: $LLM_SSH_KEY"
    ssh-keygen -q -N "" -t ed25519 -f "$LLM_SSH_KEY" -C "llm account for $LLM_VM_NAME"
fi

echo "==> Packaging extra_llm_files for the llm user"
EXTRA_LLM_FILES_DIR="$(dirname "$0")/extra_llm_files"
EXTRA_LLM_FILES_B64="$(cd "$EXTRA_LLM_FILES_DIR" && zip -qr - . | base64 -w0)"

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
  # Written to /root, not /home/llm: the write-files module runs before the
  # users-groups module creates the "llm" user, so /home/llm doesn't exist
  # yet and "owner: llm:llm" here would fail with "Unknown user or group".
  - path: /root/extra_llm_files.zip
    encoding: b64
    permissions: '0600'
    content: ${EXTRA_LLM_FILES_B64}

# Install the Claude Code CLI as the unprivileged llm user.
runcmd:
  - curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip -q awscliv2.zip && ./aws/install --update
  - curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  - cp /root/extra_llm_files.zip /home/llm/extra_llm_files.zip && chown llm:llm /home/llm/extra_llm_files.zip
  - sudo -u llm -i bash -c "unzip -o -q ~/extra_llm_files.zip -d ~ && rm -f ~/extra_llm_files.zip"
  - sudo -u llm -i bash -c "curl -fsSL https://claude.ai/install.sh | bash"
  - sudo -u llm -i bash -c "curl -fsSL https://antigravity.google/cli/install.sh | bash"
  - sudo -u llm -i bash -c "cp ~/.claude/CLAUDE.md ~/.gemini/GEMINI.md"

# Shut down once provisioning is done. The VM gets transferred to another
# system after this, and this lets the build script detect completion the
# same way create_base_vm.sh does for the kickstart install: by polling for
# "shut off" instead of racing to SSH in before cloud-init has finished.
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
    --graphics     none \
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

# Read cloud-init's final status straight off the disk (no boot needed) to
# confirm provisioning actually succeeded, not just that it ran to completion.
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

echo "==> eject iso"
virsh change-media $LLM_VM_NAME sda --eject --config

echo "==> clean vm to be ready for cloning"
sudo virt-sysprep --domain "$LLM_VM_NAME" --operations defaults,-ssh-userdir

