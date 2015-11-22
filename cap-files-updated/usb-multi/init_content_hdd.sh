#!/bin/bash
#
# Original Author : Lu Ken (bluewish.ken.lu@****l.com)
# Modified by : Sam @ Hackers for Charity (hackersforcharity.org) and World Possible (worldpossible.org)
#
# Initialize the content disk as following layout:
# - 20G for preload content
# - 100G for teacher content
# - 339G for RACHEL content
#

SCRIPT_ROOT="/boot/efi"

usage () {
    echo "Usage: `basename $1 $2` content_disk_device_node format_option"
}

check_root () {
    if [[ "$(id -u)" != "0" ]]; then
        echo "[!] This script must be run as root."
        exit 1
    else
        echo "[+] Yeah...you are root, continuing."
    fi
}

check_parameter () {
    if [[ -z $1 ]]; then 
        usage $0
        echo; echo "[!] Please specify the device node for content disk."
        exit 1
    else
        echo "[+] Parameter 1 passed:  $1"
    fi
    if [[ -z $2 ]]; then
        usage $0
        echo; echo "[!] Please specify the format option (0=No, 1=Yes)."
        exit 1
    else
        echo "[+] Parameter 2 passed:  $2"
    fi
}

create_disk_image () {
    echo; echo "[*] Starting function: create_disk_image."

    # GPT header uses 1M size.
    echo; echo "[*] Create GPT parition table."
    #sgdisk -og -U 87654321-1111-2222-3333-BA0987654321 $1
    parted -s $1 mklabel gpt
    echo "[+] Done."

    # Part1: 20G for preloaded content
    echo; echo "[*] Create preloaded content partition."
    #sgdisk -n 1:2048:765460479 -c 1:"preloaded" -u 1:77777777-7777-7777-7777-777777777777 -t 1:8300 $1 # original
    sgdisk -n 1:2048:+20G -c 1:"preloaded" -u 1:77777777-7777-7777-7777-777777777777 -t 1:8300 $1
    echo "[+] Done."

    # Part2: 100G for teacher content
    echo; echo "[*] Create teacher partition."
    #sgdisk -n 2:765460480:-1M -c 2:"uploaded" -u 2:88888888-8888-8888-8888-888888888888 -t 2:8300 $1 # original
    sgdisk -n 2:21G:+100G -c 2:"uploaded" -u 2:88888888-8888-8888-8888-888888888888 -t 2:8300 $1
    echo "[+] Done."

    # Part3: Remaining for RACHEL content
    echo; echo "[*] Create RACHEL partition."
    sgdisk -n 3:122G:-1M -c 3:"RACHEL" -u 3:99999999-9999-9999-9999-999999999999 -t 3:8300 $1   
    echo "[+] Done."

    echo; echo "[*] The partition table is as follows:"
    gdisk -l $1

}

format_disk () {
    if [[ $2 == "1" ]]; then
        echo; echo "[*] Running function format_disk"

        # /preloaded
        echo; echo "[*] Formatting 'preloaded' partition."
        mkfs.ext4 -L "preloaded" -U 77777777-7777-7777-7777-777777777777 /dev/sda1 &> /dev/null
        echo "[+] Done."

        # /uploaded
        echo; echo "[*] Formatting 'uploaded' partition."
        mkfs.ext4 -L "uploaded" -U 88888888-8888-8888-8888-888888888888 /dev/sda2 &> /dev/null
        echo "[+] Done."

        # /RACHEL
        echo; echo "[*] Formatting 'RACHEL' partition."
        mkfs.ext4 -L "RACHEL" -U 99999999-9999-9999-9999-999999999999 /dev/sda3  &> /dev/null  
        echo "[+] Done."

        echo; echo "[+] Formatting complete"

        echo; echo "[*] The partition table after format is as follows:"
        gdisk -l $1
    else
        echo "[-] INFO:  The function format_disk did not run!"
    fi
}

echo; echo "[*] Checking for root permissions."
check_root
echo; echo "[*] Checking for parameter 1 [$1] and 2 [$2]."
check_parameter $1 $2
echo; echo "[*] Running create_disk_image function."
create_disk_image $1
echo; echo "[*] Running format_disk function."
format_disk $1 $2 # This option will not run during Method 2 (Imaging); it only runs if parameter 2 is set to "1" during Method 3
exit
