#!/bin/sh
# FILE: cap-rachel-first-install-3.sh
# ONELINER Download/Install: sudo wget https://github.com/rachelproject/rachelplus/raw/master/install/cap-rachel-first-install-3.sh -O - | bash 

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
echo "/dev/sda1        20G   44M   19G   1% /media/preloaded"
echo "/dev/sda2        99G   60M   94G   1% /media/uploaded"
echo "/dev/sda3       339G   67M  321G   1% /media/RACHEL"

# Fixing '$rachelScriptsFile'
echo; printStatus "Fixing $rachelScriptsFile"

# Add rachel-scripts.sh script
sed "s,%rachelScriptsLog%,$rachelScriptsLog,g" > $rachelScriptsFile << 'EOF'
#!/bin/bash
# Send output to log file
rm -f %rachelScriptsLog%
exec 1>> %rachelScriptsLog% 2>&1
echo $(date) - Starting RACHEL script
exit 0
EOF


# Add rachel-scripts.sh startup in /etc/rc.local
sed -i '/scripts/d' /etc/rc.local
sudo sed -i '$e echo "# Add RACHEL startup scripts"' /etc/rc.local
sudo sed -i '$e echo "bash '$rachelScriptsFile'&"' /etc/rc.local

# Check/re-add Kiwix
if [[ -d /var/kiwix ]]; then
    echo; printStatus "Setting up Kiwix to start at boot..."
    # Remove old kiwix boot lines from /etc/rc.local
    sed -i '/kiwix/d' /etc/rc.local
    # Clean up current rachel-scripts.sh file
    sed -i '/kiwix/d' $rachelScriptsFile
    # Add lines to /etc/rc.local that will start kiwix on boot
    sed -i '$e echo "\# Start kiwix on boot"' $rachelScriptsFile
    sed -i '$e echo "echo \\$(date) - Starting kiwix"' $rachelScriptsFile
    sed -i '$e echo "\/var\/kiwix\/bin\/kiwix-serve --daemon --port=81 --library \/media\/RACHEL\/kiwix\/data\/library\/library.xml"' $rachelScriptsFile
    printGood "Done."
fi

if [[ -d $kaliteDir ]]; then
    # Delete previous setup commands from /etc/rc.local (not used anymore)
    sudo sed -i '/ka-lite/d' /etc/rc.local
    sudo sed -i '/sleep/d' /etc/rc.local
    # Delete previous setup commands from the $rachelScriptsFile
    sudo sed -i '/ka-lite/d' $rachelScriptsFile
    sudo sed -i '/kalite/d' $rachelScriptsFile
    sudo sed -i '/sleep/d' $rachelScriptsFile
    echo; printStatus "Setting up KA Lite to start at boot..."
    # Start KA Lite at boot time
    sudo sed -i '$e echo "# Start kalite at boot time"' $rachelScriptsFile
    sed -i '$e echo "echo \\$(date) - Starting kalite"' $rachelScriptsFile
    sudo sed -i '$e echo "sleep 5 #kalite"' $rachelScriptsFile
    sudo sed -i '$e echo "sudo /usr/bin/kalite start"' $rachelScriptsFile
    printGood "Done."
fi

# Remove outdated startup script
rm -f /root/iptables-rachel.sh

# Delete previous setwanip commands from /etc/rc.local - not used anymore
echo; printStatus "Deleting previous setwanip.sh script from /etc/rc.local"
sed -i '/setwanip/d' /etc/rc.local
rm -f /root/setwanip.sh
printGood "Done."

# Delete previous iptables commands from /etc/rc.local
echo; printStatus "Deleting previous iptables script from /etc/rc.local"
sed -i '/iptables/d' /etc/rc.local
printGood "Done."

# Add battery monitor for safe shutdown
echo; printStatus "Creating $rachelScriptsDir/batteryWatcher.sh"
echo "This script will monitor the battery charge level and shutdown this device with less than 3% battery charge."
# Create batteryWatcher script
cat > $rachelScriptsDir/batteryWatcher.sh << 'EOF'
#!/bin/bash
sleep 120
while :; do
    if [[ $(cat /tmp/chargeStatus) -lt 0 ]]; then
        if [[ $(cat /tmp/batteryLastChargeLevel) -lt 3 ]]; then
            echo "$(date) - Low battery shutdown" >> /var/log/RACHEL/shutdown.log
            kalite stop
            shutdown -h now
            exit 0
        fi
    fi
    sleep 10
done
EOF
chmod +x $rachelScriptsDir/batteryWatcher.sh

# Check and kill other scripts running
printStatus "Checking for and killing previously run battery monitoring scripts"
pid=$(ps aux | grep -v grep | grep "/bin/bash $rachelScriptsDir/batteryWatcher.sh" | awk '{print $2}')
if [[ ! -z $pid ]]; then kill $pid; fi
# Start script
$rachelScriptsDir/batteryWatcher.sh&
printGood "Script started...monitoring battery."
echo "Logging shutdowns to $rachelLogDir/shutdown.log"

# Add battery monitoring start line 
if [[ -f $rachelScriptsDir/batteryWatcher.sh ]]; then
    # Clean rachel-scripts.sh
    sed -i '/battery/d' $rachelScriptsFile
    sed -i '$e echo "# Start battery monitoring"' $rachelScriptsFile
    sed -i '$e echo "echo \\$(date) - Starting battery monitor"' $rachelScriptsFile
    sed -i '$e echo "bash '$rachelScriptsDir'/batteryWatcher.sh&"' $rachelScriptsFile
fi

# Add Kiwix library update script
echo; printStatus "Creating the Kiwix library rebuild/repair script."
# Create rachelKiwixStart script
cat > $rachelScriptsDir/rachelKiwixStart.sh << 'EOF'
#!/bin/bash
#-------------------------------------------
# This script is used to refresh the kiwix library upon restart to
# include everything in the rachel modules directory. It is used
# as part of the kiwix init.d script
#
# Author: Sam <sam@hackersforcharity.org>
# Based on perl version by Jonathan Field <jfield@worldpossible.org>
# Date: 2016-04-27
#-------------------------------------------

# Create tmp file (clean out new lines, etc)
tmp=`mktemp`
library="/media/RACHEL/kiwix/data/library/library.xml"

# Remove/recreate existing library
rm -f $library; touch $library

# Find all the zim files in the modules directoy
ls /media/RACHEL/rachel/modules/*/data/content/*.zim|sed 's/ /\n/g' > $tmp

# Remove modules that are marked hidden on main menu
for d in $(sqlite3 /media/RACHEL/rachel/admin.sqlite 'select moddir from modules where hidden = 1'); do
    sed -i '/'$d'/d' $tmp
done

for i in $(cat $tmp); do
    if [[ $? -ge 1 ]]; then echo "No zims found."; fi
    cmd="/var/kiwix/bin/kiwix-manage $library add $i"
    moddir="$(echo $i | cut -d'/' -f1-6)"
    zim="$(echo $i | cut -d'/' -f9)"
    if [[ -d "$moddir/data/index/$zim.idx" ]]; then
        cmd="$cmd --indexPath=$moddir/data/index/$zim.idx"
    fi
    $cmd
    if [[ $? -ge 1 ]]; then echo "Couldn't add $zim to library"; fi
done

# Restart Kiwix
killall /var/kiwix/bin/kiwix-serve
/var/kiwix/bin/kiwix-serve --daemon --port=81 --library $library
rm -f $tmp
EOF
chmod +x $rachelScriptsDir/rachelKiwixStart.sh
printGood "Done."

# Check for disable reset button flag
echo; printStatus "Added check to disable the reset button"
sed -i '$e echo "\# Check if we should disable reset button"' $rachelScriptsFile
sed -i '$e echo "echo \\$(date) - Checking if we should disable reset button"' $rachelScriptsFile
sed -i '$e echo "if [[ -f '$rachelScriptsDir'/disable_reset ]]; then killall reset_button; echo \\"Reset button disabled\\"; fi"' $rachelScriptsFile
printGood "Done."         

# Add RACHEL script complete line
sed -i '$e echo "echo \\$(date) - RACHEL startup completed"' $rachelScriptsFile

# Display currently mounted partitions
mount

# If $rachelWWW doesn't exist, set it up
if [[ ! -d $rachelWWW ]]; then
    echo; printStatus "Setting up RACHEL Content Shell."
    mv $installTmpDir/contentshell $rachelWWW
fi

# Move RACHEL Captive Portal redirect page and images to correct folders
cd $installTmpDir
echo; printStatus "Setting up RACHEL Captive Portal."
mv captiveportal-redirect.php $rachelWWW/
printGood "Moved captive portal webpage to $rachelWWW/captiveportal-redirect.php"
mv $installTmpDir/*captive.* $rachelWWW/art/
printGood "Moved captive portal images to $rachelWWW/art folder."
printGood "Done."

# Copy over files needed for Captive Portal redirect to work (these are the same ones used by the CAP)
if [[ ! -f $rachelWWW/pass_ticket.shtml && ! -f $rachelWWW/redirect.shtml ]]; then
    cp /www/pass_ticket.shtml /www/redirect.shtml $rachelWWW/.
else
    printGood "$rachelWWW/pass_ticket.shtml and $rachelWWW/redirect.shtml exist, skipping."
fi
printGood "Done."

# Add local content module
echo; printStatus "Adding the local content module."
rsync -avz $RSYNCDIR/rachelmods/en-local_content $rachelWWW/modules/
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
