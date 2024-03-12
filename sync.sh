#!/bin/bash
# Sync files and directories with a NFS or a local path
# Usage: sync.sh [-u] [-d] [-c] [-t TARGET (default: nfs)]
# Note: -u flag for upload, -d flag for download, -c flag for clean the target
# Note: -t flag to specify the target, default is nfs

# Debug mode (uncomment to enable)
# set -ux

set -eo pipefail

UPLOAD=false
DOWNLOAD=false
CLEAN=false
TARGET="nfs"

# Parse options
if [ $# -eq 0 ]; then
  echo "Choose an option: u (upload), d (download), c (clean)"
  read -p "Option: " opt
  case $opt in
    u) UPLOAD=true ;;
    d) DOWNLOAD=true ;;
    c) CLEAN=true ;;
    *) echo "Invalid option: $opt" >&2; exit 1 ;;
  esac
else
 while getopts "udct:" opt; do
   case $opt in
      u) UPLOAD=true ;;
      d) DOWNLOAD=true ;;
      c) CLEAN=true ;;
      t) TARGET=$OPTARG ;;
     \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
     :) echo "Option -$OPTARG requires an argument" >&2; exit 1 ;;
   esac
 done
fi

if [ "$UPLOAD" == true ] && [ "$DOWNLOAD" == true ]; then
  echo "Choose only one option: -u (upload), -d (download)" >&2
  exit 1
fi

if [ "$UPLOAD" == false ] && [ "$DOWNLOAD" == false ] && [ "$CLEAN" == false ]; then
  echo "Choose an option: -u (upload), -d (download), -c (clean)" >&2
  exit 1
fi

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Load settings from config file
config_file="$script_dir/.config"
declare -A CONFIG
while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" =~ ^[^#]*= ]]; then
    line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    key=$(echo "$line" | cut -d '=' -f 1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    value=$(echo "$line" | cut -d '=' -f 2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    CONFIG["$key"]="$value"
  fi
done < "$config_file"
LOCAL_PATH_BASE=${CONFIG["local_path_base"]}
NFS_TARGET_IP=${CONFIG["nfs_target_ip"]:-""}

# Load items from items files
items_file="$script_dir/items.txt"
declare -a ITEMS
items_file_content=$(tr '\n' ' ' < $items_file)
IFS=$' \t' read -r -a ITEMS <<< "$items_file_content"

if [ "$TARGET" == "nfs" ]; then
  mount_point="/mnt/$(openssl rand -hex 2)"
  sudo mkdir -p $mount_point
  sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 $NFS_TARGET_IP:/ $mount_point
elif [[ $TARGET == /* ]]; then
  mount_point="${TARGET%/}"
else
  echo "Invalid target: $TARGET" >&2
  exit 1
fi

if [ "$UPLOAD" == true ]; then
  for item in "${ITEMS[@]}"; do
    if [ ! -e "$LOCAL_PATH_BASE/$item" ]; then
      echo "File or directory not found: $LOCAL_PATH_BASE/$item" >&2
    else
      read -p "Sync $LOCAL_PATH_BASE/$item to $mount_point? [y/N] " confirm
      if [[ $confirm =~ ^[Yy]$ ]]; then
        sudo rsync -avR --delete --progress $LOCAL_PATH_BASE/./$item $mount_point
      fi
    fi
  done
fi

if [ "$DOWNLOAD" == true ]; then
  for item in "${ITEMS[@]}"; do
    if [ ! -e "$mount_point/$item" ]; then
      echo "File or directory not found: $mount_point/$item" >&2
    else
      read -p "Sync $mount_point/$item to $LOCAL_PATH_BASE? [y/N] " confirm
      if [[ $confirm =~ ^[Yy]$ ]]; then
        rsync -avR --delete --progress $mount_point/./$item $LOCAL_PATH_BASE
      fi
    fi
  done
fi

if [ "$CLEAN" == true ]; then
  read -p "Clean $mount_point? [y/N] " confirm
  if [[ $confirm =~ ^[Yy]$ ]]; then
    shopt -s dotglob
    sudo rm -rf $mount_point/*
    shopt -u dotglob
  fi
fi

if [ "$TARGET" == "nfs" ]; then
  while ! sudo umount $mount_point 2> /dev/null; do sleep 1; done
  sudo rmdir $mount_point
fi