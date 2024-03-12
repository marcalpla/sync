# Sync

File and directory synchronization with a NFS or a local path. It supports upload, download, and clean-up of the target NFS or local path.

## Requirements

- rsync
- nfs-common

## Compatibility

Tested on Ubuntu 22.04 LTS. It might work on other Linux distributions.

## Usage

```bash
sync.sh [-u] [-d] [-c] [-t TARGET (default: nfs)]
```

Parameters:

* `-u`: Upload files from the local path to the target NFS or another local path.
* `-d`: Download files to the local path from the target NFS or another local path.
* `-c`: Clean-up the target.
* `-t TARGET`: The target NFS or local path. Default is NFS.

## Configuration

* The script requires a .config file with key-value pairs for the base local path and the NFS target IP address.
* An items.txt file is needed to indicate the relative paths of the files and directories from the base local path to be synchronized.