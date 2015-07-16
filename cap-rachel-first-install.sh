#!/bin/sh
# FILE: cap-rachel-first-install.sh
# ONELINER Download/Install: sudo wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-first-install.sh -O - | bash 

# Everything below will go to this log directory
RACHELLOGDIR="/var/log/RACHEL"
mkdir -p $RACHELLOGDIR
RACHELLOGFILE="rachel-install.tmp"
RACHELLOG="$RACHELLOGDIR/$RACHELLOGFILE"

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
echo; print_good "RACHEL CAP Install Script - Version 1" | tee $RACHELLOG
print_good "Install started: $(date)" | tee -a $RACHELLOG

# Check internet connecivity
WGET=`which wget`
$WGET -q --tries=10 --timeout=5 --spider http://google.com 1>> $RACHELLOG 2>&1
if [[ $? -eq 0 ]]; then
	echo; print_good "Internet connected...continuing install." | tee -a $RACHELLOG
else
	echo; print_error "No internet connectivity; connect to the internet and try again."
	exit 1
fi

# Fix hostname issue in /etc/hosts
echo; print_status "Fixing hostname in /etc/hosts" | tee -a $RACHELLOG
sed -i 's/ec-server/WRTD-303N-Server/g' /etc/hosts 1>> $RACHELLOG 2>&1
print_good "Done." | tee -a $RACHELLOG

# Delete previous setup commands from the /etc/rc.local
echo; print_status "Delete previous RACHEL setup commands from /etc/rc.local" | tee -a $RACHELLOG
sudo sed -i '/cap-rachel/d' /etc/rc.local 1>> $RACHELLOG 2>&1
print_good "Done." | tee -a $RACHELLOG

# Download additional scripts to /root
echo; print_status "Downloading RACHEL install scripts for CAP" | tee -a $RACHELLOG
## cap-rachel-first-install-1.sh
sudo wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-first-install-1.sh -O /root/cap-rachel-first-install-1.sh 1>> $RACHELLOG 2>&1
## cap-rachel-first-install-2.sh
sudo wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-first-install-2.sh -O /root/cap-rachel-first-install-2.sh 1>> $RACHELLOG 2>&1
## cap-rachel-first-install-3.sh
sudo wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-first-install-3.sh -O /root/cap-rachel-first-install-3.sh 1>> $RACHELLOG 2>&1
## cap-rachel-setwanip-install.sh
sudo wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-setwanip-install.sh -O /root/cap-rachel-setwanip-install.sh 1>> $RACHELLOG 2>&1
## lighttpd.conf - RACHEL version (I don't overwrite at this time due to other dependencies)
sudo wget https://github.com/rachelproject/rachelplus/raw/master/lighttpd.conf -O /root/lighttpd.conf 1>> $RACHELLOG 2>&1
print_good "Done." | tee -a $RACHELLOG

# Show location of the log file
echo; print_status "Directory of RACHEL install log files with date/time stamps:" | tee -a $RACHELLOG
echo "$RACHELLOGDIR" | tee -a $RACHELLOG

# Ask if you are ready to install
echo; print_question "WARNING: This process will destroy all content on /media/RACHEL" | tee -a $RACHELLOG

read -p "Are you ready to start the install? " -r <&1
if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
	echo; print_status "Starting first install script...please wait patiently (about 30 secs) for first reboot." | tee -a $RACHELLOG
	print_status "The entire script (with reboots) takes 2-5 minutes." | tee -a $RACHELLOG
	bash /root/cap-rachel-first-install-1.sh
else
	echo; print_error "User requests not to continue...exiting at $(date)" | tee -a $RACHELLOG
	# Deleting the install script commands
	rm -f /root/cap-rachel-* $RACHELLOG
	echo; exit 1
fi
