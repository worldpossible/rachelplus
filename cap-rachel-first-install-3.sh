#!/bin/sh
# FILE: cap-rachel-first-install-3.sh
# ONELINER Download/Install: sudo wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-first-install-3.sh -O - | bash 

# Everything below will go to this log directory
RACHELLOGDIR="/var/log/RACHEL"
RACHELLOGFILE="rachel-install.tmp"
RACHELLOG="$RACHELLOGDIR/$RACHELLOGFILE"

exec 1>> $RACHELLOG 2>&1

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

# Add header/date/time to install log file
echo; print_good "RACHEL CAP Install - Script 3 started at $(date)"

# Delete previous setup commands from the /etc/rc.local
sudo sed -i '/cap-rachel/d' /etc/rc.local

# Check partitions
echo; print_status "Printing paritition table:"
df -h
echo; print_status "The partition table for /dev/sda should look very similar to the following:"
echo "/dev/sda1        20G   44M   19G   1% /media/preloaded"
echo "/dev/sda2        99G   60M   94G   1% /media/uploaded"
echo "/dev/sda3       339G   67M  321G   1% /media/RACHEL"

# Install packages
echo; print_status "Installing PHP"
sudo apt-get -y install php5-cgi git-core python-m2crypto
# Add the following line at the end of file
sudo echo "cgi.fix_pathinfo = 1" >> /etc/php5/cgi/php.ini
print_good "Done."

# Overwrite the lighttpd.conf file with our customized RACHEL version
echo; print_status "Updating lighttpd.conf to RACHEL version"
sudo wget https://github.com/rachelproject/rachelplus/raw/master/lighttpd.conf -O /usr/local/etc/lighttpd.conf
print_good "Done."

# Delete previous setwanip commands from /etc/rc.local
echo; print_status "Deleting previous setwanip.sh script from /etc/rc.local"
sudo sed -i '/setwanip/d' /etc/rc.local
print_good "Done."

# Add setwanip.sh script to run at boot
echo; print_status "Adding setwanip.sh script to autorun at startup"
sudo wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-setwanip-install.sh -O - | bash
print_good "Done."

# Enable IP forwarding from 10.10.10.10 to 192.168.88.1
#echo 1 > /proc/sys/net/ipv4/ip_forward #might not need this line
iptables -t nat -A OUTPUT -d 10.10.10.10 -j DNAT --to-destination 192.168.88.1
# Add 10.10.10.10 redirect on every reboot
sudo sed -i '$e echo "iptables -t nat -A OUTPUT -d 10.10.10.10 -j DNAT --to-destination 192.168.88.1&"' /etc/rc.local

# Install MySQL client and server
echo; print_status "Installing mysql client and server"
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'
cd /
sudo chown root:root /tmp
sudo chmod 1777 /tmp
sudo apt-get remove --purge mysql-server mysql-client mysql-common
sudo apt-get -y install mysql-server mysql-client libapache2-mod-auth-mysql php5-mysql
print_good "Done."

# Deleting the install script commands
rm -f /root/cap-rachel-*

# Add header/date/time to install log file
TIMESTAMP=$(date +"%b-%d-%Y-%R-%Z")
sudo mv $RACHELLOG $RACHELLOGDIR/rachel-install-$TIMESTAMP.log
echo; print_good "Log file saved to: /var/log/rachel-install-$TIMESTAMP.log"
print_good "RACHEL CAP Install Complete - device is ready for RACHEL content."
