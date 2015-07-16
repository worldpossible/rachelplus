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

# ONELINER Download/Install: sudo wget https://github.com/rachelproject/rachelplus/raw/master/battery-test.sh -O /root/battery-test.sh 

# Change the following, if desired
VERSION=8 #script version
RACHELLOGDIR="/var/log/RACHEL"
LOGFILE="duration-results.log"  #default log filename
LOG="$RACHELLOGDIR/$LOGFILE" #full path to log file

# Do not change anything below unless you know what you are doing

# Create temp file
TMP=`mktemp -t battery-test.tmpXXX`

# Function that will remove the temp file on start; program continues to run until system shuts down
function finish {
	rm -rf "$TMP"
}

# Save the previous logfile, if found
if [[ -f $LOG ]]; then
	mv $LOG $LOG.bak
	echo; echo "[+] Backup of previously run test saved to $LOG.bak"
fi

# Identify the script we are running
echo; echo "### Battery Duration Test Script (sam@hfc) - Version $VERSION ###"; echo

# Request if the user wants to set the log file
echo "[!] Current log file name: $LOG"
echo; read -p "[?] Do you want to rename your log file? (y/n) " -n 1 -r
if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
	echo; echo "[?] What is the full path to your log file?"
	read LOG
	echo "[+] Log file created: $LOG"
else
	echo; echo "[-] Using default log file: $LOG"
fi

# Request info to set the current date/time
echo; echo "[+] Current date/time:  "$(date)
echo; read -p "[?] Do you want to set the date/time? (y/n) " -n 1 -r
if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
	if [[ -f `which ntpdate` ]]; then
		echo; echo; read -p "[?] Is this device connected to the internet? (y/n) " -n 1 -r
		if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
			echo "[+] ntpdate exists, attempting to set date/time automatically."
			ntpdate time.apple.com
			echo "[+] Time automatically set to: "$(date)
		else
			echo "[?] What is the current date/time (use this format --> Jul 5 08:10)? "
			read DATE
			sudo date -s "$DATE" >/dev/null 2>&1
			echo "[+] Using manually entered date/time"
		fi
	fi
else
	echo; echo "[+] Using system date/time"
fi

# Sends initial test start comments to log file
echo; echo "[+] Battery Duration Test Script - Version $VERSION" > $LOG
export STARTDATE=$(date +"%s")
echo "[+] Test Started:  $(date -d @$STARTDATE)" >> $LOG

# Create tmp file that will monitor battery in background

LOGTEMP=`mktemp`
sed "s,%LOGTEMP%,$LOGTEMP,g; s,%LOG%,$LOG,g" >$TMP << 'EOF'
#!/bin/bash
while :; do
	FAILDATE=$(date +"%s")
	echo "[-] Power failure:  "$(date -d @$FAILDATE) > %LOGTEMP%
	DIFF=$(($FAILDATE-$STARTDATE))
	REST=$(($DIFF%3600))
	HOURS=$((($DIFF-$REST)/3600))
	SECONDS=$(($REST%60))
	MINUTES=$((($REST-$SECONDS)/60))
	echo "[!] Battery lasted:  $HOURS hours, $MINUTES minutes, $SECONDS seconds" >> %LOGTEMP%
	sleep 5
	sed -i '/Power failure/d' %LOG%
	sed -i '/Battery lasted/d' %LOG%
	cat %LOGTEMP% >> %LOG%
done
EOF

# Start tmp file to monitor for battery failure
bash $TMP&
sleep 2
trap finish EXIT
echo "[!] Monitoring for battery failure...please remember to disconnect the power to the device under testing."
echo
