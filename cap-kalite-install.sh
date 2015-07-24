#!/bin/bash
# Install ka-lite
# Bernd 22 July 2016

# FILE: cap-kalite-install.sh
# ONELINER Download/Install: sudo wget https://github.com/rachelproject/rachelplus/raw/master/cap_ka-lite_install.sh -O /root/cap_ka-lite_install.sh; bash cap_ka-lite_install.sh

# Everything below will go to this log directory
TIMESTAMP=$(date +"%b-%d-%Y-%H%M%Z")
RACHELLOGDIR="/var/log/RACHEL"
mkdir -p $RACHELLOGDIR
RACHELLOGFILE="rachel-install.tmp"
RACHELLOG="$RACHELLOGDIR/$RACHELLOGFILE"
KALITEDIR="/var/ka-lite"

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

# Check internet connecivity
WGET=`which wget`
$WGET -q --tries=10 --timeout=5 --spider http://google.com 1>> $RACHELLOG 2>&1
if [[ $? -eq 0 ]]; then
    echo; print_good "Internet connected...continuing install." | tee -a $RACHELLOG
else
    echo; print_error "No internet connectivity; connect to the internet and try again."
    exit 1
fi

# Add header/date/time to install log file
echo; print_good "KA Lite Install Script - Version $(date +%m%d%y%H%M)" | tee $RACHELLOG
print_good "Install started: $(date)" | tee -a $RACHELLOG

# Let's install KA Lite under /var 
if [[ ! -d $KALITEDIR ]]; then
  echo; print_status "Cloning KA Lite from GitHub."
  git clone --recursive https://github.com/learningequality/ka-lite.git /var/ka-lite
else
  echo; print_status "KA Lite already exists; updating files."
  cd $KALITEDIR; git pull
fi

### FIX THIS - need the json file and the zip file below doesn't have it
# Assuming the assessmentitems.json is on a USB drive called USB
#cp /media/USB/assessmentitems.json  /var/ka-lite/data/khan
#wget https://learningequality.org/downloads/ka-lite/0.13/content/assessment.zip -O /media/RACHEL/assessment.zip
#cd /var/

# Linux setup of KA Lite
echo; print_status "Use the following inputs when answering the setup questions:"
echo "User - rachel" 
echo "Password (x2) - rachel"
echo "Name and describe server as desired"
echo "Download exercise pack? No"
echo "Already downloaded? Yes"
echo "Start at boot? No"
echo
./setup_unix.sh

# Configure ka-lite
echo 'CONTENT_ROOT = "/media/RACHEL/kacontent/"' >> /var/ka-lite/kalite/local_settings.py
mkdir -p /media/RACHEL/kacontent
cd /media/RACHEL/kacontent/

### FIX THIS - need content
# Assuming the ka-lite_content.zip is on a USB drive called USB
#unzip  /media/uploaded/data-khan/ka-lite_content.zip
#cd content
#mv -- * ..

# Delete previous setup commands from the /etc/rc.local
sudo sed -i '/ka-lite/d' /etc/rc.local
sudo sed -i '/sleep 20/d' /etc/rc.local

# Start KA Lite at boot time
sudo sed -i '$e echo "# Start ka-lite at boot time"' /etc/rc.local
sudo sed -i '$e echo "sleep 20"' /etc/rc.local
sudo sed -i '$e echo "/var/ka-lite/bin/kalite start"' /etc/rc.local
print_good "Done."

# Add RACHEL IP
print_good "Login at http://<RACHEL-IP>:8008 and register device"
echo; print_good "Log file saved to: $RACHELLOGDIR/rachel-kalite-$TIMESTAMP.log"
print_good "KA Lite Install Complete."
echo