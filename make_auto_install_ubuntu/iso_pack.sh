#!/usr/bin/bash

# pack the SOURCE_DIR into an ISO file using mkisofs.

SOURCE_DIR="$1"
ISO_FILE="$2"
if [ -z "$SOURCE_DIR" ] || [ -z "$ISO_FILE" ]; then
  echo "Usage: $0 source_directory iso_file"
  exit 1
fi
if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: source_directory '$SOURCE_DIR' does not exist."
  exit 1
fi
echo "Packing '$SOURCE_DIR' into ISO file '$ISO_FILE'..."

xorriso -as mkisofs \
  -r -V "UBUNTU-22.04-CUSTOM" \
  -J -joliet-long -l \
  -iso-level 3 \
  -b boot/grub/i386-pc/eltorito.img \
     -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot \
  -isohybrid-gpt-basdat \
  -o "$ISO_FILE" "$SOURCE_DIR"
if [ $? -ne 0 ]; then
  echo "Error: Failed to create ISO file."
  exit 1
fi
echo "ISO file '$ISO_FILE' created successfully."