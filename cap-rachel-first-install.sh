
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

# Delete previous setup commands from the /etc/rc.local
sudo sed -i '/cap-rachel/d' /etc/rc.local

# Add header/date/time to install log file
echo; print_good "RACHEL CAP Install - Started $(date)" | tee $RACHELLOG

echo; print_status "Downloading RACHLEL install scripts for CAP" | tee -a $RACHELLOG
# Download additional scripts to /root
echo; print_status "Downloading RACHLEL install scripts for CAP" | tee -a $RACHELLOG
## cap-rachel-first-install-1.sh
sudo wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-first-install-1.sh -O /root/cap-rachel-first-install-1.sh | tee -a $RACHELLOG
print_good "Done." | tee -a $RACHELLOG
## cap-rachel-first-install-2.sh
sudo wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-first-install-2.sh -O /root/cap-rachel-first-install-2.sh | tee -a $RACHELLOG
print_good "Done." | tee -a $RACHELLOG
## cap-rachel-first-install-3.sh
sudo wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-first-install-3.sh -O /root/cap-rachel-first-install-3.sh | tee -a $RACHELLOG
print_good "Done." | tee -a $RACHELLOG
## cap-rachel-setwanip-install.sh
sudo wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-setwanip-install.sh -O /root/cap-rachel-setwanip-install.sh | tee -a $RACHELLOG
print_good "Done." | tee -a $RACHELLOG
echo; print_good "All downloads complete" | tee -a $RACHELLOG

# Show location of the log file
echo; print_status "Location of RACHEL install log file:" | tee -a $RACHELLOG
echo "$RACHELLOG" | tee -a $RACHELLOG

# Ask if you are ready to install
echo; read -p "Are you ready to start the install? " -n 1 -r <&1
if [[ $REPLY =~ ^[Yy]$ ]]; then
	echo; print_status "Starting first install script..." | tee -a $RACHELLOG
	bash /root/cap-rachel-first-install-1.sh
else
	echo; print_error "User requests not to continue...exiting at $(date)" | tee -a $RACHELLOG
	echo; exit 1
fi
