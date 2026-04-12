#!/usr/bin/bash

# creates an autoinstall dir in the TARGET_DIR and copies user-data and meta-data files into it

user_data_file="$1"
target_dir="$2"
if [ -z "$user_data_file" ] || [ -z "$target_dir" ]; then
  echo "Usage: $0 user_data_file target_directory"
  exit 1
fi
if [ ! -f "$user_data_file" ]; then
  echo "Error: user_data_file '$user_data_file' does not exist."
  exit 1
fi
if [ ! -d "$target_dir" ]; then
  echo "Error: target_directory '$target_dir' does not exist."
  exit 1
fi
autoinstall_dir="$target_dir/autoinstall"
mkdir -p "$autoinstall_dir"
cp "$user_data_file" "$autoinstall_dir/user-data"
if [ $? -ne 0 ]; then
  echo "Error: Failed to copy user-data file."
  exit 1
fi

echo "Copied user-data file to '$autoinstall_dir/user-data'."