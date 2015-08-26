#!/bin/sh

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
#        Rewrite the hard drive partitions
#        DO NOT format any hard drive partitions
#    - "Imager" for large installs when cloning the hard drive (METHOD 2)
#        Copy boot, efi, and rootfs partitions to emmc
#        Don't touch the hard drive (since you will swap with a cloned one)
#    - "Format" for small installs and/or custom hard drive (METHOD 3)
#        *WARNING* This will erase all partitions on the hard drive */WARNING*
#        Copy boot, efi, and rootfs partitions to emmc
#        Rewrite the hard drive partitions
#        Format hard drive partitions
#        Copy content shell to /media/RACHEL/rachel
#

echo ">>>>>>>>>>>>>>> Update Start >>>>>>>>>>>>>>>"
METHOD="3" # 1=Recovery (DEFAULT), 2=Imager, 3=Format
SCRIPT_ROOT="/boot/efi/"

#
# Put your update script here
#
$SCRIPT_ROOT/led_control.sh normal off
$SCRIPT_ROOT/led_control.sh breath on
#$SCRIPT_ROOT/led_control.sh issue on
$SCRIPT_ROOT/led_control.sh 3g on

function command_status () {
	if [ $? -eq 0 ]; then
	    echo OK
	    $SCRIPT_ROOT/led_control.sh breath off 
	    $SCRIPT_ROOT/led_control.sh issue off 
	    $SCRIPT_ROOT/led_control.sh normal on
	else
	    echo FAIL
	    $SCRIPT_ROOT/led_control.sh breath off
	    $SCRIPT_ROOT/led_control.sh issue on
	fi
}

echo "Call partition update script"
$SCRIPT_ROOT/copy_partitions_to_emmc.sh $SCRIPT_ROOT
if [[ $METHOD="1" ]]; then
	$SCRIPT_ROOT/init_content_hdd.sh /dev/sda
	command_status
elif [[ $METHOD="2" ]]; then
	command_status
elif [[ $METHOD="3" ]]; then
	$SCRIPT_ROOT/init_format_content_hdd.sh /dev/sda
	mkdir -p /mnt/RACHEL
	mount /dev/sda3 /mnt/RACHEL
	cp -r $SCRIPT_ROOT/contentshell /mnt/RACHEL/rachel
	command_status
fi

echo "Copy log files"
cp -rf /var/log $SCRIPT_ROOT/
sync

echo "<<<<<<<<<<<<<< Update Over <<<<<<<<<<<<<<<<"
