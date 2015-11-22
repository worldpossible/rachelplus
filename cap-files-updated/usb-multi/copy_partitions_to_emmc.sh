#!/bin/bash

#
# This script will abstract boot, rootfs from disk image files.
# and create tar package for boot, rootfs.
#
# Author : Lu Ken (ken.lu@intel.com)
#

curr_dir="$(pwd)"
partition_dir=$curr_dir
SCRIPT_ROOT="/boot/efi"

usage () {
    echo; echo "Usage: `basename $1` [dir_for_partition_images]"
}

check_parameter () {
    if [[ -z "$1" ]]; then 
        usage $0
        echo; echo "Please specify the directory for partition image files."
        exit 1
    fi
}

check_root () {
    if [[ "$(id -u)" != "0" ]]; then
        echo; echo "[!] This script must be run as root."
        exit 1
    fi  
}

#
# @param $1     the root directory of image file
# @param $2     the partition image file name
#
check_image () {
    # check efi.tar.xz
    if [[ ! -f $1/$2 ]]; then
        echo; echo "[!] Can not find $2 in $1."
        exit 1
    fi
}

tar_param=" --checkpoint=.1000 --totals --exclude-backups --exclude-caches-all --numeric-owner "
tar_excludes=" --exclude=lost+found --exclude=media/* --exclude=mnt/* --exclude=recovery/* --exclude=sys/* --exclude=proc/* --exclude=run/* --exclude=tmp/* "

#
# @param $1 - partition node
# @param $2 - compressed file name
#
copy_image () {
    mkdir -p /tmp/$$
    mount $1 /tmp/$$
    tar xmJf $2 -C /tmp/$$ . $tar_param $tar_excludes
    sync
    sleep 2
    umount $1
    sleep 2
    rm /tmp/$$ -fr
}

copy_rootfs () {
    mkdir -p /tmp/$$
    mount $1 /tmp/$$
    tar xmJf $2 -C /tmp/$$ . $tar_param $tar_excludes
    sync
    ln -s /media/preloaded /tmp/$$/srv/media/preloaded
    ln -s /media/uploaded /tmp/$$/srv/media/uploaded
    sleep 2
    umount $1
    sleep 2
    rm /tmp/$$ -fr
}

# Main program
echo; echo "[*] Copying original rootfs partitions to eMMC."

check_root
check_parameter $1

if [[ ! -z "$1" ]]; then
    partition_dir=$(readlink -f $1)
fi

cd $partition_dir

echo; echo "[*] Search partition image from dir $partition_dir"
check_image $partition_dir efi.tar.xz
check_image $partition_dir boot.tar.xz
check_image $partition_dir rootfs.tar.xz
echo "[+] Done."

# copy EFI boot partition for EFI boot
echo; echo "[*] Copy EFI System Partition."
copy_image /dev/mmcblk0p2 efi.tar.xz
echo "[+] Done."

# copy Linux boot partition 
echo; echo "[*] Copy Linux boot partition."
copy_image /dev/mmcblk0p3 boot.tar.xz
echo "[+] Done."

# copy Linux rootfs partition
echo; echo "[*] Copy rootfs partition."
mkfs.ext4 -L "ec_root" -U 44444444-4444-4444-4444-444444444444 /dev/mmcblk0p4
copy_rootfs /dev/mmcblk0p4 rootfs.tar.xz
echo "[+] Done."

exit

