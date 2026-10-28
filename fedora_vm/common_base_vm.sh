# Shared variables for the base VM scripts.


# Add iso to known kvm ISOs
# sudo cp ~/Downloads/Fedora-Server-dvd-x86_64-44-1.7.iso /var/lib/libvirt/images/
# sudo virsh pool-refresh default
# virsh -c qemu:///system vol-list default
ISO="/var/lib/libvirt/images/Fedora-Server-dvd-x86_64-44-1.7.iso"

# Resolve the correct --os-variant for CentOS Stream 10.
# Try the exact name first; fall back to centos-stream9 if osinfo-db is older.
# osinfo-query os | grep -i fedora
OS_VARIANT="fedora43"

VM_NAME="ks_fedora_minimal"

function set_valid_os_variant() {
    if ! osinfo-query os short-id="$OS_VARIANT" &>/dev/null 2>&1; then
        FALLBACK_OS_VARIANT="fedora-unknown"
        echo "WARNING: osinfo-db does not know '$OS_VARIANT'; falling back to ${FALLBACK_OS_VARIANT}"
        echo "         Run: sudo osinfo-db-import --local \$(osinfo-db-tools --version) to update."
        OS_VARIANT="${FALLBACK_OS_VARIANT}"
    fi
}