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

usbDateTime=$(date +"%Y%m%d.%H%M")
imageSavePath="$HOME"
imageSavePathCAP="/media/RACHEL/recovery"
installTmpDir="/root/CAP-rachel-install.tmp"
rachelPartition="/media/RACHEL"
rachelWWW="$rachelPartition/rachel"
rachelScriptsDir="/root/rachel-scripts"
rachelTmpDir="/media/RACHEL/CAP-rachel-install.tmp"
rachelRecoveryDir="/media/RACHEL/recovery"
rsyncDIR="rsync://dev.worldpossible.org"

loggingStart(){
	if [[ $(echo $os | grep "CAP") ]]; then
		createLog="/media/RACHEL/recovery/createUSB-$usbDateTime.log"
	else
		createLog="./createUSB-$usbDateTime.log"
	fi
	exec &> >(tee "$createLog")
}

identifyOS(){
	if [[ $(cat /etc/hostname 2>/dev/null) == "WRTD-303N-Server" ]] || [[ $(cat /etc/hostname 2>/dev/null) == "WAPD-237N-Server" ]]; then
		os=CAP1
	elif [[ $(cat /etc/hostname 2>/dev/null) == "WAPD-235N-Server" ]] && [[ $(lsb_release -ds | grep 14.04) ]]; then
		os=CAP2
	elif [[ $(cat /etc/hostname 2>/dev/null) == "WAPD-235N-Server" ]] && [[ $(lsb_release -ds | grep 16.04) ]]; then
		os=CAP2_16.04
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
	if [[ $(echo $os | grep "CAP") ]]; then
		imageSavePath=$imageSavePathCAP
	else
		imageSavePath=$imageSavePath
	fi
	printGood "Saving image to:  $imageSavePath"
}

identifyDeviceNum(){
	# Identify the device name
	if [[ $os == "linux" ]] || [[ $(echo $os | grep "CAP") ]]; then
		echo; printStatus "List of currently mounted USB devices:"
		lsblk|grep -v mmc|grep -v sda
		echo; printQuestion "What is the device name that you want to image (for /dev/sdb, enter 'sdb')? "; read diskPart
		usbDeviceName="/dev/$diskPart"
	elif [[ $os == "osx" ]]; then
		diskutil list
		echo; printQuestion "What is the number of the device that you want to image (for /dev/disk1, enter '1')? "; read diskPart
		usbDeviceName="/dev/disk$diskPart"
	fi
	echo; printGood "Device name:  $usbDeviceName"
}

confirmRecoveryUSB(){
	# Confirm RACHEL Recovery USB
	echo; printStatus "Confirming the USB is a RACHEL Recovery USB."
	if [[ $os == "linux" ]] || [[ $(echo $os | grep "CAP") ]]; then
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
		echo; printError "This does not appear to be a valid RACHEL Recovery USB...exiting."
		exit 1
		## Future - add support to build a RACHEL Recovery USB from scratch
		# printQuestion "Would you like to prepare this USB as a RACHEL Recovery USB? "; read REPLY
		# if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
		# 	# Add ability to create a USB from scratch using git pull?
		# 	cd $mountName
		# 	git clone https://github.com/rachelproject/usbrecoveryshell.git
		# 	cp -r usbrecoveryshell/ .
		# 	rmdir usbrecoveryshell
		# else
		# 	echo; exit 1
		# fi
	else
		printGood "This is a RACHEL Recovery USB."
		usbVersion=$(head -1 $mountName/CHANGELOG)
	fi
}

setRecoveryMETHOD(){
	echo; printQuestion "What run mode do you want to set for the USB?"
	echo "    - [METHOD_1_Recovery] Standard Recovery"
	echo "    - [METHOD_2_Clone] OS Recovery without touching the hard drive since you will add a cloned one"
	echo "    - [METHOD_3_AutoInstall] Automated OS Recovery and reimage hard drive to fresh install of RACHEL w/optional rsync module install"
    echo
    select menu in "METHOD_1_Recovery" "METHOD_2_Clone" "METHOD_3_AutoInstall"; do
		case $menu in
		METHOD_1_Recovery)
			echo; printStatus "Setting the recovery method to '1' for the default recovery method."
			awk 'BEGIN{OFS=FS="="} $1~/method/ {$2=1;}1' $mountName/update.sh > update.tmp; mv update.tmp $mountName/update.sh
			usbType="Recovery"
			# Check if we want to build an install USB as well (good if you are not wanting to wait for the Recovery to finish)
			echo; printQuestion "Do you want to build an install USB along with a Recovery USB? (y/N) "; read REPLY
			if [[ $REPLY =~ ^[Yy]$ ]]; then
				buildInstall=1
			fi
			break
		;;
		METHOD_2_Clone)
			echo; printStatus "Setting the recovery method to '2' for the default recovery method."
			awk 'BEGIN{OFS=FS="="} $1~/method/ {$2=2;}1' $mountName/update.sh > update.tmp; mv update.tmp $mountName/update.sh
			usbType="Clone"
			break
		;;
		METHOD_3_AutoInstall)
			echo; printStatus "Setting the recovery method to '3' for the default recovery method."
			awk 'BEGIN{OFS=FS="="} $1~/method/ {$2=3;}1' $mountName/update.sh > update.tmp; mv update.tmp $mountName/update.sh
			usbType="Install"
			break
		;;
		esac
    done
}

identifyUSBVersion(){
	if [[ $(echo $os | grep "CAP") ]]; then 
		imageName=''$os'_RACHEL_'$usbType'_USB_'$usbVersion'.img'
	else 
		echo; printQuestion "What model of CAP (v1 or v2) are you creating an recovery image for?"
		select menu in "CAP1" "CAP2"; do
			case $menu in
			CAP1)
				imageName='CAP1_RACHEL_'$usbType'_USB_'$usbVersion'.img'
				break
			;;
			CAP2)
				imageName='CAP2_RACHEL_'$usbType'_USB_'$usbVersion'.img'
				break
			;;
			esac
		done
	fi
	printGood "Using image name:  $imageName"
}

updateUSBFiles(){
	# Update the files on the Recovery USB
	echo; printQuestion "Do you want to update the Recovery USB files (contentshell, configure script)? (y/N) "; read REPLY
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		# Check if we are in the right directory
		cd $mountName/rachel-files

		# Update cap-rachel-configure.sh
		echo;echo "[+] Update cap-rachel-configure.sh"
		wget https://raw.githubusercontent.com/rachelproject/rachelplus/master/cap-rachel-configure.sh -O cap-rachel-configure.sh

		# Update createUSB.sh
		echo;echo "[+] Update createUSB.sh"
		wget https://raw.githubusercontent.com/rachelproject/rachelplus/master/scripts/createUSB.sh -O createUSB.sh

		# Update contentshell
		echo;echo "[+] Update contentshell"
		cd rachel
		git pull
	fi
}

sanitize(){
	# Remove history, clean logs
	echo; printStatus "Sanitizing log files."
	echo; echo "[+] Start time:  $(date "+%r")"
	# Clean log files and possible test scripts
	rm -rf /var/log/rachel-install* /var/log/RACHEL/* /var/log/rachel/*
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
	if [[ $(echo $os | grep "CAP") ]]; then
		echo; printStatus "You are running this script from a RACHEL-Plus CAP."
		echo; printQuestion "Do you want to create/build the *.tar.xz files from this device? (y/N)"
		echo "Select 'n' if you already have the three .tar.xz images on the USB."; read REPLY
		if [[ $REPLY =~ ^[Yy]$ ]]; then
			# Set the createdNewImages flag
			createdNewImages=1

			# Delete any previous .tar.xz files
			rm -f $mountName/*.tar.xz

			# Setup files for first run/install
			chmod +x /etc/battery_solve.sh /root/rachel-scripts/firstboot.sh /root/rachel-scripts/rachelStartup.sh root/cap-rachel-configure.sh
			rm /root/rachel-scripts/files/.kalite/content/*.mp4
			mv /root/rachel-scripts/firstboot.sh.done /root/rachel-scripts/firstboot.sh
			rm /root/battery_log
			rm /etc/BATTERY_EDIT_DONE
			echo $(date) > /etc/buildDate

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

			# Allow for KA Lite to completely shutdown
			sleep 1

			echo; printQuestion "Do you want to run the /root/generate_recovery.sh script?"
			echo "The script will save the *.tar.xz files to /media/RACHEL/recovery"
			echo
			echo "**WARNING** You MUST be logged in via wifi or you will get disconnected and your script will fail during script execution."
			echo
			echo "Select 'n' to exit. (y/N)"; read REPLY
			if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
				echo "It takes about 75 minutes (RACHEL-Plus CAP1) or 121 minutes (RACHEL-Plus CAP2) to create the 3 images; then, the USB script will continue."
				echo; echo "[+] Start time:  $(date "+%r")"
				rm -rf $installTmpDir $rachelTmpDir
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
	rm -rf .Spotlight-V100 .Trashes ._.Trashes .fseventsd log/* update.log .TemporaryItems ._.TemporaryItems ._README.txt
	echo; printStatus "Cleaned up USB; ready to image."
	ls -la $mountName
}

addDefaultModules(){
	if [[ -d /media/RACHEL/rachel/modules/local_content ]]; then
		echo; printStatus "Adding the local_content module."
		rsync -avz --no-perms --no-owner --no-group $rsyncDIR/rachelmods/en-local_content $mountName/rachel-files/contentshell/modules/
	fi
}

updateVersions(){
	# Remove old format
	sed -i '/^version=/d' $mountName/update.sh
	# Update firmware version
	echo; printStatus "Setting the RACHEL CAP firmware version."
	if ! grep -q ^firmwareVersion= $mountName/update.sh; then sed -i '36 a firmwareVersion=""' $mountName/update.sh; fi
	awk 'BEGIN{OFS=FS="\""} $1~/^firmwareVersion=/ {$2="'$(cat /etc/version)'";}1' $mountName/update.sh > update.tmp; mv update.tmp $mountName/update.sh
	# Update USB creation date
	echo; printStatus "Setting the RACHEL Recovery USB creation date."
	if ! grep -q ^usbCreated= $mountName/update.sh; then sed -i '37 a usbCreated=""' $mountName/update.sh; fi
	awk 'BEGIN{OFS=FS="\""} $1~/^usbCreated=/ {$2="'$usbDateTime'";}1' $mountName/update.sh > update.tmp; mv update.tmp $mountName/update.sh
	# Update USB version
	echo; printStatus "Setting the RACHEL Recovery USB version."
	if ! grep -q ^usbVersion= $mountName/update.sh; then sed -i '38 a usbVersion=""' $mountName/update.sh; fi
	awk 'BEGIN{OFS=FS="\""} $1~/^usbVersion=/ {$2="'$usbVersion'";}1' $mountName/update.sh > update.tmp; mv update.tmp $mountName/update.sh
	# Update RACHEL Installer version
	echo $usbVersion > /etc/rachelinstaller-version
	# Update KA Lite version
	kalite --version > /etc/kalite-version
	# Update Kiwix version
	cat /var/kiwix/application.ini | grep ^Version | cut -d= -f2 > /etc/kiwix-version
}

unmountUSB(){
	# Identify the device name
	echo; printStatus "Unmounting USB."
	cd ~
	if [[ $os == "linux" ]] || [[ $(echo $os | grep "CAP") ]]; then
		umount $usbDeviceName*
	elif [[ $os == "osx" ]]; then
		diskutil umountDisk $usbDeviceName
	fi
}

imageUSB(){
	# Image the USB - show the imaging time when complete; only copy our first 2 partitions to minimize space
	echo; printStatus "Creating image of USB drive (with USB 2.0 = ~60min; with USB 3.0 = ~2.5min)."
	echo; echo "[+] Start time:  $(date "+%r")"
	echo "File location:  $imageSavePath/$imageName"
	if [[ $os == "CAP1" ]]; then
#		usbDeviceName=$usbDeviceName
		partCount=$(( $(fdisk -l $usbDeviceName | grep ${usbDeviceName}2 | awk '{ print $3 }') + 1 ))
	elif [[ $os == "CAP2" ]]; then
#		partCount=$(( $(fdisk -l $usbDeviceName | grep ${usbDeviceName}2 | awk '{ print $3 }') + 1 ))
#		partCount=7714816 # Recovery USBs prior to 2.2.0
		partCount=8688540 # I don't have an easy way to get this info yet
	elif [[ $os == "CAP2_16.04" ]]; then
		partCount=$(( $(fdisk -l $usbDeviceName | grep ${usbDeviceName}2 | awk '{ print $3 }') + 1 ))
		# partCount=10856448 # I don't have an easy way to get this info yet
	elif [[ $os == "linux" ]]; then # Because linux tags the 2nd part as bootable
		partCount=$(( $(fdisk -l $usbDeviceName | grep ${usbDeviceName}2 | awk '{ print $4 }') + 1 ))
	elif [[ $os == "osx" ]]; then
		usbDeviceName=/dev/rdisk$diskPart
		partCount=$(( $(sudo fdisk $usbDeviceName | grep 2: | awk '{ print $13 }' | cut -d] -f1) + 1 ))
	fi
	echo "Running cmd:  time sudo dd if=$usbDeviceName of=$imageSavePath/$imageName count=$partCount bs=512"
	time sudo dd if=$usbDeviceName of=$imageSavePath/$imageName count=$partCount bs=512
}

compressHashUSBImage(){
	cd $imageSavePath
	# MD5 hash the img
	echo; printStatus "Calculating MD5 hash of both the .img (on RACHEL-Plus CAP1 = ~50s; RACHEL-Plus CAP2 = ~40s)."
	echo; echo "[+] Start time:  $(date "+%r")"
	if [[ $os == "linux" ]] || [[ $(echo $os | grep "CAP") ]]; then
		md5app=md5sum
	elif [[ $os == "osx" ]]; then
		md5app=md5
	fi
	echo "Running cmd:  $md5app $imageName"
	echo; echo "[+] Start time:  $(date "+%r")"
	time $md5app $imageName | tee $imageName.md5
	# Compress the .img file (should reduce the image from 3.76GB to about 2.1GB)
	echo; printStatus "Compressing .img file (on RACHEL-Plus CAP1 = ~14min; RACHEL-Plus CAP2 = ~23min)."
	echo "Running cmd:  zip -9 -y -r -q -o $imageName.zip $imageName.md5 $imageName"
	time zip -9 -y -r -q -o $imageName.zip $imageName.md5 $imageName
}

createInstallUSB(){
	mkdir -p /media/RACHEL-INST
	mount /dev/sdb1 /media/RACHEL-INST
	echo; printStatus "Setting the recovery method to '3' for the default recovery method."
	awk 'BEGIN{OFS=FS="="} $1~/export method/ {$2=3;}1' $mountName/update.sh > update.tmp; mv update.tmp $mountName/update.sh
	echo; printStatus "Current METHOD:  $(cat $mountName/update.sh | grep 'export method')"
	usbType="Install"
	identifyUSBVersion
	imageUSB
	compressHashUSBImage
	echo; printStatus "RACHEL USB $usbType image build completed...here are the final image sizes:"
	du -h $imageSavePath/$imageName*
}

##### MAIN PROGRAM
identifyOS
loggingStart
echo; echo "RACHEL Recovery USB Image Creation Script"
printGood "Script started:  $(date)"
printGood "Log file:  $createLog"
if [[ $(echo $os) == "CAP1" ]]; then
	printGood "Hardware:  RACHEL-Plus (CAP v1)"
elif [[ $(echo $os) == "CAP2" ]]; then
	printGood "Hardware:  RACHEL-Plus (CAP v2)"
elif [[ $(echo $os) == "CAP2_16.04" ]]; then
	printGood "Hardware:  RACHEL-Plus (CAP v2 16.04)"
elif [[ -f /etc/issue ]]; then
	printGood "Hardware:  Linux/Unix"
elif [[ -d /Volumes ]]; then
	printGood "Hardware:  OSX"
fi
identifySavePath
identifyDeviceNum
confirmRecoveryUSB
setRecoveryMETHOD
identifyUSBVersion
updateUSBFiles
updateVersions
buildUSBImage
removeOSXJunk
#addDefaultModules
unmountUSB
imageUSB
compressHashUSBImage
echo; printStatus "RACHEL USB $usbType image build completed...here are the final image sizes:"
du -h $imageSavePath/$imageName*
# If install flag set, build an install USB
if [[ $(echo $buildInstall) == 1 ]]; then createInstallUSB; fi
echo; printGood "Script ended:  $(date)"
# Logging off
exec &>/dev/tty
stty sane
echo
