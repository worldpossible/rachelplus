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
