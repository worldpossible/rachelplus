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

function print_good () {
    echo -e "\x1B[01;32m[+]\x1B[0m $1"
}

function print_error () {
    echo -e "\x1B[01;31m[-]\x1B[0m $1"
}

function print_status () {
    echo -e "\x1B[01;35m[*]\x1B[0m $1"
}

function print_question () {
    echo -e "\x1B[01;33m[?]\x1B[0m $1"
}

# Check root
if [ "$(id -u)" != "0" ]; then
  print_error "This step must be run as root; sudo password is 123lkj"
  exit 1
fi

# Add header/date/time to install log file
echo; print_good "RACHEL CAP Install - Script 3 started at $(date)"

# Change directory into $INSTALLTMPDIR
cd $INSTALLTMPDIR

# Delete previous setup commands from the /etc/rc.local
sudo sed -i '/cap-rachel/d' /etc/rc.local

# Check partitions
echo; print_status "Printing paritition table:"
df -h
echo; print_status "The partition table for /dev/sda should look very similar to the following:"
echo "/dev/sda1        20G   44M   19G   1% /media/preloaded"
echo "/dev/sda2        99G   60M   94G   1% /media/uploaded"
echo "/dev/sda3       339G   67M  321G   1% /media/RACHEL"

# Fixing /root/rachel-scripts.sh
echo; print_status "Fixing $RACHELSCRIPTSFILE" | tee -a $RACHELLOG

# Add rachel-scripts.sh script
sed "s,%RACHELSCRIPTSLOG%,$RACHELSCRIPTSLOG,g" > $RACHELSCRIPTSFILE << 'EOF'
#!/bin/bash
# Send output to log file
rm -f %RACHELSCRIPTSLOG%
exec 1>> %RACHELSCRIPTSLOG% 2>&1
# Add the RACHEL iptables rule to redirect 10.10.10.10 to CAP default of 192.168.88.1
# Added sleep to wait for CAP rcConf and rcConfd to finish initializing
#
sleep 60
iptables -t nat -I PREROUTING -d 10.10.10.10 -j DNAT --to-destination 192.168.88.1
exit 0
EOF


# Add rachel-scripts.sh startup in /etc/rc.local
sed -i '/scripts/d' /etc/rc.local
sudo sed -i '$e echo "# Add RACHEL startup scripts"' /etc/rc.local
sudo sed -i '$e echo "bash /root/rachel-scripts.sh&"' /etc/rc.local

# Check/re-add Kiwix
if [[ -d /var/kiwix ]]; then
    echo; print_status "Setting up Kiwix to start at boot..."
    # Remove old kiwix boot lines from /etc/rc.local
    sed -i '/kiwix/d' /etc/rc.local
    # Clean up current rachel-scripts.sh file
    sed -i '/kiwix/d' $RACHELSCRIPTSFILE
    # Add lines to /etc/rc.local that will start kiwix on boot
    sed -i '$e echo "\# Start kiwix on boot"' $RACHELSCRIPTSFILE
    sed -i '$e echo "\/var\/kiwix\/bin\/kiwix-serve --daemon --port=81 --library \/media\/RACHEL\/kiwix\/data\/library\/library.xml"' $RACHELSCRIPTSFILE
fi

if [[ -d /var/ka-lite ]]; then
    echo; print_status "Setting up KA Lite to start at boot..."
    # Delete previous setup commands from the /etc/rc.local
    sed -i '/ka-lite/d' /etc/rc.local
    sed -i '/sleep 20/d' /etc/rc.local
    # Clean up current rachel-scripts.sh file
    sed -i '/ka-lite/d' $RACHELSCRIPTSFILE
    sed -i '/sleep 20/d' $RACHELSCRIPTSFILE
    # Start KA Lite at boot time
    sed -i '$e echo "# Start ka-lite at boot time"' $RACHELSCRIPTSFILE
    sed -i '$e echo "sleep 20"' $RACHELSCRIPTSFILE
    sed -i '$e echo "/var/ka-lite/bin/kalite restart"' $RACHELSCRIPTSFILE
    print_good "Done." | tee -a $RACHELLOG
fi

# Clean up outdated stuff
# Remove outdated startup script
rm -f /root/iptables-rachel.sh

# Delete previous setwanip commands from /etc/rc.local - not used anymore
echo; print_status "Deleting previous setwanip.sh script from /etc/rc.local"
sed -i '/setwanip/d' /etc/rc.local
rm -f /root/setwanip.sh
print_good "Done." | tee -a $RACHELLOG

# Delete previous iptables commands from /etc/rc.local
echo; print_status "Deleting previous iptables script from /etc/rc.local"
sed -i '/iptables/d' /etc/rc.local
print_good "Done." | tee -a $RACHELLOG

# If $RACHELWWW doesn't exist, set it up
if [[ ! -d $RACHELWWW ]]; then
	echo; print_status "Setting up RACHEL Content Shell."
	mv $INSTALLTMPDIR/contentshell $RACHELWWW
fi

# Move RACHEL Captive Portal redirect page and images to correct folders
cd $INSTALLTMPDIR
echo; print_status "Setting up RACHEL Captive Portal."
mv captiveportal-redirect.php $RACHELWWW/
print_good "Moved captive portal webpage to $RACHELWWW/captiveportal-redirect.php"
mv $INSTALLTMPDIR/*captive.* $RACHELWWW/art/
print_good "Moved captive portal images to $RACHELWWW/art folder."
print_good "Done."

# Copy over files needed for Captive Portal redirect to work (these are the same ones used by the CAP)
if [[ ! -f $RACHELWWW/pass_ticket.shtml && ! -f $RACHELWWW/redirect.shtml ]]; then
	cp /www/pass_ticket.shtml /www/redirect.shtml $RACHELWWW/.
else
	print_good "$RACHELWWW/pass_ticket.shtml and $RACHELWWW/redirect.shtml exist, skipping."
fi
print_good "Done."

# Deleting the install script commands
echo; print_status "Deleting the install scripts."
rm -rf /root/cap-rachel-* $RACHELTMPDIR
print_good "Done."

# Add header/date/time to install log file
sudo mv $RACHELLOG $RACHELLOGDIR/rachel-install-$TIMESTAMP.log
echo; print_good "Log file saved to: $RACHELLOGDIR/rachel-install-$TIMESTAMP.log"
print_good "RACHEL CAP Install Complete."

# Reboot
echo; print_status "I need to reboot; once rebooted, your CAP is ready for RACHEL content."
echo "Download modules from http://dev.worldpossible.org/mods/"
echo; print_status "Rebooting in 10 seconds..." 
sleep 10
reboot
