# Make autoinstall Ubuntu image

## Introduction

### Purpose

Describe how to create an Autoinstallation ISO for Ubuntu.

### References

* [How to optimize installation process during offline autoinstall Ubuntu 22.04?](https://askubuntu.com/questions/1490821/how-to-optimize-installation-process-during-offline-autoinstall-ubuntu-22-04)
* [ubuntu-autoinstall-generator](https://github.com/covertsh/ubuntu-autoinstall-generator)
* [autoinstall-desktop](https://github.com/canonical/autoinstall-desktop)
* []()

Process

- iso_unpack.sh
- iso_modify.sh
- iso_pack.sh

e.g.

- ./iso_unpack.sh ~/Downloads/ubuntu-22.04.5-desktop-amd64.iso ~/tmp/ubuntu.iso.dir
- ./iso_modify.sh user-data.yaml ~/tmp/ubuntu.iso.dir
- ./iso_pack.sh ~/tmp/ubuntu.iso.dir ~/tmp/ubunut-22.04-desktop-modified.iso



  xorriso -as mkisofs \
  -r -V "UBUNTU-CUSTOM" \
  -J -l -cache-inodes \
  -iso-level 3 \
  -b boot/grub/i386-pc/eltorito.img \
     -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot \
  -e boot/grub/efi.img \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  -o ~/tmp/ubuntu-22.04-desktop-modified.iso .




- mount | grep Ubunt
- sudo mount -o remount,rw /dev/sdf1

#### Investigate a qcow2


- sudo mkdir -p /mnt/qcow2
- sudo guestmount -a ~/tmp/disk.qcow2 -i --ro /mnt/qcow2
- ls /mnt/qcow2
- # When done:
  - sudo guestunmount /mnt/qcow2
