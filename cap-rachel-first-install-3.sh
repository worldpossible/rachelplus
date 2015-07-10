#!/bin/sh
# cap-rachel-first-install-3.sh

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
echo; read -rsp $'[?] Confirm new partitions are correct and then press any key to continue or Ctrl-C to exit...\n' -n1 key

echo; print_good "Great! Moving on..."
echo; print_status "Installing PHP"
# install packages
sudo apt-get -y install php5-cgi git-core python-m2crypto
# add the following line at the end of file
sudo echo "cgi.fix_pathinfo = 1" >> /etc/php5/cgi/php.ini
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
