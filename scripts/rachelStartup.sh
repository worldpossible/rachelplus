#!/bin/bash

# Send output to log file
rm -f /var/log/rachel/rachel-scripts.log
exec 1>> /var/log/rachel/rachel-scripts.log 2>&1
echo $(date) - Starting RACHEL script

# First boot
if [[ -f /root/rachel-scripts/firstboot.sh ]]; then
    echo $(date) - Running "firstboot" script
    bash /root/rachel-scripts/firstboot.sh
fi

# Run once
if [[ -f /media/RACHEL/runonce.sh ]]; then
    echo $(date) - Running "runonce" script
    bash /media/RACHEL/runonce.sh
fi

# Start kiwix on boot
echo $(date) - Starting kiwix
bash /root/rachel-scripts/rachelKiwixStart.sh

# Start kalite at boot time
echo $(date) - Starting kalite
sleep 20 # kalite needs full network to start up
         # (any way to speed up the network boot?)
sudo /usr/bin/kalite start

# Start battery monitoring
#echo $(date) - Starting battery monitor
#bash /root/rachel-scripts/batteryWatcher.sh &

# Check if we should disable reset button
echo $(date) - Checking if we should disable reset button
if [[ -f /root/rachel-scripts/disable_reset ]]; then killall reset_button; echo "Reset button disabled"; fi

# Start esp, our system for doing remote service
echo $(date) - Start esp process
php /root/rachel-scripts/esp-checker.php &

# Check for modules (simple check on boot for updated modules on attached USB)
if [[ $(lsblk | grep -E 'sdb|sdc|sdd') ]]; then
	echo; echo $(date) - Running "module update" script
	usbDrive=$(df -h | grep -E 'sdb1|sdc1|sdd1' | grep media | awk '{ print $1 }' | cut -d'/' -f3)
	if [[ $usbDrive != 0 ]]; then
		echo "[!] WARNING:  USB is *not* mounted."
		echo "[-] Attempting to mount the attached USB to /media/usb"
		mkdir /media/usb
		mount /dev/$usbDrive /media/usb
		if [[ $(df -h | grep $usbDrive | grep usb) ]]; then echo "[+] Mounted successfully."; else echo "[!] Mounting failed."; mountFail=1; fi
		if [[ $mountFail == 1 ]]; then
			echo "Run 'dmesg' to view CAP error log."
			echo "You can also check the RACHEL configure script log file (noted below) for other possible errors."
		else
			mountedUSB="/media/usb"
		fi
	else
		mountedUSB=$(lsblk | grep $usbDrive | awk '{ print $7 }')
	fi

	# Add module symlink for index.htmlf and correct permissions
	if [[ -d $mountedUSB/rachelmods ]]; then
		# Set 3G led light on to alert user that module update started
		bash /root/led_control.sh 3g on
		# Start module update
		rsync -avhP $mountedUSB/rachelmods/ /media/RACHEL/rachel/modules/
		# Add symlinks - when running the Recovery USB, symlinks are not permitted on FAT partitions, so we have to create them after recovery runs
		echo; echo "[-] Add symlink for en-local_content."
		installedMods=$(ls /media/RACHEL/rachel/modules)
		while IFS= read -r module; do
			ln -s /media/RACHEL/rachel/modules/$module/rachel-index.php /media/RACHEL/rachel/modules/$module/index.htmlf 2>/dev/null
			if [[ -f /media/RACHEL/rachel/modules/$module/finish_install.sh ]]; then bash /media/RACHEL/rachel/modules/$module/finish_install.sh; fi
		done <<< "$installedMods"
		find /media/RACHEL/rachel/modules/ -type d -print0 | xargs -0 chmod 0755
		find /media/RACHEL/rachel/modules/ -type f -print0 | xargs -0 chmod 0644
	else
		echo "[!] Mounted USB does not have a rachelmods folder...moving on."
	fi
	# Safely eject the attached USB
	sync
	eject $mountedUSB
	# Set 3G led light off to alert user that module transfer is complete
	#   and they can remove the USB
	bash /root/led_control.sh 3g off
fi

# And we're done
echo $(date) - RACHEL startup completed
exit 0