
#!/bin/sh
# FILE: cap-rachel-first-install.sh
# ONELINER Download/Install: sudo wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-first-install.sh -O - | bash 

RACHELLOG="/var/log/rachel-install.log"

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
$WGET -q --tries=10 --timeout=5 http://www.google.com -O /tmp/index.google &> /dev/null | tee $RACHELLOG
if [ ! -s /tmp/index.google ];then
	print_error "No internet connectivity; connect to the internet and try again." | tee $RACHELLOG
	exit 1
else
	print_good "Internet connected...continuing install." | tee $RACHELLOG
fi

# Save backup of previous install log file to $RACHELLOG.bak
if [[ -f $RACHELLOG ]]; then
	mv $RACHELLOG $RACHELLOG.bak
	print_good "Saved backup of previous install log to $RACHELLOG.bak"
fi

# Add header/date/time to install log file
echo; print_good "RACHEL CAP Install - Started $(date)" | tee $RACHELLOG

# Fix hostname issue in /etc/hosts
sed -i 's/ec-server/WRTD-303N-Server/g' /etc/hosts | tee -a $RACHELLOG

# Delete previous setup commands from the /etc/rc.local
sudo sed -i '/cap-rachel/d' /etc/rc.local | tee -a $RACHELLOG

# Download additional scripts to /root
echo; print_status "Downloading RACHEL install scripts for CAP" | tee -a $RACHELLOG
## cap-rachel-first-install-1.sh
sudo wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-first-install-1.sh -O /root/cap-rachel-first-install-1.sh | tee -a $RACHELLOG
## cap-rachel-first-install-2.sh
sudo wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-first-install-2.sh -O /root/cap-rachel-first-install-2.sh | tee -a $RACHELLOG
## cap-rachel-first-install-3.sh
sudo wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-first-install-3.sh -O /root/cap-rachel-first-install-3.sh | tee -a $RACHELLOG
## cap-rachel-setwanip-install.sh
sudo wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-setwanip-install.sh -O /root/cap-rachel-setwanip-install.sh | tee -a $RACHELLOG
echo; print_good "Downloading complete." | tee -a $RACHELLOG

# Show location of the log file
echo; print_status "Location of RACHEL install log file:" | tee -a $RACHELLOG
echo "$RACHELLOG" | tee -a $RACHELLOG

# Ask if you are ready to install
echo; read -p "Are you ready to start the install? " -n 1 -r <&1
if [[ $REPLY =~ ^[Yy]$ ]]; then
	echo; print_status "Starting first install script...please wait patiently (about 30 secs) for first reboot." | tee -a $RACHELLOG
	echo; print_status "The entire script (with reboots) takes 2-5 minutes."
	bash /root/cap-rachel-first-install-1.sh
else
	echo; print_error "User requests not to continue...exiting at $(date)" | tee -a $RACHELLOG
	echo; exit 1
fi
