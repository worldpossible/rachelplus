#!/bin/sh

# VERY VERY VERY VERY VERY BETA

# FILE: cap-rachel-post-install.sh
# ONELINER Download/Install: sudo wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-post-install.sh -O - | bash 

# Everything below will go to this log directory
RACHELLOGDIR="/var/log/RACHEL"
mkdir -p $RACHELLOGDIR
RACHELLOGFILE="rachel-install.tmp"
RACHELLOG="$RACHELLOGDIR/$RACHELLOGFILE"
RACHELWWW="/media/RACHEL/rachel"

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

print_error "This script is too beta at the moment, exiting."
exit 1

# Check root
if [ "$(id -u)" != "0" ]; then
	print_error "This step must be run as root; sudo password is 123lkj"
	exit 1
fi

# Add header/date/time to install log file
echo; print_good "RACHEL CAP Post-Install Script - Version 1" | tee $RACHELLOG
print_good "Install started: $(date)" | tee -a $RACHELLOG

# Ask if RACHEL is already installed
echo; print_question "Is the base RACHEL content already located at /media/RACHEL/rachel folder?" | tee -a $RACHELLOG
read -p "If you answer (n), you will be given an option to provide a path to the content (y/n) " -r <&1
if [[ $REPLY =~ ^[nN][oO]|[nN]$ ]]; then
	echo; print_question "The base build of this install is the RACHEL USB 32GB zip file called rachelusb_32EN_X.X.X.zip" | tee -a $RACHELLOG
	echo "    The X.X.X portion of the file name will vary depending on the RACHEL version. If you have that file at a location" | tee -a $RACHELLOG
	echo "    that the Intel CAP can reach, answer (y) to enter the path to the file." | tee -a $RACHELLOG
	echo; read -p "Would you like to provide a path to rsync the files from? (y/n) " -r <&1	
	if [[ $REPLY =~ ^[nN][oO]|[nN]$ ]]; then
		echo; print_error "User requests not to continue...exiting at $(date)" | tee -a $RACHELLOG
		echo; exit 1
	fi
	echo "What is the path to the rachelusb_32EN_X.X.X.zip file? " read rachelpath

fi

# Reconfigure RACHEL files
echo; print_question "Before running this script, you need to have copied the basic RACHEL content to" | tee -a $RACHELLOG
echo "  /media/RACHEL/rachel on the Intel CAP.  You should see the RACHEL index.php file at /media/RACHEL/rachel/index.php" | tee -a $RACHELLOG
echo; echo "  If you are not ready, answer 'N', copy over the data and then run this script again." | tee -a $RACHELLOG

read -p "Are you ready to update the RACHEL files? " -r <&1
if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
	echo; print_status "Fixing index.php." | tee -a $RACHELLOG
	# Redirect LOCAL CONTENT link to Intel CAP's content manager site on port 8090
	sed -i 's|<li><a href="local-frameset.html">LOCAL CONTENT</a></li>|<li><a href="./" onclick="javascript:event.target.port=8090" target="_blank">LOCAL CONTENT</a></li>|g' /media/RACHEL/rachel/index.php
	# Display the current IP of the server on the main page
	sed -i 's|<div id="ip">http://<?php echo gethostbyname(gethostname()); ?>/</div>|<div align="right" id="ip"><b>Server Address</b> </br><? echo $_SERVER["SERVER_ADDR"]; ?></div>|g' /media/RACHEL/rachel/index.php
	# Download RACHEL Captive Portal redirect page
	wget https://github.com/rachelproject/rachelplus/raw/master/captiveportal-redirect.php -O $RACHELWWW/captiveportal-redirect.php
	# Copy over files needed for Captive Portal redirect
	cp /www/pass_ticket.shtml /www/redirect.shtml $RACHELWWW/.
else
	# Exit program
	echo; print_error "User requests not to continue...exiting at $(date)" | tee -a $RACHELLOG
	# Deleting the install script commands
	rm -f /root/cap-rachel-* $RACHELLOG
	echo; exit 1
fi