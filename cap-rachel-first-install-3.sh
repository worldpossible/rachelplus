#!/bin/sh
# FILE: cap-rachel-first-install-3.sh
# ONELINER Download/Install: sudo wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-first-install-3.sh -O - | bash 

# Everything below will go to the file '/var/log/rachel-install.log'
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>>/var/log/rachel-install.log 2>&1

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
echo; print_good "RACHEL CAP Install - Started $(date)"

# Delete previous setup commands from the /etc/rc.local
sudo sed -i '/cap-rachel/d' /etc/rc.local

# Check partitions
echo; print_status "Printing paritition table:"
df -h
echo; print_status "The partition table for /dev/sda should look very similar to the following:"
echo; print_status "     /dev/sda1        20G   44M   19G   1% /media/preloaded"
echo; print_status "     /dev/sda2        99G   60M   94G   1% /media/uploaded"
echo; print_status "     /dev/sda3       339G   67M  321G   1% /media/RACHEL"

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

# Add setwanip.sh script to run at boot
echo; print_status "Adding setwanip.sh script to autorun at startup"
sudo wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-setwanip-install.sh -O - | bash
print_good "Done."

# Install MySQL client and server
echo; print_status "Installing mysql client and server"
sudo cd /
sudo chown root:root /tmp
sudo chmod 1777 /tmp
sudo apt-get remove --purge mysql-server mysql-client mysql-common
sudo apt-get -y install mysql-server mysql-client libapache2-mod-auth-mysql php5-mysql
print_good "Done."

echo; print_status "Update mysql by copy & pasting the following commands into the mysql shell"
echo; echo "Run the following command to enter a mysql shell...then run the three MySQL commands"
echo "    mysql -u root -proot"
echo; echo "MySQL Commands:"
echo "    CREATE DATABASE sphider_plus;"
echo "    SHOW DATABASES;"
echo "    EXIT"
echo; print_status "If the script does not enter a mysql shell, please type 'mysql -u root -proot' and then enter the commands above."
echo; print_status "NOTE:  Please reboot once the mysql changes are complete."

# Deleting the install script commands
rm -f /root/cap-rachel-*
