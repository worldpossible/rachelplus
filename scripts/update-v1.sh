#!/bin/sh

# Choose the appropriate recovery method:
#
#   Method 1 : "Recovery" (DEFAULT)
#             Rewrite the eMMC only - this should fix problems where the
#             device will not boot by replacing the firmware and system
#             software to original settings. RACHEL content (on the
#             /media/RACHEL partition) will not be touched.
#
#   Method 2 : Unused option (historically, "Imager")
#
#   Method 3 : "Format" 
#             Completely rewrite BOTH the eMMC and /media/RACHEL partition.
#             This will WIPE EVERYTHING from the device and leave you with
#             an empty RACHEL device. You will then need to download content.
#             This is the method used to create brand new RACHEL devices,
#             followed by module installation through the RACHEL Admin.
#

# Set the method here:
method="1"

echo ">>>>>>>>>>>>>>> Update Start >>>>>>>>>>>>>>>"
firmwareVersion="1.2.24-root"
usbCreated="20170918.0826"
usbVersion="1.2.1"
scriptRoot="/boot/efi/"
rachelPartition="/media/RACHEL"

# Logging
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1> $scriptRoot/update.log 2>&1

#
# Put your update script here
#
$scriptRoot/led_control.sh normal off
$scriptRoot/led_control.sh breath on
#$scriptRoot/led_control.sh issue on
$scriptRoot/led_control.sh 3g on

checkKA(){
    # Check KA Lite admin directory location
    # If /tmp/$$/root/.kalite is not a symlink, move KA Lite database to 
    #   hard drive for speed increase and to prevent filling up the eMMC with user data
    echo; echo "[+] Checking that .kalite directory lives on hard disk"
    if [[ -d  "/tmp/$$/root/.kalite" ]]; then
        if [[ ! -L "/tmp/$$/root/.kalite" ]]; then
            echo; echo "[*] Need to move .kalite from eMMC to hard disk"
            sudo kalite stop
            echo; echo "[*] Before copying KA Lite folder - here is an 'ls' of $rachelPartition"
            ls -la $rachelPartition
            echo; echo "[+] Copying primary (.kalite) directory to $rachelPartition"
            if [[ -d $rachelPartition/.kalite ]]; then
                rm -rf $rachelPartition/.kalite
            fi
            mv /tmp/$$/root/.kalite $rachelPartition/
            echo; echo "[*] After copying KA Lite folder - $rachelPartition (should list folders .kalite)"
            ls -la $rachelPartition
            echo; echo "[+] Symlinking /tmp/$$/root/.kalite to /media/RACHEL/.kalite"
            ln -s $rachelPartition/.kalite /tmp/$$/root/.kalite
            ls -la /tmp/$$/root/.kalite
            echo; echo "[+] Symlinking complete"
        else
            echo "[+] .kalite directory is located on the hard disk"
        fi
    else
        echo "[!] Neither the KA Lite directory nor symlink found!"
        cp -r /tmp/$$/root/rachel-scripts/files/.kalite $rachelPartition
    fi
}

checkRACHEL(){
    echo; echo "[+] Updating RACHEL partition"
    rsync -avhP /tmp/$$/root/rachel-scripts/files/rachel/ $rachelPartition/rachel
}

mountRoot(){
    # Mount root partition
    echo; echo "[*] Mounting /dev/mmcblk0p4 (root partition)"
    mkdir /tmp/$$
    mount /dev/mmcblk0p4 /tmp/$$
}

mountRACHEL(){
    # Mount RACHEL hard drive
    echo; echo "[*] Mounting /dev/sda3 (RACHEL partition)"
    mkdir $rachelPartition
    mount /dev/sda3 $rachelPartition
}

unmountPartitions(){
    # Unmount all
    umount /dev/mmcblk0p4 /dev/sda3
}

echo "[*] Call partition update script"
if [ $method -eq 1 ]; then
    mountRoot
    mountRACHEL
    checkKA
    checkRACHEL
    unmountPartitions
    $scriptRoot/copy_partitions_to_emmc.sh $scriptRoot
    mountRoot
    mv /tmp/$$/root/rachel-scripts/firstboot.sh /tmp/$$/root/rachel-scripts/firstboot.sh.done
    cp $scriptRoot/rachelStartup.sh /tmp/$$/root/rachel-scripts
    cp $scriptRoot/83-mountstorage.rules /tmp/$$/etc/udev/rules.d
    cp $scriptRoot/cap-rachel-configure.sh /tmp/$$/root
    chmod +x /tmp/$$/root/cap-rachel-configure.sh /tmp/$$/root/rachel-scripts/rachelStartup.sh
    unmountPartitions
    $scriptRoot/init_content_hdd.sh /dev/sda 0
elif [ $method -eq 3 ]; then
    $scriptRoot/copy_partitions_to_emmc.sh $scriptRoot
    $scriptRoot/init_content_hdd.sh /dev/sda 1
    # here we mount the root partition and copy
    # a couple files which allow us to override
    # the auto-installation options
    # (code borrowed from copy_partitions_to_emmc.sh)
    mountRoot
    cp $scriptRoot/rachel-autoinstall.* /tmp/$$/root/rachel-scripts/files
    cp $scriptRoot/rachelStartup.sh /tmp/$$/root/rachel-scripts
    unmountPartitions
fi
echo ">>>>>>>>>>>>>>> Change status >>>>>>>>>>>>>>>"
if [ $? -eq 0 ]; then
    echo "OK"
    $scriptRoot/led_control.sh breath off 
    $scriptRoot/led_control.sh issue off 
    $scriptRoot/led_control.sh normal on
else
    echo "FAIL"
    $scriptRoot/led_control.sh breath off
    $scriptRoot/led_control.sh issue on
fi

#echo "Copy log files"
#cp /var/log $scriptRoot/ -fr
sync

echo "<<<<<<<<<<<<<< Update Over <<<<<<<<<<<<<<<<"
exit 0
