
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
    echo -e "\x1B[01;34m[*]\x1B[0m $1"
}

# Check root
if [ "$(id -u)" != "0" ]; then
	print_error "This step must be run as root; sudo password is 123lkj"
	exit 1
fi

# Check internet connecivity
WGET=`which wget`
$WGET -N --tries=10 --timeout=5 http://www.google.com -O /tmp/index.google &> /dev/null >> $RACHELLOG 2>&1
if [ ! -s /tmp/index.google ]; then
	print_error "No internet connectivity; connect to the internet and try again." | tee $RACHELLOG
	exit 1
else
	print_good "Internet connected...continuing install." | tee $RACHELLOG
fi

# Save backup of previous install log file to $RACHELLOG.bak
#PREVRACHELLOG=``
#if [[ -f $RACHELLOG ]]; then
#	mv $RACHELLOG $RACHELLOG.bak >> $RACHELLOG 2>&1
#	echo; print_good "Saved backup of previous install log to $RACHELLOG.bak"
#fi

# Add header/date/time to install log file
echo; print_good "RACHEL CAP Install Script - Version 1" | tee $RACHELLOG
print_good "Install started: $(date)"

# Fix hostname issue in /etc/hosts
echo; print_status "Fixing hostname in /etc/hosts" | tee -a $RACHELLOG
sed -i 's/ec-server/WRTD-303N-Server/g' /etc/hosts >> $RACHELLOG 2>&1
print_good "Done." | tee -a $RACHELLOG

# Delete previous setup commands from the /etc/rc.local
echo; print_status "Delete previous RACHEL setup commands from /etc/rc.local" | tee -a $RACHELLOG
sudo sed -i '/cap-rachel/d' /etc/rc.local >> $RACHELLOG 2>&1
print_good "Done." | tee -a $RACHELLOG

# Download additional scripts to /root
echo; print_status "Downloading RACHEL install scripts for CAP" | tee -a $RACHELLOG
## cap-rachel-first-install-1.sh
sudo wget -N https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-first-install-1.sh -O /root/cap-rachel-first-install-1.sh >> $RACHELLOG 2>&1
## cap-rachel-first-install-2.sh
sudo wget -N https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-first-install-2.sh -O /root/cap-rachel-first-install-2.sh >> $RACHELLOG 2>&1
## cap-rachel-first-install-3.sh
sudo wget -N https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-first-install-3.sh -O /root/cap-rachel-first-install-3.sh >> $RACHELLOG 2>&1
## cap-rachel-setwanip-install.sh
sudo wget -N https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-setwanip-install.sh -O /root/cap-rachel-setwanip-install.sh >> $RACHELLOG 2>&1
print_good "Done." | tee -a $RACHELLOG

# Show location of the log file
echo; print_status "Directory of RACHEL install log files with date/time stamps:" | tee -a $RACHELLOG
echo "$RACHELLOGDIR" | tee -a $RACHELLOG

# Ask if you are ready to install
echo; read -p "Are you ready to start the install? " -n 1 -r <&1
if [[ $REPLY =~ ^[Yy]$ ]]; then
	echo; echo; print_status "Starting first install script...please wait patiently (about 30 secs) for first reboot." | tee -a $RACHELLOG
	print_status "The entire script (with reboots) takes 2-5 minutes." | tee -a $RACHELLOG
	bash /root/cap-rachel-first-install-1.sh
else
	echo; print_error "User requests not to continue...exiting at $(date)" | tee -a $RACHELLOG
	echo; exit 1
fi
