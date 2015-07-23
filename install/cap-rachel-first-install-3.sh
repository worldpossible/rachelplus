#!/bin/sh
# FILE: cap-rachel-first-install-3.sh
# ONELINER Download/Install: sudo wget https://github.com/rachelproject/rachelplus/raw/master/install/cap-rachel-first-install-3.sh -O - | bash 

# Everything below will go to this log directory
TIMESTAMP=$(date +"%b-%d-%Y-%H%M%Z")
RACHELLOGDIR="/var/log/RACHEL"
mkdir -p $RACHELLOGDIR
RACHELLOGFILE="rachel-install.tmp"
RACHELLOG="$RACHELLOGDIR/$RACHELLOGFILE"
RACHELWWW="/media/RACHEL/rachel"
exec 1>> $RACHELLOG 2>&1

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
sudo mv /root/lighttpd.conf /usr/local/etc/lighttpd.conf
print_good "Done."

# Delete previous setwanip commands from /etc/rc.local
echo; print_status "Deleting previous setwanip.sh script from /etc/rc.local"
sudo sed -i '/setwanip/d' /etc/rc.local
print_good "Done."

# Delete previous iptables commands from /etc/rc.local
echo; print_status "Deleting previous iptables script from /etc/rc.local"
sudo sed -i '/iptables/d' /etc/rc.local
print_good "Done."

# Enable IP forwarding from 10.10.10.10 to 192.168.88.1 *NOT WORKING*
#echo 1 > /proc/sys/net/ipv4/ip_forward #might not need this line
	cat > /root/iptables-rachel.sh << 'EOF'
#!/bin/bash
# Add the RACHEL iptables rule to redirect 10.10.10.10 to CAP default of 192.168.88.1
# Added sleep to wait for CAP rcConf and rcConfd to finish initializing
#
sleep 60
iptables -t nat -A OUTPUT -d 10.10.10.10 -j DNAT --to-destination 192.168.88.1
EOF

# Add 10.10.10.10 redirect on every reboot
sudo sed -i '$e echo "# RACHEL iptables - Redirect from 10.10.10.10 to 192.168.88.1"' /etc/rc.local
#sudo sed -i '$e echo "iptables -t nat -A OUTPUT -d 10.10.10.10 -j DNAT --to-destination 192.168.88.1&"' /etc/rc.local
sudo sed -i '$e echo "bash /root/iptables-rachel.sh&"' /etc/rc.local

# Install MySQL client and server
echo; print_status "Installing mysql client and server"
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'
cd /
sudo chown root:root /tmp
sudo chmod 1777 /tmp
sudo apt-get -y remove --purge mysql-server mysql-client mysql-common
sudo apt-get -y install mysql-server mysql-client libapache2-mod-auth-mysql php5-mysql
print_good "Done."

# Clone or update the RACHEL content shell from GitHub
if [[ ! -d $RACHELWWW ]]; then
	echo; print_status "Cloning the RACHEL content shell from GitHub."
	git clone https://github.com/rachelproject/contentshell /media/RACHEL
else
	if [[ ! -d $RACHELWWW/.git ]]; then
		echo; print_status "RACHELWWW exists but it wasn't installed from git; installing RACHEL content shell from GitHub."
		rm -rf /media/RACHEL/rachel.contentshell # in case of previous failed install
		git clone https://github.com/rachelproject/contentshell /media/RACHEL/rachel.contentshell
		cp -rf /media/RACHEL/rachel.contentshell/* /media/RACHEL/rachel # overwrite current content with contentshell
		cp -rf /media/RACHEL/rachel.contentshell/.git /media/RACHEL/rachel/ # copy over GitHub files
		rm -rf /media/RACHEL/rachel.contentshell # remove contentshell temp folder
	else
		echo; print_status "RACHELWWW exists; updating RACHEL content shell from GitHub."
		cd $RACHELWWW; git pull
	fi
fi
print_good "Done."

# Download RACHEL Captive Portal redirect page
echo; print_status "Downloading Captive Portal content and moving a copy files."
if [[ ! -f $RACHELWWW/captiveportal-redirect.php ]]; then
	wget https://github.com/rachelproject/rachelplus/raw/master/captive-portal/captiveportal-redirect.php -O $RACHELWWW/captiveportal-redirect.php
	print_good "Downloaded $RACHELWWW/captiveportal-redirect.php."
else
	print_good "$RACHELWWW/art/captiveportal-redirect.php exists, skipping."
fi
if [[ ! -f $RACHELWWW/art/RACHELbrandLogo-captive.png ]]; then
	wget https://github.com/rachelproject/rachelplus/raw/master/captive-portal/RACHELbrandLogo-captive.png -O $RACHELWWW/art/RACHELbrandLogo-captive.png
	print_good "Downloaded $RACHELWWW/art/RACHELbrandLogo-captive.png."
else
	print_good "$RACHELWWW/art/RACHELbrandLogo-captive.png exists, skipping."
fi
if [[ ! -f $RACHELWWW/art/HFCbrandLogo-captive.jpg ]]; then
	wget https://github.com/rachelproject/rachelplus/raw/master/captive-portal/HFCbrandLogo-captive.jpg -O $RACHELWWW/art/HFCbrandLogo-captive.jpg
	print_good "Downloaded $RACHELWWW/art/HFCbrandLogo-captive.jpg."
else
	print_good "$RACHELWWW/art/HFCbrandLogo-captive.jpg exists, skipping."
fi
if [[ ! -f $RACHELWWW/art/WorldPossiblebrandLogo-captive.png ]]; then
	wget https://github.com/rachelproject/rachelplus/raw/master/captive-portal/WorldPossiblebrandLogo-captive.png -O $RACHELWWW/art/WorldPossiblebrandLogo-captive.png
	print_good "Downloaded $RACHELWWW/art/WorldPossiblebrandLogo-captive.png."
else
	print_good "$RACHELWWW/art/WorldPossiblebrandLogo-captive.png exists, skipping."
fi

# Copy over files needed for Captive Portal redirect to work (these are the same ones used by the CAP)
if [[ ! -f $RACHELWWW/pass_ticket.shtml && ! -f $RACHELWWW/redirect.shtml ]]; then
	cp /www/pass_ticket.shtml /www/redirect.shtml $RACHELWWW/.
else
	print_good "$RACHELWWW/pass_ticket.shtml and $RACHELWWW/redirect.shtml exist, skipping."
fi
print_good "Done."

# Deleting the install script commands
echo; print_status "Deleting the install scripts."
rm -f /root/cap-rachel-*
print_good "Done."

# Add header/date/time to install log file
sudo mv $RACHELLOG $RACHELLOGDIR/rachel-install-$TIMESTAMP.log
echo; print_good "Log file saved to: $RACHELLOGDIR/rachel-install-$TIMESTAMP.log"
print_good "RACHEL CAP Install Complete."

# Reboot
echo; print_status "I need to reboot; once rebooted, your CAP is ready for RACHEL content."
echo "Download modules from http://dev.worldpossible.org/mods/"
echo; print_status "Rebooting in 10 seconds..." 
sleep 10
reboot
