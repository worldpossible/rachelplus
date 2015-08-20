#!/bin/bash

echo "clean up..."

ifconfig eth0 down

#
# clean the database for content hub
# 
rm /srv/easyconnect/db.sqlite3

#
# remove udev for ethernet 
#
rm /etc/udev/rules.d/70-persistent-net.rules

#
# clean the wireless MAC address
#
objReq sys setparam wanMacAddr 0

#
# clean the SSID
#
#redis-cli del WlanSsidT0_ssid

sync

sleep 3

echo "Start generate images"

#
# generate the recovery images
#
/root/disk_tools/extract_partitions_from_target.sh /recovery/

sync

sleep 3

echo "Finish generation"

ifconfig eth0 up
