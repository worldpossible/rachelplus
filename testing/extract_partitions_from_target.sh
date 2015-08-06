#!/bin/bash

#
# This script will abstract boot, rootfs from disk image files.
# and create tar package for boot, rootfs.
#
# @author: Lu, Ken(ken.lu@intel.com)
#

usage() {
    echo "
Usage: `basename $1` [dir_for_partition_images]
"
}

check_parameter() {
    if [ -z "$1" ]; then
        usage $0
        echo "please specify directory for saving partition images."
        exit 1
    fi
}

check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root" 1>&2
        exit 1
    fi
}

tar_param=" --checkpoint=.1000 --totals --exclude-backups --exclude-caches-all --numeric-owner "
tar_excludes=" --exclude=lost+found --exclude=media/* --exclude=mnt/* --exclude=recovery/* --exclude=sys/* --exclude=proc/* --exclude=run/* --exclude=tmp/* "

#
# @param $1 - target folder
# @param $2 - compressed file name
# @param $3 - addtional directories like ./dev.
#
# Note: since using --one-file-system, the ./dev maybe missed when backup, 
#       so need add "./dev" in $3.
#
extract_partition() {
    tar cpJf $2 -C $1 . $3 $tar_param $tar_excludes
    sync
    sleep 2
}

check_root
check_parameter $1

curr_dir="$(pwd)"

if [ ! -z "$1" ];
then
    partition_dir="$(readlink -f $1)/$(date +%Y-%m-%d-%H-%M)"
else
    partition_dir="$(curr_dir)/$(date +%Y-%m-%d-%H-%M)"
fi

mkdir -p $partition_dir
cd $partition_dir

# abstract EFI boot partition for EFI boot
echo "Abstract EFI system partition"
extract_partition /boot/efi efi.tar.xz

# abstract Linux boot partition
echo "Abstract Linux boot partition"
extract_partition /boot boot.tar.xz

# abstract Linux rootfs partition
echo "Abstract Linux rootfs partition"
extract_partition / rootfs.tar.xz --exclude=boot

# abstract RACHEL partition
echo "Abstract RACHEL partition"
extract_partition /media/RACHEL/rachel rachel.tar.xz

echo "Successfully abstracted partition images to $partition_dir"

