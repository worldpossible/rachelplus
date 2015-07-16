#!/bin/sh
# FILE: cap-rachel-first-install-2.sh
# ONELINER Download/Install: wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-first-install-2.sh -O - | bash 

# Everything below will go to this log directory
RACHELLOGDIR="/var/log/RACHEL"
RACHELLOGFILE="rachel-install.tmp"
RACHELLOG="$RACHELLOGDIR/$RACHELLOGFILE"

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
echo; print_good "RACHEL CAP Install - Script 2 started at $(date)" | tee -a $RACHELLOG

# Delete previous setup commands from the /etc/rc.local
sudo sed -i '/cap-rachel/d' /etc/rc.local >> $RACHELLOG 2>&1

# Create the new filesystems so we can write files to them
echo; print_status "Creating filesystems" | tee -a $RACHELLOG
mkfs.ext4 -L "preloaded" -U 77777777-7777-7777-7777-777777777777 /dev/sda1 >> $RACHELLOG 2>&1
mkfs.ext4 -L "uploaded" -U 88888888-8888-8888-8888-888888888888 /dev/sda2 >> $RACHELLOG 2>&1
mkfs.ext4 -L "RACHEL" -U 99999999-9999-9999-9999-999999999999 /dev/sda3 >> $RACHELLOG 2>&1
print_good "Done." | tee -a $RACHELLOG

# Add lines to /etc/rc.local that will start the next script to run on reboot
sudo sed -i '$e echo "bash \/root\/cap-rachel-first-install-3.sh&"' /etc/rc.local >> $RACHELLOG 2>&1

# Reboot
echo; print_good "RACHEL CAP Install - Script 2 ended at $(date)" | tee -a $RACHELLOG
echo; print_status "I need to reboot; once rebooted, please run the next download/install command." | tee -a $RACHELLOG
print_status "Rebooting in 10 seconds..." | tee -a $RACHELLOG
sleep 10
reboot >> $RACHELLOG 2>&1
