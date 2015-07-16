#!/bin/sh
# FILE: cap-rachel-first-install-2.sh
# ONELINER Download/Install: wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-first-install-2.sh -O - | bash 

# Everything below will go to the file '/var/log/rachel-install.log'
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>>/var/log/rachel-install.log 2>&1

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
echo; print_good "RACHEL CAP Install - Script 2 started at $(date)"

# Delete previous setup commands from the /etc/rc.local
sudo sed -i '/cap-rachel/d' /etc/rc.local

# Create the new filesystems so we can write files to them
echo; print_status "Creating filesystems"
mkfs.ext4 -L "preloaded" -U 77777777-7777-7777-7777-777777777777 /dev/sda1
mkfs.ext4 -L "uploaded" -U 88888888-8888-8888-8888-888888888888 /dev/sda2
mkfs.ext4 -L "RACHEL" -U 99999999-9999-9999-9999-999999999999 /dev/sda3
print_good "Done."

# Add lines to /etc/rc.local that will start the next script to run on reboot
sudo sed -i '$e echo "bash \/root\/cap-rachel-first-install-3.sh&"' /etc/rc.local

# Reboot
echo; print_good "RACHEL CAP Install - Script 2 ended at $(date)"
echo; print_status "I need to reboot; once rebooted, please run the next download/install command."
print_status "Rebooting in 10 seconds..." 
sleep 10
reboot
