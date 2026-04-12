#!/usr/bin/bash

# Unpacks an ISO file into a target directory using 7z.

# noclobber - skip unpack if target directory exists

CLOBBER=1
while getopts "n" opt; do
  case $opt in
    n)
      CLOBBER=0
      ;;
    *)
      echo "Usage: $0 [-n] iso_file target_directory"
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))
ISO_FILE="$1"
TARGET_DIR="$2"
if [ -z "$ISO_FILE" ] || [ -z "$TARGET_DIR" ]; then
  echo "Usage: $0 [-n] iso_file target_directory"
  exit 1
fi

if [ ! -f "$ISO_FILE" ]; then
  echo "Error: ISO file '$ISO_FILE' does not exist."
  exit 1
fi
if [ -d "$TARGET_DIR" ] && [ $CLOBBER -eq 0 ]; then
  echo "Target directory '$TARGET_DIR' already exists. Skipping unpack."
  exit 0
fi
mkdir -p "$TARGET_DIR"
echo "Unpacking '$ISO_FILE' to '$TARGET_DIR'..."
# 7z x "$ISO_FILE" -o"$TARGET_DIR"
sudo mkdir ~/mnt
sudo mount -o loop $ISO_FILE ~/mnt
rsync -a ~/mnt/ "$TARGET_DIR"
sudo umount ~/mnt
if [ $? -ne 0 ]; then
  echo "Error: Failed to unpack ISO file."
  exit 1
fi
echo "Unpacking completed successfully."

exit 0