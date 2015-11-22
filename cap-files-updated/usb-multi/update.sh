#!/bin/bash
#
# Original Author : Lu Ken (bluewish.ken.lu@****l.com)
# Modified by : Sam @ Hackers for Charity (hackersforcharity.org) and World Possible (worldpossible.org)
#
# USB CAP Multitool
# Description: This is the first script to run when the CAP starts up
# It will set the LED lights and setup the emmc and hard drive
#
# LED Status:
#    - During script:  Wireless breathe and 3G solid
#    - After success:  Wireless solid and 3G solid
#    - After fail:  Wireless fast blink and 3G solid
#
# Install Options:
#    - "Recovery" for end user CAP recovery (METHOD 1)
#        Copy boot, efi, and rootfs partitions to emmc
#        Rewrite the hard drive partition table
#        DO NOT format any hard drive partitions (set format_option to 0)
#    - "Imager" for large installs when cloning the hard drive (METHOD 2)
#        Copy boot, efi, and rootfs partitions to emmc
#        Don't touch the hard drive (since you will swap with a cloned one)
#    - "Format" for small installs and/or custom hard drive (METHOD 3)
#        *WARNING* This will erase all partitions on the hard drive */WARNING*
#        Copy boot, efi, and rootfs partitions to emmc
#        Rewrite the hard drive partition table
#        Format hard drive partitions (set format_option to 1)
#        Copy content shell to /media/RACHEL/rachel
#
# Stage RACHEL files on USB using the following commands:
#	cd <USB-Drive-Root>
#	git clone https://github.com/rachelproject/contentshell.git contentshell
#
VERSION="6"
TIMESTAMP=$(date +"%b-%d-%Y-%H%M%Z")
SCRIPT_ROOT="/boot/efi"
METHOD="3" # 1=Recovery (DEFAULT), 2=Imager, 3=Format

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1> $SCRIPT_ROOT/update.log 2>&1

echo; echo ">>>>>>>>>>>>>>> USB CAP Multitool - Version $VERSION - Started $(date) >>>>>>>>>>>>>>>"
echo; echo "BASH version:  $(echo $BASH_VERSION)"
echo "Multitool configured to run method:  $METHOD"
echo " -- 1=Recovery (DEFAULT), 2=Imager, 3=Format"

echo; echo "[*] Configuring LEDs."
$SCRIPT_ROOT/led_control.sh normal off
$SCRIPT_ROOT/led_control.sh breath on
#$SCRIPT_ROOT/led_control.sh issue on
$SCRIPT_ROOT/led_control.sh 3g on
echo "[+] Done."

command_status () {
	export EXITCODE="$?"
	if [[ $EXITCODE == 0 ]]; then
		echo "Command status:  OK"
		$SCRIPT_ROOT/led_control.sh breath off 
		$SCRIPT_ROOT/led_control.sh issue off 
		$SCRIPT_ROOT/led_control.sh normal on
	else
		echo "Command status:  FAIL"
		$SCRIPT_ROOT/led_control.sh breath off
		$SCRIPT_ROOT/led_control.sh issue on
	fi
}

backup_GPT () {
	echo; echo "[*] Current GUID Partition Table (GPT) for the hard disk /dev/sda:"
	sgdisk -p /dev/sda
	echo; echo "[*] Backing up GPT to $SCRIPT_ROOT/sda-backup-$TIMESTAMP.gpt"
	sgdisk -b $SCRIPT_ROOT/rachel-files/gpt/sda-backup-$TIMESTAMP.gpt /dev/sda
	echo "[+] Backup complete."
}

echo; echo "[*] METHOD $METHOD will now execute."
echo; echo "[*] Executing script:  $SCRIPT_ROOT/copy_partitions_to_emmc.sh"
$SCRIPT_ROOT/copy_partitions_to_emmc.sh $SCRIPT_ROOT

backup_GPT
if [[ $METHOD == 1 ]]; then
	echo; echo "[*] Executing script:  $SCRIPT_ROOT/init_content_hdd.sh, format option 0"
	$SCRIPT_ROOT/init_content_hdd.sh /dev/sda 0
	command_status
	echo; echo "[+] Ran METHOD 1."
elif [[ $METHOD == 2 ]]; then
	command_status
	echo; echo "[+] Ran METHOD 2."
elif [[ $METHOD == 3 ]]; then
	echo; echo "[*] Executing script:  $SCRIPT_ROOT/init_content_hdd.sh, format option 1"
	$SCRIPT_ROOT/init_content_hdd.sh /dev/sda 1
	echo; echo "[*] Mounting /dev/sda3"
	mkdir -p /mnt/RACHEL
	mount /dev/sda3 /mnt/RACHEL
	echo "[*] Copying RACHEL contentshell files to /dev/sda3"
	cp -r $SCRIPT_ROOT/rachel-files/contentshell /mnt/RACHEL/rachel
	cp $SCRIPT_ROOT/rachel-files/*.* /mnt/RACHEL/rachel/
	cp $SCRIPT_ROOT/rachel-files/art/*.* /mnt/RACHEL/rachel/art/
	command_status
	echo; echo "[+] Ran METHOD 3."
fi

echo; echo "[*] Copying log files to root of USB."
cp -rf /var/log $SCRIPT_ROOT/
sync
$SCRIPT_ROOT/led_control.sh 3g off
echo "[+] Done."

echo; echo "<<<<<<<<<<<<<< USB CAP Multitool - Completed $(date) <<<<<<<<<<<<<<<<"
