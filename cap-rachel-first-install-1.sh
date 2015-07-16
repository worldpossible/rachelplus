#!/bin/sh
# FILE: cap-rachel-first-install-1.sh
# ONELINER Download/Install: sudo wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-first-install-1.sh -O - | bash 

# Everything below will go to this log directory
RACHELLOGDIR="var/log/RACHEL"
RACHELLOGFILE="rachel-install.tmp"
RACHELLOG="$RACHELLOGDIR/$RACHELLOGFILE"

exec 1>> $RACHELLOG 2>&1

function print_good () {
    echo -e "\x1B[01;32m[+]\x1B[0m $1"
}

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

# Add header/date/time to install log file
echo; print_good "RACHEL CAP Install - Script 1 started at $(date)"

# Delete previous setup commands from the /etc/rc.local
sudo sed -i '/cap-rachel/d' /etc/rc.local

# Update CAP package repositories
echo; print_status "Updating CAP package repositories"
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 16126D3A3E5C1192
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 40976EAF437D05B5
apt-get update
print_good "Done."

# Repartition external 500GB hard drive into 3 partitions
echo; print_status "Repartitioning hard drive"
sgdisk -p /dev/sda
sgdisk -o /dev/sda
parted -s /dev/sda mklabel gpt
sgdisk -n 1:2048:+20G -c 1:"preloaded" -u 1:77777777-7777-7777-7777-777777777777 -t 1:8300 /dev/sda
sgdisk -n 2:21G:+100G -c 2:"uploaded" -u 2:88888888-8888-8888-8888-888888888888 -t 2:8300 /dev/sda
sgdisk -n 3:122G:-1M -c 3:"RACHEL" -u 3:99999999-9999-9999-9999-999999999999 -t 3:8300 /dev/sda
sgdisk -p /dev/sda
print_good "Done."

# Add the new RACHEL partition /dev/sda3 to mount on boot
echo; print_status "Adding /dev/sda3 into /etc/fstab"
echo -e "/dev/sda3\t/media/RACHEL\t\text4\tauto,nobootwait 0\t0" >> /etc/fstab
print_good "Done."

# Add lines to /etc/rc.local that will start the next script to run on reboot
sudo sed -i '$e echo "bash \/root\/cap-rachel-first-install-2.sh&"' /etc/rc.local

echo; print_good "RACHEL CAP Install - Script 1 ended at $(date)"
echo; print_status "I need to reboot; once rebooted, the next script will run automatically."
print_status "Rebooting in 10 seconds..." 
sleep 10
reboot
