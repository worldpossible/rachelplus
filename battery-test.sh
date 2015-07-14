#!/bin/bash
##############################################################################
# Hackers for Charity (http://hackersforcharity.org/education)
# 
# Description:  This file is used to test duration of various batteries 
# running the device.  It will ask whether or not you wish to set the  
# date/time, then create a file named in the LOG variable relative to  
# the current folder.
#
# Usage: Ensure script is executable: "chmod +x ./battery-test.sh" and 
# then start the script once you remove all but the battery as a power
# source.  The script will continually update until power fails.  When you
# reboot, you can then read the log file (default: duration-results) to
# determine how long the battery lasted.
##############################################################################

# Change the following, if desired
VERSION=6 #script version
LOG="duration-results"  #default log file

echo; echo "### Battery Duration Test Script (sam@hfc) - Version $VERSION ###"; echo
# Do not change anything after this line
# Request if the user wants to set the log file
echo "[!] Current log file name: $PWD/$LOG"
read -r -p "[?] Do you want to rename your log file? [y/N] " response
response=${response,,}
if [[ $response =~ ^(yes|y)$ ]]
then
	echo "[?] What do you want to call your log file?"
	read LOG
	echo "[+] Log file created: $PWD/$LOG" | tee -a $LOG
else
	echo "[-] Using default log file: $PWD/$LOG" | tee -a $LOG
fi

# Request info to set the current date/time
echo; read -r -p "[?] Do you want to set the date/time?? [y/N] " response
response=${response,,}
if [[ $response =~ ^(yes|y)$ ]]; then
	if [[ -f `which ntpdate` ]]; then
		read -r -p "[?] Is this device connected to the internet? (y/n) " response
		if [[ $response =~ ^(yes|y)$ ]]; then
			echo "[+] ntpdate exists, attempting to set date/time automatically."
			ntpdate time.apple.com
			echo "[+] Done."
		else
			echo "[?] What is the current date/time (use this format --> Jul 5 08:10)?"
			read DATE
			sudo date -s "$DATE" >/dev/null 2>&1
			echo "[+] Using manually entered date/time"
		fi
	fi
else
	echo "[+] Using system date/time"
fi

# Sends initial test start comments to log file
echo; echo "[+] Battery Duration Test Script - Version $VERSION" | tee $LOG
STARTDATE=$(date +"%s")
echo "[+] Test Started:  $(date -d @$STARTDATE)" | tee -a $LOG 

# Monitors device for failure
#while :; do sed -i '/Power failure/d' $LOG; FAILDATE=$(date); echo "[-] Power failure:  "$FAILDATE >> $LOG; sleep 5; done
echo "[!] Monitoring for battery failure..."
echo "[!] Ctrl-C to exit"
while :; \
do sed -i '/Power failure/d' $LOG; \
sed -i '/Battery lasted/d' $LOG; \
FAILDATE=$(date +"%s"); \
echo "[-] Power failure:  "$(date -d @$FAILDATE) >> $LOG; \
DIFF=$(($FAILDATE-$STARTDATE)); \
REST=$(($DIFF%3600));
HOURS=$((($DIFF-$REST)/3600));
SECONDS=$(($REST%60));
MINUTES=$((($REST-$SECONDS)/60));
echo "[!] Battery lasted:  $HOURS hours, $MINUTES minutes, $SECONDS seconds" >> $LOG; \
sleep 5; \
done
