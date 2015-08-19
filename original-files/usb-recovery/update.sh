#!/bin/sh

echo ">>>>>>>>>>>>>>> Update Start >>>>>>>>>>>>>>>"
SCRIPT_ROOT="/boot/efi/"

#
# Put your update script here
#
$SCRIPT_ROOT/led_control.sh normal off
$SCRIPT_ROOT/led_control.sh breath on
#$SCRIPT_ROOT/led_control.sh issue on
$SCRIPT_ROOT/led_control.sh 3g on

echo "Call partition update script"
$SCRIPT_ROOT/copy_partitions_to_emmc.sh $SCRIPT_ROOT
$SCRIPT_ROOT/init_content_hdd.sh /dev/sda
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

echo "Copy log files"
cp /var/log $SCRIPT_ROOT/ -fr
sync

echo "<<<<<<<<<<<<<< Update Over <<<<<<<<<<<<<<<<"
