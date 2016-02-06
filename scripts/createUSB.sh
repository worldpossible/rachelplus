#!/bin/sh
# RACHEL Recovery USB Image Creation Script
# By: sam@hfc
# Usage:  ./createUSB.sh

version=1
date=$(date +"%Y%m%d")
imageSavePath="$HOME"

identifyOS(){
	if [[ -f /etc/issue ]]; then
		os=linux
		echo; echo "[+] You are running a Unix variant"
	elif [[ -d /Volumes ]]; then
		os=osx
		echo; echo "[+] You are running OSX"
	else
		echo; echo "[!] Your OS is unknown; sorry, I can not continue."
		echo; exit 1
	fi
}

identifyUSBVersion(){
	# Identify the device name
	echo; read -p "[?] What will be the version number for the RACHEL Recovery USB (e.g. 1-2-16_v2)? " usbVersion
	imageName="RACHEL_Recovery_USB_"$usbVersion"_$date.img"
	echo; echo "[+] Image name:  $imageName"
}

identifyDeviceNum(){
	# Identify the device name
	if [[ $os == "linux" ]]; then
		os=linux
		echo; echo "[+] You are running a Unix variant"
		fdisk -l
		echo; read -p "[?] What is the device name that you want to image (for /dev/sda, enter 'sda')? " diskNum
		usbDeviceName="/dev/$diskNum"
	elif [[ $os == "osx" ]]; then
		os=osx
		echo; echo "[+] You are running OSX"
		diskutil list
		echo; read -p "[?] What is the number of the device that you want to image (for /dev/disk1, enter '1')? " diskNum
		usbDeviceName="/dev/disk$diskNum"
	fi
	echo; echo "[+] Device name:  $usbDeviceName"
}

confirmRecoveryUSB(){
	# Remove OSX junk files - no need to have them on the image
	echo; echo "[*] Removing any OSX junk files."
	if [[ $os == "linux" ]]; then
		mountName=$(mount | grep "$usbDeviceName"1 | awk '{print $3}')
	elif [[ $os == "osx" ]]; then
		mountName=$(mount | grep "$usbDeviceName"s1 | awk '{print $3}')
	fi
	if [[ -z $mountName ]]; then
		echo; echo "[!] I couldn't find a valid, mounted patition, exiting."
		exit 1
	fi
	# Check for update.sh; if not found, exit
	if [[ ! -f $mountName/update.sh ]]; then
		echo; echo "[!] This does not appear to be a valid RACHEL Recovery USB; 'update.sh' was not found."
		echo; exit 1
	fi
}

removeOSXJunk(){
	cd $mountName
	echo "Removing any OSX junk files in the directory:  $(pwd)"
	rm -rf .Spotlight-V100 .Trashes ._.Trashes .fseventsd log/* update.log
	echo
	ls -la $mountName
}

setRecoveryMETHOD(){
	echo; echo "[*] Setting the recovery method to '1' for the default recovery method"
	awk 'BEGIN{OFS=FS="\""} $1~/METHOD/ {$2="1";}1' $mountName/update.sh > update.tmp; mv update.tmp update.sh
}

unmountUSB(){
	# Identify the device name
	echo; echo "[*] Unmounting USB."
	cd ~
	sync
	if [[ $os == "linux" ]]; then
		umount $usbDeviceName*
	elif [[ $os == "osx" ]]; then
		diskutil umountDisk $usbDeviceName
	fi
}

imageUSB(){
	# Image the USB - show the imaging time when complete; only copy our first 2 partitions to minimize space
	echo; echo "[*] Creating image of USB drive (this process could take around 50 minutes."
	echo "File location:  $imageSavePath/$imageName"
	if [[ $os == "linux" ]]; then
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
	echo; echo "[*] Compressing .img file."
	echo "Running cmd:  zip -9 -o $imageName.zip $imageName"
	zip -9 -o -ll $imageName.zip $imageName
	
	# MD5 hash the files
	echo; echo "[*] Calculating MD5 hash of both the .img and .img.zip files."
	if [[ $os == "linux" ]]; then
		md5app=md5sum
	elif [[ $os == "osx" ]]; then
		md5app=md5
	fi
	echo "Running cmd:  $md5app $imageName $imageName.zip"
	$md5app $imageName $imageName.zip
}

##### MAIN PROGRAM
echo; echo "RACHEL Recovery USB Image Creation Script"
echo "[+] Script started:  $(date)"
echo "[+] Saving image to $imageSavePath"
identifyOS
identifyUSBVersion
identifyDeviceNum
confirmRecoveryUSB
removeOSXJunk
setRecoveryMETHOD
unmountUSB
imageUSB
compressHashUSBImage
echo; echo "[+] RACHEL USB Recovery image build completed; final image sizes:"
du -h $imageSavePath/$imageName*
echo; echo "[+] Script ended:  $(date)"
echo
