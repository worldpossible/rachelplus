#!/bin/sh
# FILE: cap-rachel-first-install-2.sh
# ONELINER Download/Install: wget https://github.com/rachelproject/rachelplus/raw/master/install/cap-rachel-first-install-2.sh -O - | bash 

# Import functions from /root/cap-rachel-configure.sh
. /root/cap-rachel-configure.sh --source-only

# # Everything below will go to this log directory
# rachelLogDir="/var/log/rachel"
# rachelLogFile="rachel-install.tmp"
# rachelLog="$rachelLogDir/$rachelLogFile"
# installTmpDir="/root/cap-rachel-install.tmp"

# Close STDOUT file descriptor
exec 1<&-
# Close STDERR FD
exec 2<&-
# Open STDOUT as $rachelLog file for read and write.
exec 1>>$rachelLog
# Redirect STDERR to STDOUT
exec 2>&1

# exec 1>> $rachelLog 2>&1

function printGood () {
    echo -e "\x1B[01;32m[+]\x1B[0m $1"
}

function printError () {
    echo -e "\x1B[01;31m[-]\x1B[0m $1"
}

function printStatus () {
    echo -e "\x1B[01;35m[*]\x1B[0m $1"
}

function printQuestion () {
    echo -e "\x1B[01;33m[?]\x1B[0m $1"
}

# Check root
if [ "$(id -u)" != "0" ]; then
  printError "This step must be run as root; sudo password is 123lkj"
  exit 1
fi

# Add header/date/time to install log file
echo; printGood "RACHEL CAP Install - Script 2 started at $(date)"

# Delete previous setup commands from the /etc/rc.local
sudo sed -i '/cap-rachel/d' /etc/rc.local

# If this script is running, we don't want any previous data, so force creation of new filesystems
umount /dev/sda1 /dev/sda2 /dev/sda3

# Create the new filesystems so we can write files to them
echo; printStatus "Creating filesystems"
# Turn logging off - might cause issues
#exec &>/dev/tty
mkfs.ext4 -L "preloaded" -U 77777777-7777-7777-7777-777777777777 /dev/sda1
mkfs.ext4 -L "uploaded" -U 88888888-8888-8888-8888-888888888888 /dev/sda2
mkfs.ext4 -L "RACHEL" -U 99999999-9999-9999-9999-999999999999 /dev/sda3
# Turn logging back on
#exec &> >(tee -a "$rachelLog")
printGood "Done."

# Add lines to /etc/rc.local that will start the next script to run on reboot
sudo sed -i '$e echo "bash '$installTmpDir'\/cap-rachel-first-install-3.sh&"' /etc/rc.local

## DELETE when done testing
echo 1 > /root/script2.ran
printGood "Wrote /root/script2.ran file"

# Reboot
echo; printGood "RACHEL CAP Install - Script 2 ended at $(date)"
echo; printStatus "I need to reboot; once rebooted, please run the next download/install command."
printStatus "Rebooting in 5 seconds..."
sleep 5
noCleanup=1
# reboot