#!/bin/bash
#
# RACHEL Recovery USB
# Description: This is the first script to run when the CAP starts up
# and boots from USB. It will set the LED lights and setup the emmc and hard drive.
#
# LED Status:
#    - During script:  Wireless breathe and 3G solid
#    - After success:  Wireless solid and 3G no light
#    - After fail:  Wireless fast blink and 3G solid
#
# Install Options:
#    - "Recovery" for end user CAP recovery (method 1)
#        Copy boot, efi, and rootfs partitions to emmc
#        Rewrite the hard drive partition table
#        DO NOT format any hard drive partitions (set format_option to 0)
#    - "Imager" for large installs when cloning the hard drive (method 2)
#        Copy boot, efi, and rootfs partitions to emmc
#        Don't touch the hard drive (since you will swap with a cloned one)
#    - "AutoInstall" for auto install and/or custom hard drive (method 3)
#        *WARNING* This will erase all partitions on the hard drive */WARNING*
#        Copy boot, efi, and rootfs partitions to emmc
#        Rewrite the hard drive partition table
#        Format hard drive partitions (set format_option to 1)
#        Copy contentshell and rsync modules to /media/RACHEL/rachel
#

scriptRoot="/boot/efi"
. $scriptRoot/rachel-files/cap-rachel-configure.sh --source-only

# METHOD --> 1=Recovery (DEFAULT), 2=Imager, 3=AutoInstall
export method=1

firmwareVersion="2.2.15-rooted"
usbCreated="20170912.0152"
usbVersion="2.2.6"
timestamp=$(date +"%b-%d-%Y-%H%M%Z")

commandStatus(){
	export exitCode="$?"
	if [[ $exitCode == 0 ]]; then
		echo "Command status:  OK"
		$scriptRoot/led_control.sh breath off &> /dev/null
		$scriptRoot/led_control.sh issue off &> /dev/null
		$scriptRoot/led_control.sh normal on &> /dev/null
	else
		echo "Command status:  FAIL"
		$scriptRoot/led_control.sh breath off &> /dev/null
		$scriptRoot/led_control.sh issue on &> /dev/null
	fi
}

checkKA(){
	# Check KA Lite admin directory location
	# If $rootDir/.kalite is not a symlink, move KA Lite database to hard drive for speed increase and to prevent filling up the eMMC with user data
	echo; echo "[+] Checking that .kalite directory lives on hard disk"
	if [[ ! -L $rootDir/.kalite ]]; then
		echo; echo "[*] Need to move .kalite from eMMC to hard disk"
		sudo kalite stop
		echo; echo "[*] Before copying KA Lite folder - here is an 'ls' of $rachelPartition"
		ls -la $rachelPartition
		echo; echo "[+] Copying primary (.kalite) and backup (.kalite-backup) directory to $rachelPartition"
		if [[ -d $rachelPartition/.kalite ]]; then
			rm -rf $rachelPartition/.kalite-backup
			mv $rachelPartition/.kalite $rachelPartition/.kalite-backup
		else
			rm -rf $rachelPartition/.kalite
			cp -r $rootDir/.kalite $rachelPartition/.kalite-backup
		fi
		mv $rootDir/.kalite $rachelPartition/
		echo; echo "[*] After copying KA Lite folder - $rachelPartition (should list folders .kalite and .kalite-backup)"
		ls -la $rachelPartition
		echo; echo "[+] Symlinking $rootDir/.kalite to /media/RACHEL/.kalite"
		ln -s $rachelPartition/.kalite $rootDir/.kalite
		echo; echo "[+] Symlinking complete - $rootDir"
	else
		echo "[+] .kalite directory is located on the hard disk"
	fi
}

updateCore(){
	echo "[*] Add/update RACHEL contentshell files to /dev/sda3 (RACHEL web root)"
	rsync -avhP $rootDir/rachel-scripts/files/rachel/ /media/RACHEL/rachel/
	chmod +x $rachelPartition/rachel/*.shtml

	echo "[+] Updating RACHEL files"
    cp $scriptRoot/rachel-files/*.sh $rootDir/rachel-scripts/files/
    mv $rootDir/rachel-scripts/files/cap-rachel-configure.sh $rootDir/
	chmod +x $rootDir/cap-rachel-configure.sh

	echo; echo "[+] Core update complete"
}

mountPartitions(){
	# Mount root partition
	echo "[*] Mounting /dev/mmcblk0p4 (root partition)"
	mkdir /tmp/$$
	mount /dev/mmcblk0p4 /tmp/$$
	rootDir="/tmp/$$/root"

	# Mount RACHEL hard drive
	echo "[*] Mounting /dev/sda3 (RACHEL partition)"
	mkdir -p $rachelPartition
	mount /dev/sda3 $rachelPartition
}

unmountPartitions(){
	# Unmount all
	sync
	umount /dev/mmcblk0p4 /dev/sda3
	rm -rf /tmp/$$
}

copyPartitions(){
	# Check and copy partitions to CAP
	echo; echo "[*] Executing script:  $scriptRoot/copy_partitions_to_emmc.sh"
	$scriptRoot/copy_partitions_to_emmc.sh $scriptRoot
}

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1> $scriptRoot/update.log 2>&1

echo; echo ">>>>>>>>>>>>>>> RACHEL Recovery USB - Version $usbVersion - Started $(date) <<<<<<<<<<<<<<<"
echo "RACHEL/CAP Firmware Build:  $firmwareVersion"
echo "RACHEL Recovery USB Build Date:  $usbCreated"
echo "Bash Version:  $(echo $BASH_VERSION)"
echo "Recovery USB configured to run method:  $method"
echo " -- 1=Recovery (DEFAULT), 2=Imager, 3=AutoInstall"

echo; echo "[*] Updating LEDs."
$scriptRoot/led_control.sh normal off &> /dev/null
$scriptRoot/led_control.sh breath on &> /dev/null
#$scriptRoot/led_control.sh issue on &> /dev/null
$scriptRoot/led_control.sh 3g on &> /dev/null
echo "[+] Done."

echo; echo "[*] Method $method will now execute"

# here we mount the root partition and copy
# a couple files which allow us to override
# the auto-installation options
# (code borrowed from copy_partitions_to_emmc.sh)

# Run METHOD
if [[ $method == 1 ]]; then
	# Mount paritions to check KA Lite admin folder location
	mountPartitions
	checkKA
	unmountPartitions

	# Copy OS paritions to eMMC
	copyPartitions
	commandStatus

	# Copy OS partitions to eMMC
	echo; echo "[*] Executing script:  $scriptRoot/init_content_hdd.sh, format option 0"
	$scriptRoot/init_content_hdd.sh /dev/sda 0
	commandStatus

	# Running post-recovery
	echo; echo "[+] Running cap-rachel-configure.sh --usbrecovery"
	$rootDir/cap-rachel-configure.sh --usbrecovery
	commandStatus

	# Copying core content to the CAP and checking for files staged for copy to CAP
	echo; echo "[*] Updating core files/folders"
	mountPartitions
	commandStatus
	updateCore
	commandStatus
	echo; echo "[+] Ran method 1"
elif [[ $method == 2 ]]; then
	# Copy OS partitions to eMMC
	copyPartitions
	commandStatus
	echo; echo "[+] Ran method 2"
elif [[ $method == 3 ]]; then
	# Copy OS paritions to eMMC
	copyPartitions
	commandStatus

	# Format the hard drive
	echo; echo "[*] Executing script:  $scriptRoot/init_content_hdd.sh, format option 1"
	$scriptRoot/init_content_hdd.sh /dev/sda 1
	commandStatus

	# Copying core content to the CAP and checking for files staged for copy to CAP
	echo; echo "[*] Updating core files/folders"
	mountPartitions
	commandStatus
	updateCore
	commandStatus

	# Update additional files (used when needed)
	# cp $scriptRoot/rachel-files/rachelStartup.sh $rootDir/rachel-scripts/rachelStartup.sh
	# chmod +x $rootDir/rachel-scripts/rachelStartup.sh

	# cp $scriptRoot/rachel-files/battery_solve.sh /tmp/$$/etc/battery_solve.sh
	# chmod +x /tmp/$$/etc/battery_solve.sh

	# Update autoinstall files
	cp $scriptRoot/rachel-autoinstall.* $rootDir/rachel-scripts/files
	echo; echo "[+] Ran method 3"
fi

# Copy rachelinstaller version to disk
#echo $usbVersion > $rachelPartition/rachelinstaller-version
echo $usbVersion > /tmp/$$/etc/rachelinstaller-version

# Unmount all partitions
unmountPartitions

# Disabled copy of logs; not used
#echo; echo "[*] Copying log files to root of USB"
#cp -rf /var/log $scriptRoot/
sync
echo; echo "[*] Updating LEDs."
$scriptRoot/led_control.sh 3g off &> /dev/null
echo "[+] Done."

echo; echo ">>>>>>>>>>>>>>> RACHEL Recovery USB - Completed $(date) <<<<<<<<<<<<<<<"