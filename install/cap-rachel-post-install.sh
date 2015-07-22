#!/bin/sh

# FILE: cap-rachel-post-install.sh
# ONELINER Download/Install: sudo wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-post-install.sh -O - | bash 
# Add header/date/time to install log file

# Everything below will go to this log directory
VERSION="BETA (July 18, 2015)"
TIMESTAMP=$(date +"%b-%d-%Y-%H%M%Z")
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

# Check root
if [ "$(id -u)" != "0" ]; then
	print_error "This step must be run as root; sudo password is 123lkj"
	exit 1
fi

# Add header/date/time to install log file
echo; print_good "RACHEL CAP Post-Install Script - Version $VERSION" | tee $RACHELLOG
print_good "Install started: $TIMESTAMP" | tee -a $RACHELLOG

: <<'COMMENT'
# Ask if RACHEL is already installed
echo; print_question "Is the core RACHEL content already located in the /media/RACHEL/rachel folder?" | tee -a $RACHELLOG
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

# Add RACHEL home directory - this is redundant with the next git clone command
echo; print_status "Add RACHEL home directory."
mkdir /media/RACHEL/rachel
print_good "Done."
COMMENT

# Clone the RACHEL content shell from GitHub
echo; print_status "Cloning the RACHEL content shell from GitHub." | tee -a $RACHELLOG
git clone https://github.com/rachelproject/contentshell /media/RACHEL/rachel
print_good "Done." | tee -a $RACHELLOG

# Download RACHEL Captive Portal redirect page
echo; print_status "Downloading Captive Portal content and moving a copy files." | tee -a $RACHELLOG
if [[ ! -f $RACHELWWW/art/captiveportal-redirect.php ]]; then
	wget https://github.com/rachelproject/rachelplus/raw/master/captive-portal/captiveportal-redirect.php -O $RACHELWWW/art/captiveportal-redirect.php 1>> $RACHELLOG 2>&1
else
	print_good "$RACHELWWW/art/captiveportal-redirect.php exists, skipping."
fi
if [[ ! -f $RACHELWWW/art/captiveportal-redirect.php ]]; then
	wget https://github.com/rachelproject/rachelplus/raw/master/captive-portal/RACHELbrandLogo-captive.png -O $RACHELWWW/art/RACHELbrandLogo-captive.png 1>> $RACHELLOG 2>&1
else
	print_good "$RACHELWWW/art/RACHELbrandLogo-captive.png exists, skipping."
fi
if [[ ! -f $RACHELWWW/art/captiveportal-redirect.php ]]; then
	wget https://github.com/rachelproject/rachelplus/raw/master/captive-portal/HFCbrandLogo-captive.jpg -O $RACHELWWW/art/HFCbrandLogo-captive.jpg 1>> $RACHELLOG 2>&1
else
	print_good "$RACHELWWW/art/HFCbrandLogo-captive.jpg exists, skipping."
fi
if [[ ! -f $RACHELWWW/art/captiveportal-redirect.php ]]; then
	wget https://github.com/rachelproject/rachelplus/raw/master/captive-portal/WorldPossiblebrandLogo-captive.png -O $RACHELWWW/art/WorldPossiblebrandLogo-captive.png 1>> $RACHELLOG 2>&1
else
	print_good "$RACHELWWW/art/WorldPossiblebrandLogo-captive.png exists, skipping."
fi

# Copy over files needed for Captive Portal redirect to work (these are the same ones used by the CAP)
if [[ ! -f $RACHELWWW/pass_ticket.shtml && ! -f $RACHELWWW/redirect.shtml ]]; then
	cp /www/pass_ticket.shtml /www/redirect.shtml $RACHELWWW/. 1>> $RACHELLOG 2>&1
else
	print_good "$RACHELWWW/pass_ticket.shtml and $RACHELWWW/redirect.shtml exist, skipping."
fi
print_good "Done." | tee -a $RACHELLOG

# Add header/date/time to install log file
sudo mv $RACHELLOG $RACHELLOGDIR/rachel-post-install-$TIMESTAMP.log 1>> $RACHELLOG 2>&1
echo; print_good "Log file saved to: $RACHELLOGDIR/rachel-post-install-$TIMESTAMP.log" | tee -a $RACHELLOG
print_good "RACHEL CAP Post-Install Complete." | tee -a $RACHELLOG
echo; print_status "I need to reboot; once rebooted, your CAP is ready for RACHEL content."
echo "Download modules from http://dev.worldpossible.org/mods/"
echo; print_status "Rebooting in 10 seconds..." 
sleep 10
reboot
