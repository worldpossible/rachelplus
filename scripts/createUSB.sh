#!/bin/bash
# RACHEL Recovery USB Image Creation Script
# By: sam@hfc
# Usage:  ./createUSB.sh

printGood(){
	echo -e "\x1B[01;32m[+]\x1B[0m $1"
}

printError(){
	echo -e "\x1B[01;31m[-]\x1B[0m $1"
}

printStatus(){
	echo -e "\x1B[01;35m[*]\x1B[0m $1"
}

printQuestion(){
	echo -e "\x1B[01;33m[?]\x1B[0m $1"
}

version=2.1.9
timestamp=$(date +"%Y%m%d.%H%M")
usbDate=$(date +"%Y%m%d")
imageSavePath="$HOME"
imageSavePathCAP="/media/RACHEL/recovery"
installTmpDir="/root/cap-rachel-install.tmp"
rachelPartition="/media/RACHEL"
rachelWWW="$rachelPartition/rachel"
rachelScriptsDir="/root/rachel-scripts"
rachelTmpDir="/media/RACHEL/cap-rachel-install.tmp"
rachelRecoveryDir="/media/RACHEL/recovery"
rsyncDIR="rsync://dev.worldpossible.org"

loggingStart(){
	if [[ $os == "cap_v1" ]] || [[ $os == "cap_v2" ]]; then
		createLog="/media/RACHEL/recovery/createUSB-$timestamp.log"
	else
		createLog="./createUSB-$timestamp.log"
	fi
	exec &> >(tee "$createLog")
}

identifyOS(){
	if [[ $(cat /etc/hostname) == "WRTD-303N-Server" ]]; then
		os=cap_v1
	elif [[ $(cat /etc/hostname) == "WAPD-235N-Server" ]]; then
		os=cap_v2
	elif [[ -f /etc/issue ]]; then
		os=linux
	elif [[ -d /Volumes ]]; then
		os=osx
	else
		echo; printError "Your OS is unknown; sorry, I can not continue."
		echo; exit 1
	fi
}

identifySavePath(){
	if [[ $os == "cap_v1" ]] || [[ $os == "cap_v2" ]]; then
		imageSavePath=$imageSavePathCAP
	else
		imageSavePath=$imageSavePath
	fi
	printGood "Saving image to $imageSavePath"
}

identifyUSBVersion(){
    usbVersion=$usbDate
	if [[ $os == "cap_v1" ]]; then 
        imageName="CAPv1_RACHEL_Recovery_USB_$usbDate.img"
	elif [[ $os == "cap_v2" ]]; then
        imageName="CAPv2_RACHEL_Recovery_USB_$usbDate.img"
	else 
		printQuestion "What model of CAP (v1 or v2) are you creating an recovery image for?"
	    select menu in "CAPv1" "CAPv2"; do
			case $menu in
			CAPv1)
				imageName="CAPv1_RACHEL_Recovery_USB_$usbDate.img"
			;;
			CAPv2)
			    imageName="CAPv2_RACHEL_Recovery_USB_$usbDate.img"
			;;
			esac
	    done
	fi
	printGood "Image name:  $imageName"
}

identifyDeviceNum(){
	# Identify the device name
	if [[ $os == "linux" ]] || [[ $os == "cap_v1" ]] || [[ $os == "cap_v2" ]]; then
		echo; printStatus "List of currently mounted USB devices:"
		lsblk|grep -v mmc|grep -v sda
		echo; printQuestion "What is the device name that you want to image (for /dev/sdb, enter 'sdb')? "; read diskNum
		usbDeviceName="/dev/$diskNum"
	elif [[ $os == "osx" ]]; then
		diskutil list
		echo; printQuestion "What is the number of the device that you want to image (for /dev/disk1, enter '1')? "; read diskNum
		usbDeviceName="/dev/disk$diskNum"
	fi
	echo; printGood "Device name:  $usbDeviceName"
}

confirmRecoveryUSB(){
	# Confirm RACHEL Recovery USB
	echo; printStatus "Confirming the USB is a RACHEL Recovery USB."
	if [[ $os == "linux" ]] || [[ $os == "cap_v1" ]] || [[ $os == "cap_v2" ]]; then
		mountName=$(mount | grep "$usbDeviceName"1 | awk '{print $3}')
	elif [[ $os == "osx" ]]; then
		mountName=$(mount | grep "$usbDeviceName"s1 | awk '{print $3}')
	fi
	if [[ -z $mountName ]]; then
		echo; printError "I couldn't find a mounted USB for that disk, exiting."
		echo; exit 1
	fi
	# Check for update.sh; if not found, exit
	if [[ ! -f $mountName/update.sh ]]; then
		echo; printError "This does not appear to be a valid RACHEL Recovery USB; 'update.sh' was not found."
		printQuestion "Would you like to prepare this USB as a RACHEL Recovery USB? "; read REPLY
		if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
			# Add ability to create a USB from scratch using git pull?
			cd $mountName
			git clone https://github.com/rachelproject/usbrecoveryshell.git
			cp -r usbrecoveryshell/ .
			rmdir usbrecoveryshell
		else
			echo; exit 1
		fi
	else
		printGood "This is a RACHEL Recovery USB."
	fi
}

sanitize(){
	# Remove history, clean logs
	echo; printStatus "Sanitizing log files."
	# Clean log files and possible test scripts
	rm -rf /var/log/rachel-install* /var/log/RACHEL/* /var/log/rachel/* /root/test.sh
	# Clean previous cached logins from ssh
	rm -f /root/.ssh/known_hosts
	# Clean off ka-lite_content.zip (if exists)
	rm -f /media/RACHEL/ka-lite_content.zip
	# Clean previous files from running the generate_recovery.sh script 
	rm -rf /recovery/20* $rachelRecoveryDir/20*
	# Clean bash, nano, mysql, and vim history
	echo "" > /root/.bash_history
	echo "" > /root/.viminfo
	echo "" > /root/.nano_history
	echo "" > /root/.mysql_history
	# Remove previous Weaved installs; we use ESP now
	rm -rf /usr/bin/notify_Weaved*.sh /usr/bin/Weaved*.sh /etc/weaved /root/Weaved*.log
}

buildUSBImage(){
	if [[ $os == "cap_v1" ]] || [[ $os == "cap_v2" ]]; then
		echo; printStatus "You are running this script from a RACHEL-Plus CAP."
		echo; printQuestion "Do you want to create/build the *.tar.xz files from this device? (y/N)"
		echo "Select 'n' if you already have the three .tar.xz images on the USB."; read REPLY
		if [[ $REPLY =~ ^[Yy]$ ]]; then
			# Set the createdNewImages flag
			createdNewImages=1
			# Delete any previous .tar.xz files
			rm -f $mountName/*.tar.xz
			# Sanitize?
			echo; printQuestion "Do you want to sanitize this device prior to building the *.tar.xz files? (y/N) "; read REPLY
			if [[ $REPLY =~ ^[Yy]$ ]]; then
				sanitize
			fi
			# Stop script from defaulting the SSID
			sed -i 's/^redis-cli del WlanSsidT0_ssid/#redis-cli del WlanSsidT0_ssid/g' /root/generate_recovery.sh
			# Stop KA Lite
			echo; printStatus "Stopping KA Lite."
			kalite stop
#			# Delete the Device ID and crypto keys from the database (without affecting the admin user you have already set up)
#			echo; printStatus "Delete KA Lite Device ID and clearing crypto keys from the database"
#			kalite manage runcode "from django.conf import settings; settings.DEBUG_ALLOW_DELETIONS = True; from securesync.models import Device; Device.objects.all().delete(); from fle_utils.config.models import Settings; Settings.objects.all().delete()"
			echo; printQuestion "Do you want to run the /root/generate_recovery.sh script?"
			echo "The script will save the *.tar.xz files to /media/RACHEL/recovery"
			echo
			echo "**WARNING** You MUST be logged in via wifi or you will get disconnected and your script will fail during script execution."
			echo
			echo "Select 'n' to exit. (y/N)"; read REPLY
			if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
				echo "It takes about 75 minutes (on a RACHEL-Plus CAP) to create the 3 images; then, the USB script will continue."
				echo "Started building images at $(date "+%r")"
				rm -rf $0 $installTmpDir $rachelTmpDir
				echo; time /root/generate_recovery.sh $rachelRecoveryDir/
				echo
			else
				printError "User requested to exit, exiting."
				exit 1
			fi
		fi
		buildSaveDir=$(ls $rachelRecoveryDir | grep ^2)
		echo; printStatus "Checking $rachelRecoveryDir/$buildSaveDir for the three .tar.xz files."
		if [[ $createdNewImages == 1 ]]; then
			if [[ ! -f $rachelRecoveryDir/$buildSaveDir/boot.tar.xz ]] || [[ ! -f $rachelRecoveryDir/$buildSaveDir/efi.tar.xz ]] || [[ ! -f $rachelRecoveryDir/$buildSaveDir/rootfs.tar.xz ]]; then
				printError "One or more of the .tar.xz were not created, check log file:  $createLog"
				echo "	You may also want to check the directory where the .tar.xz files are created:  $rachelRecoveryDir/$buildSaveDir"
				echo; exit 1
			else
				printGood "Found the files; copying the .tar.xz files to the USB drive."
				cp $rachelRecoveryDir/$buildSaveDir/*.tar.xz $mountName/
			fi
		fi
	fi
	if [[ ! -f $mountName/boot.tar.xz ]] || [[ ! -f $mountName/efi.tar.xz ]] || [[ ! -f $mountName/rootfs.tar.xz ]]; then
		echo; printError "I could not find all three of the following files on the USB:"
		echo "	boot.tar.xz"
		echo "	efi.tar.xz"
		echo "	rootfs.tar.xz"
		echo; printStatus "Either copy the files to your USB or run this script again and create the files when prompted."
		echo; exit 1
	fi
}

removeOSXJunk(){
	# Remove OSX junk files - no need to have them on the image
	echo; printStatus "Removing any OSX junk files."
	cd $mountName
	echo "Removing any OSX junk files in the directory:  $(pwd)"
	rm -rf .Spotlight-V100 .Trashes ._.Trashes .fseventsd log/* update.log
	echo; printStatus "Cleaned up USB; ready to image."
	ls -la $mountName
}

setRecoveryMETHOD(){
	echo; printStatus "Setting the recovery method to '1' for the default recovery method."
	awk 'BEGIN{OFS=FS="\""} $1~/method=/ {$2="1";}1' $mountName/update.sh > update.tmp; mv update.tmp update.sh
}

addDefaultModules(){
	if [[ -d /media/RACHEL/rachel/modules/local_content ]]; then
		echo; printStatus "Adding the local_content module."
		rsync -avz --no-perms --no-owner --no-group $rsyncDIR/rachelmods/en-local_content $mountName/rachel-files/contentshell/modules/
	fi
}

updateVersions(){
	# Update firmware version
	echo; printStatus "Setting the RACHEL CAP firmware version."
	if ! grep -q ^firmwareVersion= $mountName/update.sh; then
		sed -i '33 a firmwareVersion=""' $mountName/update.sh
	fi
	awk 'BEGIN{OFS=FS="\""} $1~/^firmwareVersion=/ {$2="'$(cat /etc/version)'";}1' $mountName/update.sh > update.tmp; mv update.tmp update.sh
	# Update USB version
	echo; printStatus "Setting the RACHEL Recovery USB version."
	awk 'BEGIN{OFS=FS="\""} $1~/^usbVersion=/ {$2="'$usbVersion'";}1' $mountName/update.sh > update.tmp; mv update.tmp update.sh
	# Update USB creation date
	echo; printStatus "Setting the RACHEL Recovery USB creation date."
	sed -i '/^version=/d' $mountName/update.sh
	if ! grep -q ^usbCreated= $mountName/update.sh; then
		sed -i '33 a usbCreated=""' $mountName/update.sh
	fi
	awk 'BEGIN{OFS=FS="\""} $1~/^usbCreated=/ {$2="'$timestamp'";}1' $mountName/update.sh > update.tmp; mv update.tmp update.sh
	# Update RACHEL Installer version
	echo $usbVersion > /etc/rachelinstaller-version
	echo $usbVersion > $mountName/rachel-files/rachelinstaller-version
	# Update KA Lite version
	kalite --version > /etc/kalite-version
	# Update Kiwix version
	cat /var/kiwix/application.ini | grep ^Version | cut -d= -f2 > /etc/kiwix-version
}

unmountUSB(){
	# Identify the device name
	echo; printStatus "Unmounting USB."
	cd ~
	sync
	if [[ $os == "linux" ]] || [[ $os == "cap_v1" ]] || [[ $os == "cap_v2" ]]; then
		umount $usbDeviceName*
	elif [[ $os == "osx" ]]; then
		diskutil umountDisk $usbDeviceName
	fi
}

imageUSB(){
	# Image the USB - show the imaging time when complete; only copy our first 2 partitions to minimize space
	echo; printStatus "Creating image of USB drive (on USB 2.0 = ~60min; on USB 3.0 = ~2.5min)."
	echo "File location:  $imageSavePath/$imageName"
	if [[ $os == "cap_v1" ]]; then
#		usbDeviceName=$usbDeviceName
		partCount=$(( $(fdisk -l $usbDeviceName | grep ${usbDeviceName}2 | awk '{ print $3 }') + 1 ))
	elif [[ $os == "cap_v2" ]]; then
#		partCount=$(( $(fdisk -l $usbDeviceName | grep ${usbDeviceName}2 | awk '{ print $3 }') + 1 ))
		partCount=7714816 # I don't have an easy way to get this info yet
	elif [[ $os == "linux" ]]; then # Because linux tags the 2nd part as bootable
		partCount=$(( $(fdisk -l $usbDeviceName | grep ${usbDeviceName}2 | awk '{ print $4 }') + 1 ))
	elif [[ $os == "osx" ]]; then
		usbDeviceName=/dev/rdisk$diskNum
		partCount=$(( $(sudo fdisk $usbDeviceName | grep 2: | awk '{ print $13 }' | cut -d] -f1) + 1 ))
	fi
	echo "Running cmd:  time sudo dd if=$usbDeviceName of=$imageSavePath/$imageName count=$partCount bs=512"
	time sudo dd if=$usbDeviceName of=$imageSavePath/$imageName count=$partCount bs=512
}

compressHashUSBImage(){
	cd $imageSavePath
	# Compress the .img file (should reduce the image from 3.76GB to about 2.1GB)
	echo; printStatus "Compressing .img file (on RACHEL-Plus CAPv1 = ~14min; RACHEL-Plus CAPv2 = ~23min)."
	echo "Running cmd:  zip -9 -y -r -q -o $imageName.zip $imageName"
	time zip -9 -y -r -q -o $imageName.zip $imageName
	# MD5 hash the files
	echo; printStatus "Calculating MD5 hash of both the .img and .img.zip files (on RACHEL-Plus CAPv1 = ~51s; RACHEL-Plus CAPv2 = ~40s)."
	if [[ $os == "linux" ]] || [[ $os == "cap_v1" ]] || [[ $os == "cap_v2" ]]; then
		md5app=md5sum
	elif [[ $os == "osx" ]]; then
		md5app=md5
	fi
	echo "Running cmd:  $md5app $imageName $imageName.zip"
	time $md5app $imageName $imageName.zip | tee $imageName.zip.md5
}

##### MAIN PROGRAM
identifyOS
loggingStart
echo; echo "RACHEL Recovery USB Image Creation Script"
printGood "Script started:  $(date)"
printGood "Log file:  $createLog"
if [[ $(cat /etc/hostname) == "WRTD-303N-Server" ]]; then
	printGood "Hardware:  RACHEL-Plus (CAP v1)"
elif [[ $(cat /etc/hostname) == "WAPD-235N-Server" ]]; then
	printGood "Hardware:  RACHEL-Plus (CAP v2)"
elif [[ -f /etc/issue ]]; then
	printGood "Hardware:  Linux/Unix"
elif [[ -d /Volumes ]]; then
	printGood "Hardware:  OSX"
fi
identifySavePath
identifyUSBVersion
identifyDeviceNum
confirmRecoveryUSB
buildUSBImage
removeOSXJunk
setRecoveryMETHOD
addDefaultModules
updateVersions
unmountUSB
imageUSB
compressHashUSBImage
echo; printStatus "RACHEL USB Recovery image build completed; final image sizes:"
du -h $imageSavePath/$imageName*
echo; printGood "Script ended:  $(date)"
# Logging off
exec &>/dev/tty
stty sane
echo