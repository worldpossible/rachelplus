#!/bin/sh
# FILE: cap-rachel-first-install-3.sh
# ONELINER Download/Install: sudo wget https://github.com/rachelproject/rachelplus/raw/master/install/cap-rachel-first-install-3.sh -O - | bash 

# Everything below will go to this log directory
TIMESTAMP=$(date +"%b-%d-%Y-%H%M%Z")
RACHELLOGDIR="/var/log/RACHEL"
mkdir -p $RACHELLOGDIR
RACHELLOGFILE="rachel-install.tmp"
RACHELLOG="$RACHELLOGDIR/$RACHELLOGFILE"
RACHELWWW="/media/RACHEL/rachel"
KALITEDIR="/var/ka-lite"
INSTALLTMPDIR="/root/cap-rachel-install.tmp"
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

# Delete previous setwanip commands from /etc/rc.local
echo; print_status "Deleting previous setwanip.sh script from /etc/rc.local"
sudo sed -i '/setwanip/d' /etc/rc.local
rm /root/setwanip.sh
print_good "Done."

# Delete previous iptables commands from /etc/rc.local
echo; print_status "Deleting previous iptables script from /etc/rc.local"
sudo sed -i '/iptables/d' /etc/rc.local
print_good "Done."

# Enable IP forwarding from 10.10.10.10 to 192.168.88.1 (only from wifi)
#echo 1 > /proc/sys/net/ipv4/ip_forward #line not needed as option already set
cat > /root/iptables-rachel.sh << 'EOF'
#!/bin/bash
# Add the RACHEL iptables rule to redirect 10.10.10.10 to CAP default of 192.168.88.1
# Added sleep to wait for CAP rcConf and rcConfd to finish initializing
#
sleep 60
iptables -t nat -A OUTPUT -d 10.10.10.10 -j DNAT --to-destination 192.168.88.1
EOF

# Add 10.10.10.10 redirect on every reboot
sudo sed -i '$e echo "# RACHEL iptables - Redirect from 10.10.10.10 to 192.168.88.1"' /etc/rc.local
#sudo sed -i '$e echo "iptables -t nat -A OUTPUT -d 10.10.10.10 -j DNAT --to-destination 192.168.88.1&"' /etc/rc.local
sudo sed -i '$e echo "bash /root/iptables-rachel.sh&"' /etc/rc.local

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
rm -rf /root/cap-rachel-*
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
