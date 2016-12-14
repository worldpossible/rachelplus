#!/bin/sh
# FILE: cap-rachel-first-install-3.sh
# ONELINER Download/Install: sudo wget https://github.com/rachelproject/rachelplus/raw/master/install/cap-rachel-first-install-3.sh -O - | bash 

# Import functions from /root/cap-rachel-configure.sh
. /root/cap-rachel-configure.sh --source-only

# Everything below will go to this log directory
timestamp=$(date +"%b-%d-%Y-%H%M%Z")
rachelLogDir="/var/log/rachel"
rachelLogFile="rachel-install.tmp"
rachelLog="$rachelLogDir/$rachelLogFile"
rachelPartition="/media/RACHEL"
rachelWWW="$rachelPartition/rachel"
kaliteDir="/var/ka-lite"
kaliteContentDir="/media/RACHEL/kacontent"
installTmpDir="/root/cap-rachel-install.tmp"
rachelTmpDir="/media/RACHEL/cap-rachel-install.tmp"
rachelScriptsDir="/root/rachel-scripts"
rachelScriptsFile="$rachelScriptsDir/rachelStartup.sh"
rachelScriptsLog="$rachelLogDir/rachel-scripts.log"

exec 1>> $rachelLog 2>&1

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
echo; printGood "RACHEL CAP Install - Script 3 started at $(date)"

# Change directory into $installTmpDir
cd $installTmpDir

# Delete previous setup commands from the /etc/rc.local
sudo sed -i '/cap-rachel/d' /etc/rc.local

# Check partitions
echo; printStatus "Printing paritition table:"
df -h
echo; printStatus "The partition table for /dev/sda should look very similar to the following:"
# v1 CAPs post RACHEL Recovery USB v9 and v2 CAPs
echo "/dev/sda1       2.9G  4.6M  2.8G   1% /media/preloaded"
echo "/dev/sda2        17G   44M   16G   1% /media/uploaded"
echo "/dev/sda3       439G   67M  411G   1% /media/RACHEL"
# OLD v1 CAPs
#echo "/dev/sda1        20G   44M   19G   1% /media/preloaded"
#echo "/dev/sda2        99G   60M   94G   1% /media/uploaded"
#echo "/dev/sda3       339G   67M  321G   1% /media/RACHEL"

# Fixing $rachelScriptsFile
repairRachelScripts

# Remove outdated startup script - replaced by /root/rachel-scripts/rachelStartup.sh
rm -f /root/iptables-rachel.sh

# Delete previous setwanip commands from /etc/rc.local - not used anymore
echo; printStatus "Deleting previous setwanip.sh script from /etc/rc.local"
sed -i '/setwanip/d' /etc/rc.local
rm -f /root/setwanip.sh
printGood "Done."

# Delete previous iptables commands from /etc/rc.local - not used anymore
echo; printStatus "Deleting previous iptables script from /etc/rc.local"
sed -i '/iptables/d' /etc/rc.local
printGood "Done."

# Add battery monitor for safe shutdown
installBatteryWatch

# Add Kiwix library update script
createKiwixRepairScript

# Add RACHEL script complete line
sed -i '$e echo "echo \\$(date) - RACHEL startup completed"' $rachelScriptsFile

# Display currently mounted partitions
mount

# If $rachelWWW doesn't exist, set it up
if [[ ! -d $rachelWWW ]]; then
    echo; printStatus "Setting up RACHEL Content Shell."
    mv $installTmpDir/contentshell $rachelWWW
fi

# # Move RACHEL Captive Portal redirect page and images to correct folders
# cd $installTmpDir
# echo; printStatus "Setting up RACHEL Captive Portal."
# mv captiveportal-redirect.php $rachelWWW/
# printGood "Moved captive portal webpage to $rachelWWW/captiveportal-redirect.php"
# mv $installTmpDir/*captive.* $rachelWWW/art/
# printGood "Moved captive portal images to $rachelWWW/art folder."
# printGood "Done."

# # Copy over files needed for Captive Portal redirect to work (these are the same ones used by the CAP)
# if [[ ! -f $rachelWWW/pass_ticket.shtml && ! -f $rachelWWW/redirect.shtml ]]; then
#     cp /www/pass_ticket.shtml /www/redirect.shtml $rachelWWW/.
# else
#     printGood "$rachelWWW/pass_ticket.shtml and $rachelWWW/redirect.shtml exist, skipping."
# fi
# printGood "Done."

# Add local content module
echo; printStatus "Adding the local content module."
rsync -avz $rsyncOnline/rachelmods/en-local_content $rachelWWW/modules/
printGood "Done."

# Deleting the install script commands
echo; printStatus "Deleting the install scripts."
rm -rf $installTmpDir $rachelTmpDir
printGood "Done."

# Add header/date/time to install log file
sudo mv $rachelLog $rachelLogDir/rachel-install-$timestamp.log
echo; printGood "Log file saved to: $rachelLogDir/rachel-install-$timestamp.log"
printGood "RACHEL CAP Install Complete."

# Reboot
echo; printStatus "I need to reboot; once rebooted, your CAP is ready for RACHEL content."
echo "Download modules from http://dev.worldpossible.org/mods/"
echo; printStatus "Rebooting..." 
reboot
