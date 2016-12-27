#!/bin/sh
# FILE: cap-rachel-first-install-3.sh
# ONELINER Download/Install: sudo wget https://github.com/rachelproject/rachelplus/raw/master/install/cap-rachel-first-install-3.sh -O - | bash 

# Import functions from /root/cap-rachel-configure.sh
. /root/cap-rachel-configure.sh --source-only
internet="1"
onlineVariables

# Logging
exec 1>> $rachelLog 2>&1

# Check root
if [ "$(id -u)" != "0" ]; then
  printError "This step must be run as root; sudo password is 123lkj"
  exit 1
fi

# Add header/date/time to install log file
echo; printGood "RACHEL CAP Install - Script 3 started at $(date)"

# Change directory into $installTmpDir
cd $installTmpDir

# Delete previous setup commands from the /etc/rc.local
sudo sed -i '/cap-rachel/d' /etc/rc.local

# Check partitions
echo; printStatus "Printing paritition table:"
df -h
echo; printStatus "The partition table for /dev/sda should look very similar to the following:"
# v1 CAPs post RACHEL Recovery USB v9 and v2 CAPs
echo "/dev/sda1       2.9G  4.5M  2.8G   1% /media/preloaded"
echo "/dev/sda2        17G   44M   16G   1% /media/uploaded"
echo "/dev/sda3       439G   71M  417G   1% /media/RACHEL"
# OLD v1 CAPs
#echo "/dev/sda1        20G   44M   19G   1% /media/preloaded"
#echo "/dev/sda2        99G   60M   94G   1% /media/uploaded"
#echo "/dev/sda3       339G   67M  321G   1% /media/RACHEL"

# Wait for network connection
pingTest(){
    ping -q -c 1 -W 1 google.com
}
pingTest 1>/dev/null 2>&1
while [[ $? -ge 1 ]]; do sleep 2; echo; printStatus "Waiting for network..."; pingTest; done
printGood "Network up...continuing install."

# Update CAP package repositories
echo; printStatus "Updating CAP package repositories"
for i in $(echo $gpgKeys); do $GPGKEY$i; done
apt-get clean; apt-get purge; apt-get update
printGood "Done."

# Install RACHEL required packages
echo; printStatus "Installing packages."
# Setup root password for mysql install
debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'
chown root:root /tmp
chmod 1777 /tmp
installPkgUpdates
# Force install of failed packages
apt-get -fy install
printGood "Done."

# Add the following line at the end of file
grep -q '^cgi.fix_pathinfo = 1' /etc/php5/cgi/php.ini && sed -i '/^cgi.fix_pathinfo = 1/d' /etc/php5/cgi/php.ini; echo 'cgi.fix_pathinfo = 1' >> /etc/php5/cgi/php.ini

# If $rachelWWW doesn't exist, set it up
cd $installTmpDir
if [[ ! -d $rachelWWW ]]; then
    echo; printStatus "Cloning the RACHEL content shell from GitHub into $(pwd)"
    rm -rf contentshell # in case of previous failed install
    $GITCLONERACHELCONTENTSHELL
    mv $installTmpDir/contentshell $rachelWWW
    printGood "Done."
else
    printError "RACHEL directory already exists, skipping."
fi

# Overwrite the lighttpd.conf file with our customized RACHEL version
echo; printStatus "Updating lighttpd.conf to RACHEL version"
$LIGHTTPDFILE
mv $installTmpDir/lighttpd.conf /usr/local/etc/lighttpd.conf
printGood "Done."

# Fixing $rachelScriptsFile
repairRachelScripts

# Remove outdated startup script - replaced by /root/rachel-scripts/rachelStartup.sh
rm -f /root/iptables-rachel.sh

# Delete previous setwanip commands from /etc/rc.local - not used anymore
echo; printStatus "Deleting previous setwanip.sh script from /etc/rc.local"
sed -i '/setwanip/d' /etc/rc.local
rm -f /root/setwanip.sh
printGood "Done."

# Delete previous iptables commands from /etc/rc.local - not used anymore
echo; printStatus "Deleting previous iptables script from /etc/rc.local"
sed -i '/iptables/d' /etc/rc.local
printGood "Done."

# Add battery monitor for safe shutdown
installBatteryWatch

# Add Kiwix library update script
createKiwixRepairScript

# Display currently mounted partitions
echo; printStatus "Listing currently mounted /dev/sda partitions."
mount | grep sda

# Add local content module
echo; printStatus "Adding the local content module."
echo "rsyncOnline=$rsyncOnline"
echo "Executing -> rsync -avz $rsyncOnline/rachelmods/en-local_content $rachelWWW/modules/" 
rsync -avz $rsyncOnline/rachelmods/en-local_content $rachelWWW/modules/
printGood "Done."

# update RACHEL installer version
if [[ ! -f /etc/rachelinstaller-version ]]; then $(cat /etc/version | cut -d- -f1 > /etc/rachelinstaller-version); fi
echo $(cat /etc/rachelinstaller-version | cut -d_ -f1)-$(date +%Y%m%d.%H%M) > /etc/rachelinstaller-version

# Deleting the install script commands
echo; printStatus "Deleting the install scripts."
rm -rf $installTmpDir $rachelTmpDir
printGood "Done."

# Add header/date/time to install log file
echo; printGood "RACHEL CAP Install - Script 3 of 3 ended at $(date)"
sudo mv $rachelLog $rachelLogDir/rachel-install-$timestamp.log
echo; printGood "Log file saved to: $rachelLogDir/rachel-install-$timestamp.log"
printGood "RACHEL CAP Install Complete."

# Reboot
echo; printStatus "I need to reboot; once rebooted, your CAP is ready for RACHEL content."
echo "Download modules from http://dev.worldpossible.org/mods/"
echo; printStatus "Rebooting..."
noCleanup=1
reboot
