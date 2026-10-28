# Fedora VM

- sudo ./create_base_vm.sh
  - ./destroy_base_vm.sh
- ./virt_cloud_builder.sh ks_fedora_minimal base_fedora_minimal
- ./create_llm_base_vm.sh llm_fedora base_fedora_minimal.qcow2
  - ./destroy_base_vm.sh llm_fedora
- ./clone_llm_base_vm.sh llm_vm llm_fedora
- ./run_vm.sh llm_vm
- ./connect_llm.sh
  - ssh -i vm_llm -o IdentitiesOnly=yes llm@192.168.122.73
- ./sync_to_vm.sh extra_llm_files 192.168.122.73 test

- ./virt_cloud_builder.sh llm_fedora llm_fedora_base
- ./create_dev_gui_vm.sh dev_gui llm_fedora_base.qcow2
- ./clone_llm_base_vm.sh gui_vm dev_gui
- ./run_vm.sh gui_vm
- virsh -c qemu:///system domifaddr gui_vm

- virsh -c qemu:///system list --all
- virsh -c qemu:///system vol-list default

## Temporary design

- Be able to run a Minimal gnome environment
- access via ssh -x
- access via Remmina

### Gnome VM
- Add graphics support to the VM
- How to autoinstall the playbook on a new vm, cloud-init?
- zsh

### Security

#### Remina security

Mitigations

- Disable clipboard, shared folders, printer, audio and USB redirection.
- Keep Remmina and FreeRDP updated.
- Run Remmina as a Flatpak or under a separate user to limit damage.
- For a local VM, prefer the hypervisor’s own console (e.g. virt-manager/SPICE) with sharing features off.
- Don’t save credentials, and use network isolation for the VM.


- ssh -i vm_devops -o IdentitiesOnly=yes devops@192.168.122.155
- sudo dnf -y install ansible

## Troubleshooting



This is the Live ISO problem I mentioned. --location needs an install tree with images/pxeboot/vmlinuz and initrd.img, and Live ISOs don’t have one, so virt-install can’t boot the installer or inject your kickstart.

```text
❯ sudo ./create_base_vm.sh
==> Creating VM: ks_fedora_minimal
    ISO      : /var/lib/libvirt/images/Fedora-KDE-Desktop-Live-43-1.6.x86_64.iso
    Kickstart: ./ks.cfg
    Disk     : /var/lib/libvirt/images/ks_fedora_minimal.qcow2 (20 GB)
    OS hint  : fedora41

    ETA 9-12 minutes for installation, then the VM will shut off automatically.

Starting install...
ERROR    Couldn't find kernel for install tree.
Domain installation does not appear to have been successful.
If it was, you can restart your domain by running:
  virsh --connect qemu:///system start ks_fedora_minimal
otherwise, please restart your installation.
```



