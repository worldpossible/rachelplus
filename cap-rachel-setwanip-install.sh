#!/bin/bash
##############################################################################
# Hackers for Charity (http://hackersforcharity.org/education)
# setwanip.sh Setup Script (sam@hfc)
#
# Description:  Sets WAN IP in index.php for RACHEL to eth0 IP (set by
# DHCP or to the default IP of 192.168.88.1.
#
# Usage: You only need to run this script one time. Cut and paste or just
# run this script to set the IPs in the index.html file to the current IP
# on the eth0 interface. Once run, you must leave the script in the
# scripts folder located here:  /root/setwanip.sh
##############################################################################

# Everything below will go to the file '/var/log/cap-rachel-install.log'
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>>/var/log/cap-rachel-install.log 2>&1

cat > /root/setwanip.sh << 'EOF'
#!/bin/bash
newip=$(/sbin/ifconfig |grep -A1 "eth0"| awk '{ if ( $1 == "inet" ) { print $2 }}'|cut -f2 -d":")
if [[ -z "$newip" ]]
then
	sed -i -r 's/(\b[0-9]{1,3}\.){3}[0-9]{1,3}\b'/192.168.88.1/ /media/RACHEL/rachel/index.php
	sed -i -r 's/(\b[0-9]{1,3}\.){3}[0-9]{1,3}\b'/192.168.88.1/ /media/RACHEL/rachel/captiveportal-redirect.html
else
	sed -i -r 's/(\b[0-9]{1,3}\.){3}[0-9]{1,3}\b'/$newip/ /media/RACHEL/rachel/index.php
	sed -i -r 's/(\b[0-9]{1,3}\.){3}[0-9]{1,3}\b'/$newip/ /media/RACHEL/rachel/captiveportal-redirect.html
fi
EOF
chmod +x /root/setwanip.sh
sudo sed -i '$e echo "# RACHEL - Set file IPs to the current WAN IP"' /etc/rc.local
sudo sed -i '$e echo "bash \/root\/setwanip.sh&"' /etc/rc.local
