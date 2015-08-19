#!/bin/sh

#
# Author : Lu Ken (bluewish.ken.lu@gmail.com)
# 
# Initialize the content disk as following layout:
# - 400G for preload content
# - 100G for teacher content
#

usage() {
    echo "
Usage: `basename $1` content_disk_device_node
"
}

check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root" 1>&2
       exit 1
    fi
}

check_parameter() {
    if [ -z "$1" ]; then 
        usage $0
        echo "please speficy the device node for content disk."
        exit 1
    fi
}

create_disk_image() {

    # GPT header uses 1M size.
    echo "@@ Create GPT parition table ..."
    #sgdisk -og -U 87654321-1111-2222-3333-BA0987654321 $1
    parted -s $1 mklabel gpt

    # Part1: 20G for preloaded content
    echo "@@ Create preloaded content partition."
    #sgdisk -n 1:2048:765460479 -c 1:"preloaded" -u 1:77777777-7777-7777-7777-777777777777 -t 1:8300 $1 # original
    sgdisk -n 1:2048:+20G -c 1:"preloaded" -u 1:77777777-7777-7777-7777-777777777777 -t 1:8300 /dev/sda

    # Part2: 100G for teacher content
    echo "@@ Create teacher partition."
    #sgdisk -n 2:765460480:-1M -c 2:"uploaded" -u 2:88888888-8888-8888-8888-888888888888 -t 2:8300 $1 # original
    sgdisk -n 2:21G:+100G -c 2:"uploaded" -u 2:88888888-8888-8888-8888-888888888888 -t 2:8300 /dev/sda

    # Part3: Remaining for RACHEL content
    echo "@@ Create RACHEL partition."
    sgdisk -n 3:122G:-1M -c 3:"RACHEL" -u 3:99999999-9999-9999-9999-999999999999 -t 3:8300 /dev/sda    

    echo "@@ The partition table is as follows:"
    gdisk -l $1
}

format_disk() {

    # /preloaded
    mkfs.ext4 -L "preloaded" -U 77777777-7777-7777-7777-777777777777 /dev/sda1

    # /uploaded
    mkfs.ext4 -L "uploaded" -U 88888888-8888-8888-8888-888888888888 /dev/sda2

    gdisk -l $1
}

check_root
check_parameter $1
create_disk_image $1
format_disk $1
