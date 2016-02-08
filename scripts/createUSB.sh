#!/bin/sh
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

version=2
timestamp=$(date +"%Y%m%d.%H%M")
usbDate=$(date +"%Y%m%d")
imageSavePath="$HOME"
imageSavePathCAP="/media/RACHEL/recovery"
installTmpDir="/root/cap-rachel-install.tmp"
rachelTmpDir="/media/RACHEL/cap-rachel-install.tmp"
rachelRecoveryDir="/media/RACHEL/recovery"
weavedInstall="wget -c https://github.com/weaved/installer/raw/master/Intel_CAP/weaved_IntelCAP.tar -O /root/weaved_IntelCAP.tar"
createLog="/media/RACHEL/recovery/createUSB-$timestamp.log"

loggingStart(){
	exec &> >(tee "$createLog")
}

identifyOS(){
	if [[ $(cat /etc/hostname) == "WRTD-303N-Server" ]]; then
		os=cap
		printGood "You are running the script on a RACHEL-Plus CAP."
	elif [[ -f /etc/issue ]]; then
		os=linux
		printGood "You are running the script on a Unix variant."
	elif [[ -d /Volumes ]]; then
		os=osx
		printGood "You are running the script on OSX."
	else
		echo; printError "Your OS is unknown; sorry, I can not continue."
		echo; exit 1
	fi
}

identifySavePath(){
	if [[ $os == "cap" ]]; then
		imageSavePath=$imageSavePathCAP
	else
		imageSavePath=$imageSavePath
	fi
	printGood "Saving image to $imageSavePath"
}

identifyUSBVersion(){
	# Identify the device name
	echo; read -p "[?] What will be the version number for the RACHEL Recovery USB (e.g. 1-2-16_v2)? " usbVersion
	imageName="RACHEL_Recovery_USB_$usbVersion_$usbDate.img"
	echo; printGood "Image name:  $imageName"
}

identifyDeviceNum(){
	# Identify the device name
	if [[ $os == "linux" ]] || [[ $os == "cap" ]]; then
		fdisk -l
		echo; read -p "[?] What is the device name that you want to image (for /dev/sdb, enter 'sdb')? " diskNum
		usbDeviceName="/dev/$diskNum"
	elif [[ $os == "osx" ]]; then
		diskutil list
		echo; read -p "[?] What is the number of the device that you want to image (for /dev/disk1, enter '1')? " diskNum
		usbDeviceName="/dev/disk$diskNum"
	fi
	echo; printGood "Device name:  $usbDeviceName"
}

confirmRecoveryUSB(){
	# Confirm RACHEL Recovery USB
	echo; printStatus "Confirming the USB is a RACHEL Recovery USB."
	if [[ $os == "linux" ]] || [[ $os == "cap" ]]; then
		mountName=$(mount | grep "$usbDeviceName"1 | awk '{print $3}')
	elif [[ $os == "osx" ]]; then
		mountName=$(mount | grep "$usbDeviceName"s1 | awk '{print $3}')
	fi
	if [[ -z $mountName ]]; then
		echo; printError "I couldn't find a valid, mounted patition, exiting."
		echo; exit 1
	fi
	# Check for update.sh; if not found, exit
	if [[ ! -f $mountName/update.sh ]]; then
		echo; printError "This does not appear to be a valid RACHEL Recovery USB; 'update.sh' was not found."
		echo; exit 1
	else
		printGood "This is a RACHEL Recovery USB."
	fi
}

installDefaultWeavedServices(){
	echo; printStatus "Installing Weaved service."
	cd /root
	# Download weaved files
	echo; printStatus "Downloading required files."
	$weavedInstall
	tar xvf weaved_IntelCAP.tar
	if [[ -d /root/weaved_software ]]; then
		rm -f /root/weaved_IntelCAP.tar
		echo; printGood "Done."
		# Run installer
		cd /root/weaved_software
		bash install.sh
		echo; printGood "Weaved service install complete."
		printGood "NOTE: An Weaved service uninstaller is available from the Utilities menu of this script."
	else
		echo; printError "One or more files did not download correctly; and try again."
		echo; exit 1
	fi
}

sanitize(){
	# Remove history, clean logs
	echo; printStatus "Sanitizing log files."
	# Clean log files and possible test scripts
	rm -rf /var/log/rachel-install* /var/log/RACHEL/* /root/test.sh
	# Clean previous cached logins from ssh
	rm -f /root/.ssh/known_hosts
	# Clean off ka-lite_content.zip (if exists)
	rm -f /media/RACHEL/ka-lite_content.zip
	# Clean previous files from running the generate_recovery.sh script 
	rm -rf /recovery/20* $rachelRecoveryDir/20*
	# Clean bash history
	echo "" > /root/.bash_history
	echo; printQuestion "Do you want to remove any currently activated Weaved services and run the default Weaved setup?"
	echo "If you enter 'y', we will install the staged default Weaved services for ports 22, 80, and 8080."
	read -p "    Enter (y/N) " REPLY
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		# Remove previous Weaved installs
		rm -rf /usr/bin/notify_Weaved*.sh /usr/bin/Weaved*.sh /etc/weaved/services/Weaved*.conf /root/Weaved*.log
		# Install default weaved services
		installDefaultWeavedServices
	fi
	echo; printGood "All ready for a customer; register Weaved services, if needed."
}

buildUSBImage(){
	if [[ $os == "cap" ]]; then
		echo; printStatus "You are running this script from a RACHEL-Plus CAP."
		printQuestion "Do you want to create/build the *.tar.xz files from this device?"
		echo "    (Select 'n' if you already have the three .tar.xz images on the USB)"
		read -p "    Enter (y/N) " REPLY
		if [[ $REPLY =~ ^[Yy]$ ]]; then
			# Delete any previous .tar.xz files
			rm -f $mountName/*.tar.xz
			# Sanitize?
			echo; printQuestion "Do you want to sanitize this device prior to building the *.tar.xz files?"
			read -p "    Enter (y/N) " REPLY
			if [[ $REPLY =~ ^[Yy]$ ]]; then
			    sanitize
			fi
			# Stop script from defaulting the SSID
			sed -i 's/^redis-cli del WlanSsidT0_ssid/#redis-cli del WlanSsidT0_ssid/g' /root/generate_recovery.sh
			# Stop KA Lite
			echo; printStatus "Stopping KA Lite."
			kalite stop
			# Delete the Device ID and crypto keys from the database (without affecting the admin user you have already set up)
			echo; printStatus "Delete KA Lite Device ID and clearing crypto keys from the database"
			kalite manage runcode "from django.conf import settings; settings.DEBUG_ALLOW_DELETIONS = True; from securesync.models import Device; Device.objects.all().delete(); from fle_utils.config.models import Settings; Settings.objects.all().delete()"
			echo; printQuestion "Do you want to run the /root/generate_recovery.sh script?"
			echo "    The script will save the *.tar.xz files to /media/RACHEL/recovery"
			echo
			echo "    **WARNING** You MUST be logged in via wifi or you will get disconnected and your script will fail during script execution."
			echo
			read -p "    Select 'n' to exit. (y/N) " -r
			if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
				echo "It takes about 45 minutes to create the 3 images; then, the USB script will continue."
				rm -rf $0 $installTmpDir $rachelTmpDir
				echo; /root/generate_recovery.sh $rachelRecoveryDir/
				echo
		    fi
		fi
	fi
	if [[ ! -f $mountName/boot.tar.xz ]] || [[ ! -f $mountName/efi.tar.xz ]] || [[ ! -f $mountName/rootfs.tar.xz ]]; then
		echo; printError "I could not find all three of the following files on the USB:"
		echo "    boot.tar.xz"
		echo "    efi.tar.xz"
		echo "    rootfs.tar.xz"
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
	echo
	ls -la $mountName
}

setUSBVersion(){
	echo; printStatus "Setting the RACHEL Recovery USB version."
	awk 'BEGIN{OFS=FS="\""} $1~/VERSION=/ {$2="'$usbVersion'";}1' $mountName/update.sh > update.tmp; mv update.tmp update.sh
}

setRecoveryMETHOD(){
	echo; printStatus "Setting the recovery method to '1' for the default recovery method"
	awk 'BEGIN{OFS=FS="\""} $1~/METHOD=/ {$2="1";}1' $mountName/update.sh > update.tmp; mv update.tmp update.sh
}

unmountUSB(){
	# Identify the device name
	echo; printStatus "Unmounting USB."
	cd ~
	sync
	if [[ $os == "linux" ]] || [[ $os == "cap" ]]; then
		umount $usbDeviceName*
	elif [[ $os == "osx" ]]; then
		diskutil umountDisk $usbDeviceName
	fi
}

imageUSB(){
	# Image the USB - show the imaging time when complete; only copy our first 2 partitions to minimize space
	echo; printStatus "Creating image of USB drive (on USB 2.0 = ~55min; on USB 3.0 = ~2min30sec)."
	echo "File location:  $imageSavePath/$imageName"
	if [[ $os == "linux" ]] || [[ $os == "cap" ]]; then
		usbDeviceName=$usbDeviceName
	elif [[ $os == "osx" ]]; then
		usbDeviceName=/dev/rdisk$diskNum
	fi
	echo "Running cmd:  time sudo dd if=$usbDeviceName of=$imageSavePath/$imageName count=7337984 bs=512"
	time sudo dd if=$usbDeviceName of=$imageSavePath/$imageName count=7337984 bs=512
}

compressHashUSBImage(){
	cd $imageSavePath
	# Compress the .img file (should reduce the image from 3.76GB to about 2.1GB)
	echo; printStatus "Compressing .img file."
	echo "Running cmd:  zip -9 -o $imageName.zip $imageName"
	time zip -9 -o $imageName.zip $imageName
	
	# MD5 hash the files
	echo; printStatus "Calculating MD5 hash of both the .img and .img.zip files."
	if [[ $os == "linux" ]] || [[ $os == "cap" ]]; then
		md5app=md5sum
	elif [[ $os == "osx" ]]; then
		md5app=md5
	fi
	echo "Running cmd:  $md5app $imageName $imageName.zip"
	time $md5app $imageName $imageName.zip
}

##### MAIN PROGRAM
loggingStart
echo; echo "RACHEL Recovery USB Image Creation Script"
printGood "Script started:  $(date)"
printGood "Log file:  $createLog"
identifyOS
identifySavePath
identifyUSBVersion
identifyDeviceNum
confirmRecoveryUSB
buildUSBImage
removeOSXJunk
setUSBVersion
setRecoveryMETHOD
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
