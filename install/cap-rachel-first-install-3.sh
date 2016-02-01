#!/bin/sh
# FILE: cap-rachel-first-install-3.sh
# ONELINER Download/Install: sudo wget https://github.com/rachelproject/rachelplus/raw/master/install/cap-rachel-first-install-3.sh -O - | bash 

# Everything below will go to this log directory
TIMESTAMP=$(date +"%b-%d-%Y-%H%M%Z")
RACHELLOGDIR="/var/log/RACHEL"
RACHELLOGFILE="rachel-install.tmp"
RACHELLOG="$RACHELLOGDIR/$RACHELLOGFILE"
RACHELPARTITION="/media/RACHEL"
RACHELWWW="$RACHELPARTITION/rachel"
KALITEDIR="/var/ka-lite"
KALITERCONTENTDIR="/media/RACHEL/kacontent"
INSTALLTMPDIR="/root/cap-rachel-install.tmp"
RACHELTMPDIR="/media/RACHEL/cap-rachel-install.tmp"
RACHELSCRIPTSFILE="/root/rachel-scripts.sh"
RACHELSCRIPTSLOG="/var/log/RACHEL/rachel-scripts.log"

exec 1>> $RACHELLOG 2>&1

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

# Change directory into $INSTALLTMPDIR
cd $INSTALLTMPDIR

# Delete previous setup commands from the /etc/rc.local
sudo sed -i '/cap-rachel/d' /etc/rc.local

# Check partitions
echo; printStatus "Printing paritition table:"
df -h
echo; printStatus "The partition table for /dev/sda should look very similar to the following:"
echo "/dev/sda1        20G   44M   19G   1% /media/preloaded"
echo "/dev/sda2        99G   60M   94G   1% /media/uploaded"
echo "/dev/sda3       339G   67M  321G   1% /media/RACHEL"

# Fixing /root/rachel-scripts.sh
echo; printStatus "Fixing $RACHELSCRIPTSFILE"

# Add rachel-scripts.sh script
sed "s,%RACHELSCRIPTSLOG%,$RACHELSCRIPTSLOG,g" > $RACHELSCRIPTSFILE << 'EOF'
#!/bin/bash
# Send output to log file
rm -f %RACHELSCRIPTSLOG%
exec 1>> %RACHELSCRIPTSLOG% 2>&1
echo $(date) - Starting RACHEL script
exit 0
EOF


# Add rachel-scripts.sh startup in /etc/rc.local
sed -i '/scripts/d' /etc/rc.local
sudo sed -i '$e echo "# Add RACHEL startup scripts"' /etc/rc.local
sudo sed -i '$e echo "bash /root/rachel-scripts.sh&"' /etc/rc.local

# Check/re-add Kiwix
if [[ -d /var/kiwix ]]; then
    echo; printStatus "Setting up Kiwix to start at boot..."
    # Remove old kiwix boot lines from /etc/rc.local
    sed -i '/kiwix/d' /etc/rc.local
    # Clean up current rachel-scripts.sh file
    sed -i '/kiwix/d' $RACHELSCRIPTSFILE
    # Add lines to /etc/rc.local that will start kiwix on boot
    sed -i '$e echo "\# Start kiwix on boot"' $RACHELSCRIPTSFILE
    sed -i '$e echo "echo \\$(date) - Starting kiwix"' $RACHELSCRIPTSFILE
    sed -i '$e echo "\/var\/kiwix\/bin\/kiwix-serve --daemon --port=81 --library \/media\/RACHEL\/kiwix\/data\/library\/library.xml"' $RACHELSCRIPTSFILE
    printGood "Done."
fi

if [[ -d $KALITEDIR ]]; then
    # Delete previous setup commands from /etc/rc.local (not used anymore)
    sudo sed -i '/ka-lite/d' /etc/rc.local
    sudo sed -i '/sleep/d' /etc/rc.local
    # Delete previous setup commands from the $RACHELSCRIPTSFILE
    sudo sed -i '/ka-lite/d' $RACHELSCRIPTSFILE
    sudo sed -i '/kalite/d' $RACHELSCRIPTSFILE
    sudo sed -i '/sleep/d' $RACHELSCRIPTSFILE
    echo; printStatus "Setting up KA Lite to start at boot..."
    # Start KA Lite at boot time
    sudo sed -i '$e echo "# Start kalite at boot time"' $RACHELSCRIPTSFILE
    sed -i '$e echo "echo \\$(date) - Starting kalite"' $RACHELSCRIPTSFILE
    sudo sed -i '$e echo "sleep 5 #kalite"' $RACHELSCRIPTSFILE
    sudo sed -i '$e echo "sudo /usr/bin/kalite start"' $RACHELSCRIPTSFILE
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
echo; printStatus "Creating /root/batteryWatcher.sh"
echo "This script will monitor the battery charge level and shutdown this device with less than 3% battery charge."
# Create batteryWatcher script
cat > /root/batteryWatcher.sh << 'EOF'
#!/bin/bash
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
chmod +x /root/batteryWatcher.sh
# Check and kill other scripts running
echo; printStatus "Checking for and killing previously run battery monitoring scripts"
pid=$(ps aux | grep -v grep | grep "/bin/bash /root/batteryWatcher.sh" | awk '{print $2}')
if [[ ! -z $pid ]]; then kill $pid; fi
# Start script
/root/batteryWatcher.sh&
echo; printGood "Script started...monitoring battery."
printGood "Logging shutdowns to /var/log/RACHEL/shutdown.log"

# Add battery monitoring start line 
if [[ -f /root/batteryWatcher.sh ]]; then
    # Clean rachel-scripts.sh
    sed -i '/battery/d' $RACHELSCRIPTSFILE
    sed -i '$e echo "# Start battery monitoring"' $RACHELSCRIPTSFILE
    sed -i '$e echo "echo \\$(date) - Starting battery monitor"' $RACHELSCRIPTSFILE
    sed -i '$e echo "bash /root/batteryWatcher.sh&"' $RACHELSCRIPTSFILE
fi

# Check for disable reset button flag
echo; printStatus "Added check to disable the reset button"
sed -i '$e echo "\# Check if we should disable reset button"' $RACHELSCRIPTSFILE
sed -i '$e echo "echo \\$(date) - Checking if we should disable reset button"' $RACHELSCRIPTSFILE
sed -i '$e echo "if [[ -f /root/disable_reset ]]; then killall reset_button; echo \\"Reset button disabled\\"; fi"' $RACHELSCRIPTSFILE
printGood "Done."         

# Add RACHEL script complete line
sed -i '$e echo "echo \\$(date) - RACHEL startup completed"' $RACHELSCRIPTSFILE

# If $RACHELWWW doesn't exist, set it up
if [[ ! -d $RACHELWWW ]]; then
	echo; printStatus "Setting up RACHEL Content Shell."
	mv $INSTALLTMPDIR/contentshell $RACHELWWW
fi

# Move RACHEL Captive Portal redirect page and images to correct folders
cd $INSTALLTMPDIR
echo; printStatus "Setting up RACHEL Captive Portal."
mv captiveportal-redirect.php $RACHELWWW/
printGood "Moved captive portal webpage to $RACHELWWW/captiveportal-redirect.php"
mv $INSTALLTMPDIR/*captive.* $RACHELWWW/art/
printGood "Moved captive portal images to $RACHELWWW/art folder."
printGood "Done."

# Copy over files needed for Captive Portal redirect to work (these are the same ones used by the CAP)
if [[ ! -f $RACHELWWW/pass_ticket.shtml && ! -f $RACHELWWW/redirect.shtml ]]; then
	cp /www/pass_ticket.shtml /www/redirect.shtml $RACHELWWW/.
else
	printGood "$RACHELWWW/pass_ticket.shtml and $RACHELWWW/redirect.shtml exist, skipping."
fi
printGood "Done."

# Deleting the install script commands
echo; printStatus "Deleting the install scripts."
rm -rf /root/cap-rachel-* $RACHELTMPDIR
printGood "Done."

# Add header/date/time to install log file
sudo mv $RACHELLOG $RACHELLOGDIR/rachel-install-$TIMESTAMP.log
echo; printGood "Log file saved to: $RACHELLOGDIR/rachel-install-$TIMESTAMP.log"
printGood "RACHEL CAP Install Complete."

# Reboot
echo; printStatus "I need to reboot; once rebooted, your CAP is ready for RACHEL content."
echo "Download modules from http://dev.worldpossible.org/mods/"
echo; printStatus "Rebooting..." 
reboot
