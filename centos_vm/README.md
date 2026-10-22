# AI VM

## Introduction

### Purpose

Autogenerate VMs to be used for LLM VMs

### Vocabulary

- AI - Artificial Intelligence.
- AIOS - AI OS - Agentic OS.
- LLM - Large Language Model.
- LLMos - LLM OS - an architectural design in which the language model acts as the central reasoning engine that orchestrates multiple tasks, tools, and agents.
  - The analogy with traditional computing is surprisingly intuitive:
    - CPU - Large Language Model (LLM)
    - Bytes - Tokens
    - RAM - Context Window
- OS - Operating System.

### References

- [A Step-by-Step Guide for Developing Your Personal Agentic System](https://medium.com/data-science-collective/a-step-by-step-guide-for-developing-your-personal-agentic-system-24c6cd6fa849)
- [AI CODING AGENTS ARE BLIND TO YOUR COMPANY KNOWLEDGE](https://devopstoolkit.live/ai/ai-coding-agents-are-blind-to-your-company-knowledge-heres-the-fix/)
- [I BUILT CUSTOM AI AGENTS FOR MY TEAM](https://devopstoolkit.live/ai/i-built-custom-ai-agents-for-my-team-heres-the-complete-blueprint/)

### Prompts

please provide the scripts for handsoff create and install a minimal installation of centos10, with sshd installed, in a kvm guest vm
install media is: CentOS-Stream-10-latest-x86_64-dvd1.iso

- Please add the creation of the a user named devops to the ks.cfg, the user must be able to sudo, it must be able to ssh into the vm using the ssh key vm_devops.pub

### TODO

- write how to start a new vm using terraform
- Generate AIOS Agentic OS
- How to handle when a AI VM disappears?
- Should each task run it its own VM?
  - or should each task be run in its own container?
- how to handle if agents are using uniques services like a single VPC for handeling kubespray update.
- could the agent be coded in a lambda? would that be useful?
- how to switch models, how to switch to AWS bedrock?

[sso-session my-sso]
sso_start_url = https://my-sso-portal.awsapps.com/start
sso_region = us-east-1
sso_registration_scopes = sso:account:access

[profile dev]
sso_session = my-sso
sso_account_id = 111122223333
sso_role_name = DeveloperRole
region = us-east-1
output = json

[profile prod]
sso_session = my-sso
sso_account_id = 444455556666
sso_role_name = ReadOnlyRole
region = us-east-1


## VM creation

### Creating a VM for LLMs

- ./destroy_base_vm.sh
- ./create_base_vm.sh
- ./virt_cloud_builder.sh ks_centos_minimal base_centos_minimal
- ./create_llm_base_vm.sh base_llm_vm base_centos_minimal
- ./clone_llm_base_vm.sh llm_vm base_llm_vm
- ./run_vm.sh llm_vm
- ./connect_llm.sh
  - ssh -i vm_llm -o IdentitiesOnly=yes llm@192.168.122.73
- ./sync_to_vm.sh extra_llm_files 192.168.122.73 test

#### Allow a VM to r/w s subdir in the host

- sudo virt-xml llm_vm --edit --memorybacking access.mode=shared,source.type=memfd
- sudo virt-xml llm_vm --add-device --filesystem type=mount,accessmode=passthrough,driver.type=virtiofs,source.dir=/home/$USER/workspace,target.dir=workspace



- ssh -i vm_devops -o IdentitiesOnly=yes devops@192.168.122.216
- Inside the vm
  - su -
  - mkdir -p /mnt/workspace
  - mount -t virtiofs workspace /mnt/workspace
  - /etc/fstab
    - workspace  /mnt/workspace  virtiofs  defaults  0 0

### Create the original VM

- export ORG_IMAGE_NAME="ks_centos10_minimal"
- bash ./create_vm_sh.sh
- virsh -c qemu:///system list --all
- export LIBVIRT_DEFAULT_URI="qemu:///system"
- virsh destroy ${ORG_IMAGE_NAME}
- virsh undefine ${ORG_IMAGE_NAME} --remove-all-storage

- virsh -c qemu:///system destroy ${ORG_IMAGE_NAME}
- virsh domblklist ${ORG_IMAGE_NAME}


- ssh-keygen -q -N "" -t ed25519 -f vm_devops -C "vm-devops-test"

- ssh -i vm_devops -o IdentitiesOnly=yes devops@192.168.122.139
- sudo -i
- dnf -y update

- https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/installation_guide/sect-kickstart-syntax

### Create the base image

- export ORG_IMAGE_NAME="ks_centos10_minimal"
- ./virt_cloud_builder.sh ${ORG_IMAGE_NAME} base_centos10_minimal
  - puts the clean .qcow2 file in the ~/tmp dir

Manually copying .qcow2 files around: sudo qemu-img convert -p -O qcow2 /var/lib/libvirt/images/${ORG_IMAGE_NAME}.qcow2 ~/tmp/${ORG_IMAGE_NAME}.qcow2

#### Base image requirements

- rsync - to enable rsync data between host and guest, both have to have rsync installed.

#### error: failed to get domain 'ks_centos10-minimal'

### Create the LLM VM

- sudo ./create_llm_base_vm.sh
- Copies the cleaned base image, builds a cloud-init NoCloud ISO, and boots a new
  VM (`${VM_NAME}-llm`) from it.
- The ISO provisions an unprivileged `llm` user (no sudo) with SSH access, and
  installs the Claude Code CLI for that user on first boot.
- Generates a dedicated `vm_llm` / `vm_llm.pub` keypair on first run.
- ssh -i vm_llm -o IdentitiesOnly=yes llm@<ip>

### Access as llm

- ssh -i vm_devops -o IdentitiesOnly=yes llm@192.168.122.125
- aws sso login --profile pre-production
- claude


aws configure sso  --use-device-code
get informationfrom credentials info for the account


## Troubleshooting

```text
That confirms it: your plain virsh is on qemu:///session, sudo virsh is on qemu:///system — two independent libvirt instances with separate VM inventories.

To make plain virsh always target the system instance (common for scripts/automation), export:


export LIBVIRT_DEFAULT_URI=qemu:///system
or add uri_default = "qemu:///system" to ~/.config/libvirt/libvirt.conf. Since I see create_vm.sh is open, do you want me to check which URI that script assumes, so it matches what you see with sudo virsh list?
```
