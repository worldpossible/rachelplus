#!/bin/sh
# cap-rachel-first-install-1.sh

function print_error () {
    echo -e "\x1B[01;31m[-]\x1B[0m $1"
}

function print_status () {
    echo -e "\x1B[01;34m[*]\x1B[0m $1"
}

# Check root
if [ "$(id -u)" != "0" ]; then
  print_error "This step must be run as root; sudo password is 123lkj"
  exit 1
fi

print_status "[+] Updating CAP package repositories"
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 16126D3A3E5C1192
apt-get update

print_status "[+] Repartitioning hard drive"
sgdisk -p /dev/sda
sgdisk -o /dev/sda
parted -s /dev/sda mklabel gpt
sgdisk -n 1:2048:+20G -c 1:"preloaded" -u 1:77777777-7777-7777-7777-777777777777 -t 1:8300 /dev/sda
sgdisk -n 2:21G:+100G -c 2:"uploaded" -u 2:88888888-8888-8888-8888-888888888888 -t 2:8300 /dev/sda
sgdisk -n 3:122G:-1M -c 3:"RACHEL" -u 3:99999999-9999-9999-9999-999999999999 -t 3:8300 /dev/sda
sgdisk -p /dev/sda

print_status "[+] Adding /dev/sda3 into /etc/fstab"
echo -e "/dev/sda3\t/media/RACHEL\t\text4\tauto,nobootwait 0\t0" >> /etc/fstab

print_status "[+] I need to reboot; once rebooted, please run cap-rachel-first-install-2.sh"
read -rsp $'Press any key to reboot...\n' -n1 key
reboot
