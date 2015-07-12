#!/bin/sh
# FILE: cap-rachel-first-install-3.sh
# ONELINER Download/Install: sudo wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-first-install-3.sh -O - | bash 

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
if [ "$(id -u)" == "0" ]; then
  print_error "This step must NOT be run as root"
  exit 1
fi

# Check partitions
echo; print_status "Printing paritition table"
df -h
print_status "Example of correct partition scheme:"
echo
echo "    root@WRTD-303N-Server:~# df -h"
echo "    Filesystem      Size  Used Avail Use% Mounted on"
echo "    /dev/mmcblk0p4  5.3G  1.4G  3.7G  27% /"
echo "    udev            943M   12K  943M   1% /dev"
echo "    tmpfs           383M  456K  382M   1% /run"
echo "    none            5.0M     0  5.0M   0% /run/lock"
echo "    none            956M     0  956M   0% /run/shm"
echo "    /dev/mmcblk0p3  181M  102M   71M  60% /boot"
echo "    /dev/mmcblk0p5  992M  1.3M  940M   1% /recovery"
echo "    /dev/sda1        20G   44M   19G   1% /media/preloaded"
echo "    /dev/sda2        99G   60M   94G   1% /media/uploaded"
echo "    /dev/sda3       339G   42G  280G  14% /media/RACHEL"
echo "    /dev/mmcblk0p2   94M   54M   41M  57% /boot/efi"
echo
echo; read -rsp $'[?] Confirm new partitions are correct and then press any key to continue or Ctrl-C to exit...\n' -n1 key

echo; print_good "Great! Moving on..."
echo; print_status "Installing PHP"
# install packages
sudo apt-get -y install php5-cgi git-core python-m2crypto
# add the following line at the end of file
sudo echo "cgi.fix_pathinfo = 1" >> /etc/php5/cgi/php.ini
print_good "Done."

echo; print_status "Updating lighttpd.conf to RACHEL version"
sudo wget https://github.com/rachelproject/rachelplus/raw/master/lighttpd.conf -O /usr/local/etc/lighttpd.conf
print_good "Done."

echo; print_status "Installing mysql client and server"
sudo cd /
sudo chown root:root /tmp
sudo chmod 1777 /tmp
sudo apt-get remove --purge mysql-server mysql-client mysql-common
sudo apt-get -y install mysql-server mysql-client libapache2-mod-auth-mysql php5-mysql
print_good "Done."

echo; print_status "Update mysql by copy & pasting the following commands into the mysql shell:"
echo "    CREATE DATABASE sphider_plus;"
echo "    SHOW DATABASES;"
echo "    EXIT"
echo
mysql -u root -proot
