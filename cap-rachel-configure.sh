#!/bin/bash
# FILE: cap-rachel-configure.sh
# ONELINER Download/Install: sudo wget https://raw.githubusercontent.com/rachelproject/rachelplus/master/cap-rachel-configure.sh -O /root/cap-rachel-configure.sh; bash cap-rachel-configure.sh

# For offline builds, run the Download-Offline-Content script in the Utilities menu.

# COMMON VARIABLES - Change as needed
DIRCONTENTOFFLINE="/media/nas/rachel-content" # Enter directory of downloaded RACHEL content for offline install (e.g. I mounted my external USB on my CAP but plugging the external USB into and running the command 'fdisk -l' to find the right drive, then 'mkdir /media/RACHEL-Content' to create a folder to mount to, then 'mount /dev/sdb1 /media/RACHEL-Content' to mount the USB drive.)
RSYNCONLINE="rsync://dev.worldpossible.org" # The current RACHEL rsync repository
CONTENTONLINE="rsync://rachel.golearn.us/content" # Another RACHEL rsync repository
WGETONLINE="http://rachelfriends.org" # RACHEL large file repo (ka-lite_content, etc)
GITRACHELPLUS="https://raw.githubusercontent.com/rachelproject/rachelplus/master" # RACHELPlus Scripts GitHub Repo
GITCONTENTSHELL="https://raw.githubusercontent.com/rachelproject/contentshell/master" # RACHELPlus ContentShell GitHub Repo

# CORE RACHEL VARIABLES - Change **ONLY** if you know what you are doing
OS="$(awk -F '=' '/^ID=/ {print $2}' /etc/os-release 2>&-)"
OSVERSION=$(awk -F '=' '/^VERSION_ID=/ {print $2}' /etc/os-release 2>&-)
VERSION=20160203.1656 # To get current version - date +%Y%m%d.%H%M
TIMESTAMP=$(date +"%b-%d-%Y-%H%M%Z")
INTERNET="1" # Enter 0 (Offline), 1 (Online - DEFAULT)
RACHELLOGDIR="/var/log/RACHEL"
mkdir -p $RACHELLOGDIR
RACHELLOGFILE="rachel-install.tmp"
RACHELLOG="$RACHELLOGDIR/$RACHELLOGFILE"
RACHELPARTITION="/media/RACHEL"
RACHELWWW="$RACHELPARTITION/rachel"
RACHELSCRIPTSFILE="/root/rachel-scripts.sh"
RACHELSCRIPTSLOG="/var/log/RACHEL/rachel-scripts.log"
KALITEUSER="root"
KALITEDIR="/root/.kalite" # Installed as user 'root'
KALITERCONTENTDIR="/media/RACHEL/kacontent"
KALITECURRENTVERSION="0.15.1"
KALITEINSTALLER="ka-lite-bundle-$KALITECURRENTVERSION.deb"
KALITESETTINGS="$KALITEDIR/settings.py"
INSTALLTMPDIR="/root/cap-rachel-install.tmp"
RACHELTMPDIR="/media/RACHEL/cap-rachel-install.tmp"
RACHELRECOVERYDIR="/media/RACHEL/recovery"
ERRORCODE="0"

# MD5 hash list
buildHashList(){
    cat > $INSTALLTMPDIR/hashes.md5 << 'EOF'
15b6aa51d8292b7b0cbfe36927b8e714 khan_assessment.zip
65fe77df27169637f20198901591dff0 ka-lite_content.zip
bd905efe7046423c1f736717a59ef82c ka-lite-bundle-0.15.0.deb
18998e1253ca720adb2b54159119ce80 ka-lite-bundle-0.15.1.deb
922b05e10e42bc3869e8b8f8bf625f07 kiwix-0.9+wikipedia_en_all_2015-05.zip
31963611e46e717e00b30f6f6d8833ac kiwix-0.9+wikipedia_en_for-schools_2013-01.zip
b61fdc3937aa226f34f685ba0bc29db1 kiwix-0.9-linux-i686.tar.bz2
4150c320a03bdae01a805fc4c3f6eb9a sphider_plus.sql
EOF
}

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

if [ -z $BASH_VERSION ]; then
    clear
    echo "[!] You didn't execute this script with bash!"
    echo "Unfortunately, not all shells are the same. \n"
    echo "Please execute \"bash "$0"\" \n"
    echo "Thank you! \n"
    exit 1
fi

# Check root
if [ "$(id -u)" != "0" ]; then
    echo "[!] This script must be run as root; sudo password is 123lkj"
    exit 1
fi

# Reset terminal
stty sane
#reset

#in case you wish to kill it
trap 'exit 3' 1 2 3 15

# Logging
loggingStart(){
    exec &> >(tee "$RACHELLOG")
}

ctrlC(){
    kill $!; trap 'kill $1' SIGTERM
    echo; printError "Cancelled by user."
    cleanup
    stty sane
    echo; exit $?
}

testingScript(){
    set -x
    trap ctrlC INT

    installDefaultWeavedServices
    backupWeavedService

    set +x
    exit 1
}

opMode(){
    trap ctrlC INT
    echo; printQuestion "Do you want to run in ONLINE or OFFLINE mode?"
    select MODE in "ONLINE" "OFFLINE"; do
        case $MODE in
        # ONLINE
        ONLINE)
            echo; printGood "Script set for 'ONLINE' mode."
            INTERNET="1"
            onlineVariables
            checkInternet
            break
        ;;
        # OFFLINE
        OFFLINE)
            echo; printGood "Script set for 'OFFLINE' mode."
            INTERNET="0"
            offlineVariables
            echo; printQuestion "The OFFLINE RACHEL content folder is set to:  $DIRCONTENTOFFLINE"
            read -p "Do you want to change the default location? (y/n) " -r
            if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
                echo; printQuestion "What is the location of your content folder? "; read DIRCONTENTOFFLINE
            fi
            if [[ ! -d $DIRCONTENTOFFLINE ]]; then
                echo; printError "The folder location does not exist!  Do you want to continue?"
                read -p "    Enter (y/N) " REPLY
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    DIRCONTENTOFFLINE=""
                    offlineVariables
                else
                    printError "Exiting on user request."
                    rm -rf $INSTALLTMPDIR $RACHELTMPDIR
                    exit 1
                fi
            fi
            break
        ;;
        esac
        printGood "Done."
        break
    done
}

osCheck(){
    if [[ -z "$OS" ]] || [[ -z "$OSVERSION" ]]; then
      printError "Internal issue. Couldn't detect OS information."
    elif [[ "$OS" == "ubuntu" ]]; then
      osVersion=$(awk -F '["=]' '/^VERSION_ID=/ {print $3}' /etc/os-release 2>&- | cut -d'.' -f1)
      printGood "Ubuntu ${OSVERSION} $(uname -m) Detected."
    elif [[ "$OS" == "debian" ]]; then
      printGood "Debian ${OSVERSION} $(uname -m) Detected."
    fi
}

onlineVariables(){
    GPGKEY1="apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 40976EAF437D05B5"
    GPGKEY2="apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 16126D3A3E5C1192"
    SOURCEUS="wget -r $GITRACHELPLUS/sources.list/sources-us.list -O /etc/apt/sources.list"
    SOURCEUK="wget -r $GITRACHELPLUS/sources.list/sources-uk.list -O /etc/apt/sources.list"
    SOURCESG="wget -r $GITRACHELPLUS/sources.list/sources-sg.list -O /etc/apt/sources.list"
    SOURCECN="wget -r $GITRACHELPLUS/sources.list/sources-sohu.list -O /etc/apt/sources.list" 
    CAPRACHELFIRSTINSTALL2="wget -r $GITRACHELPLUS/install/cap-rachel-first-install-2.sh -O cap-rachel-first-install-2.sh"
    CAPRACHELFIRSTINSTALL3="wget -r $GITRACHELPLUS/install/cap-rachel-first-install-3.sh -O cap-rachel-first-install-3.sh"
    LIGHTTPDFILE="wget -r $GITRACHELPLUS/lighttpd.conf -O lighttpd.conf"
    CAPTIVEPORTALREDIRECT="wget -r $GITRACHELPLUS/captive-portal/captiveportal-redirect.php -O captiveportal-redirect.php"
    PASSTICKETSHTML="wget -r $GITRACHELPLUS/captive-portal/pass_ticket.shtml -O pass_ticket.shtml"
    REDIRECTSHTML="wget -r $GITRACHELPLUS/captive-portal/redirect.shtml -O redirect.shtml"
    RACHELBRANDLOGOCAPTIVE="wget -r $GITRACHELPLUS/captive-portal/RACHELbrandLogo-captive.png -O RACHELbrandLogo-captive.png"
    HFCBRANDLOGOCAPTIVE="wget -r $GITRACHELPLUS/captive-portal/HFCbrandLogo-captive.jpg -O HFCbrandLogo-captive.jpg"
    WORLDPOSSIBLEBRANDLOGOCAPTIVE="wget -r $GITRACHELPLUS/captive-portal/WorldPossiblebrandLogo-captive.png -O WorldPossiblebrandLogo-captive.png"
    GITCLONERACHELCONTENTSHELL="git clone https://github.com/rachelproject/contentshell contentshell"
    RSYNCDIR="$RSYNCONLINE"
    ASSESSMENTITEMSJSON="wget -c $GITRACHELPLUS/assessmentitems.json -O /var/ka-lite/data/khan/assessmentitems.json"
    KALITEINSTALL="rsync -avhz --progress $CONTENTONLINE/$KALITEINSTALLER $INSTALLTMPDIR/$KALITEINSTALLER"
    KALITECONTENTINSTALL="rsync -avhz --progress $CONTENTONLINE/kacontent/ /media/RACHEL/kacontent/"
    KIWIXINSTALL="wget -c $WGETONLINE/downloads/public_ftp/z-holding/kiwix-0.9-linux-i686.tar.bz2 -O $RACHELTMPDIR/kiwix-0.9-linux-i686.tar.bz2"
    KIWIXSAMPLEDATA="wget -c $WGETONLINE/downloads/public_ftp/z-holding/Ray_Charles.tar.bz -O $RACHELTMPDIR/Ray_Charles.tar.bz"
    WEAVEDINSTALL="wget -c https://github.com/weaved/installer/raw/master/Intel_CAP/weaved_IntelCAP.tar -O /root/weaved_IntelCAP.tar"
    WEAVEDSINGLEINSTALL="wget -c https://github.com/weaved/installer/raw/master/weaved_software/installer.sh -O /root/weaved_software/installer.sh"
    WEAVEDUNINSTALLER="wget -c https://github.com/weaved/installer/raw/master/weaved_software/uninstaller.sh -O /root/weaved_software/uninstaller.sh"
    SPHIDERPLUSSQLINSTALL="wget -c $WGETONLINE/z-SQLdatabase/sphider_plus.sql -O $RACHELTMPDIR/sphider_plus.sql"
    DOWNLOADCONTENTSCRIPT="wget -c $GITRACHELPLUS/scripts"
    CONTENTWIKI="wget -c http://download.kiwix.org/portable/wikipedia/$FILENAME -O $RACHELTMPDIR/$FILENAME"
}

offlineVariables(){
    GPGKEY1="apt-key add $DIRCONTENTOFFLINE/rachelplus/gpg-keys/437D05B5"
    GPGKEY2="apt-key add $DIRCONTENTOFFLINE/rachelplus/gpg-keys/3E5C1192"
    SOURCEUS="rsync -avhz --progress $DIRCONTENTOFFLINE/rachelplus/sources.list/sources-us.list /etc/apt/sources.list"
    SOURCEUK="rsync -avhz --progress $DIRCONTENTOFFLINE/rachelplus/sources.list/sources-uk.list /etc/apt/sources.list"
    SOURCESG="rsync -avhz --progress $DIRCONTENTOFFLINE/rachelplus/sources.list/sources-sg.list /etc/apt/sources.list"
    SOURCECN="rsync -avhz --progress $DIRCONTENTOFFLINE/rachelplus/sources.list/sources-cn.list /etc/apt/sources.list"
    CAPRACHELFIRSTINSTALL2="rsync -avhz --progress $DIRCONTENTOFFLINE/rachelplus/install/cap-rachel-first-install-2.sh ."
    CAPRACHELFIRSTINSTALL3="rsync -avhz --progress $DIRCONTENTOFFLINE/rachelplus/install/cap-rachel-first-install-3.sh ."
    LIGHTTPDFILE="rsync -avhz --progress $DIRCONTENTOFFLINE/rachelplus/lighttpd.conf ."
    CAPTIVEPORTALREDIRECT="rsync -avhz --progress $DIRCONTENTOFFLINE/rachelplus/captive-portal/captiveportal-redirect.php ."
    PASSTICKETSHTML="rsync -avhz --progress $DIRCONTENTOFFLINE/rachelplus/captive-portal/pass_ticket.shtml ."
    REDIRECTSHTML="rsync -avhz --progress $DIRCONTENTOFFLINE/rachelplus/captive-portal/redirect.shtml ."
    RACHELBRANDLOGOCAPTIVE="rsync -avhz --progress $DIRCONTENTOFFLINE/rachelplus/captive-portal/RACHELbrandLogo-captive.png ."
    HFCBRANDLOGOCAPTIVE="rsync -avhz --progress $DIRCONTENTOFFLINE/rachelplus/captive-portal/HFCbrandLogo-captive.jpg ."
    WORLDPOSSIBLEBRANDLOGOCAPTIVE="rsync -avhz --progress $DIRCONTENTOFFLINE/rachelplus/captive-portal/WorldPossiblebrandLogo-captive.png ."
    GITCLONERACHELCONTENTSHELL=""
    RSYNCDIR="$DIRCONTENTOFFLINE"
    ASSESSMENTITEMSJSON="rsync -avhz --progress $DIRCONTENTOFFLINE/rachelplus/assessmentitems.json /var/ka-lite/data/khan/assessmentitems.json"
    KALITEINSTALL="rsync -avhz --progress $DIRCONTENTOFFLINE/$KALITEINSTALLER $INSTALLTMPDIR/$KALITEINSTALLER"
    KALITECONTENTINSTALL="rsync -avhz --progress $DIRCONTENTOFFLINE/kacontent/ /media/RACHEL/kacontent/"
    KIWIXINSTALL=""
    KIWIXSAMPLEDATA=""
    WEAVEDINSTALL=""
    WEAVEDSINGLEINSTALL=""
    WEAVEDUNINSTALLER=""
    SPHIDERPLUSSQLINSTALL=""
    DOWNLOADCONTENTSCRIPT="rsync -avhz --progress $DIRCONTENTOFFLINE/rachelplus/scripts"
    CONTENTWIKIALL=""
}

printHeader(){
    # Add header/date/time to install log file
    echo; printGood "RACHEL CAP Configuration Script - Version $VERSION"
    printGood "Script started: $(date)"
}

checkInternet(){
    trap ctrlC INT
    if [[ $INTERNET == "1" || -z $INTERNET ]]; then
        # Check internet connecivity
        WGET=`which wget`
        $WGET -q --tries=10 --timeout=5 --spider http://google.com
        if [[ $? -eq 0 ]]; then
            echo; printGood "Internet connection confirmed...continuing install."
            INTERNET=1
        else
            echo; printError "No internet connectivity; waiting 10 seconds and then I will try again."
            # Progress bar to visualize wait period
            while true;do echo -n .;sleep 1;done & 
            sleep 10
            kill $!; trap 'kill $!' SIGTERM
            $WGET -q --tries=10 --timeout=5 --spider http://google.com
            if [[ $? -eq 0 ]]; then
                echo; printGood "Internet connected confirmed...continuing install."
                INTERNET=1
            else
                echo; printError "No internet connectivity; entering 'OFFLINE' mode."
                offlineVariables
                INTERNET=0
            fi
        fi
    fi
}

commandStatus(){
    export EXITCODE="$?"
    if [[ $EXITCODE != 0 ]]; then
        printError "Command failed.  Exit code: $EXITCODE"
        export ERRORCODE="1"
    else
        printGood "Command successful."
    fi
}

checkSHA1(){
    CALCULATEDHASH=$(openssl sha1 $1)
    KNOWNHASH=$(cat $INSTALLTMPDIR/rachelplus/hashes.txt | grep $1 | cut -f1 -d" ")
    if [[ "SHA1(${1})= $2" == "${CALCULATEDHASH}" ]]; then printGood "Good hash!" && export GOODHASH=1; else printError "Bad hash!"  && export GOODHASH=0; fi
}

checkMD5(){
    echo; printStatus "Checking MD5 of: $MD5CHKFILE"
    MD5_1=$(cat $INSTALLTMPDIR/hashes.md5 | grep $(basename $1) | awk '{print $1}')
    if [[ -z $MD5_1 ]]; then printError "Sorry, we do not have a hash for that file in our database."; break; fi
    printStatus "NOTE:  This process may take a minute on larger files...be patient."
    MD5_2=$(md5sum $1 | awk '{print $1}')
    if [[ $MD5_1 != $MD5_2 ]]; then
      printError "MD5 check failed.  Please check your file and the RACHEL log ($RACHELLOG) for errors."
      MD5STATUS=0
    else
      printGood "Yeah...MD5's match; your file is okay."
      MD5STATUS=1
    fi
}

rebootCAP(){
    trap ctrlC INT
    # No log as it won't clean up the tmp file
    echo; printStatus "I need to reboot; new installs will reboot twice more automatically."
    echo; printStatus "The file, $RACHELLOG, will be renamed to a dated log file when the script is complete."
    printStatus "Rebooting in 10 seconds...Ctrl-C to cancel reboot."
    # Progress bar to visualize wait period
    # trap ctrl-c and call ctrlC()
    while true; do
        echo -n .; sleep 1
    done & 
    sleep 10
    kill $!; trap 'kill $!' SIGTERM   
    reboot
}

cleanup(){
    # Store log file
    mv $RACHELLOG $RACHELLOGDIR/cap-rachel-configure-$TIMESTAMP.log
    echo; printGood "Log file saved to: $RACHELLOGDIR/cap-rachel-configure-$TIMESTAMP.log"
    # Provide option to NOT clean up tmp files
    echo; printQuestion "Were there errors?"
    read -p "Enter 'y' to exit without cleaning up temporary folders/files. (y/N) " REPLY
    if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
        exit 1
    fi
    # Deleting the install script commands
    echo; printStatus "Cleaning up install scripts."
    rm -rf $INSTALLTMPDIR $RACHELTMPDIR
    printGood "Done."
    echo; stty sane
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
    rm -rf /recovery/20* $RACHELRECOVERYDIR/20*
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
    echo; printQuestion "Do you want to sanitize this device prior to building the USB image?"
    read -p "    Enter (y/N) " REPLY
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sanitize
    fi
    # Stop script from defaulting the SSID
    sed -i 's/^redis-cli del WlanSsidT0_ssid/#redis-cli del WlanSsidT0_ssid/g' /root/generate_recovery.sh
    # KA Lite
    echo; printStatus "Stopping KA Lite."
#    /var/ka-lite/bin/kalite stop
    kalite stop
    # Delete the Device ID and crypto keys from the database (without affecting the admin user you have already set up)
    echo; printStatus "Delete KA Lite Device ID and clearing crypto keys from the database"
#    /var/ka-lite/bin/kalite manage runcode "from django.conf import settings; settings.DEBUG_ALLOW_DELETIONS = True; from securesync.models import Device; Device.objects.all().delete(); from fle_utils.config.models import Settings; Settings.objects.all().delete()"
    kalite manage runcode "from django.conf import settings; settings.DEBUG_ALLOW_DELETIONS = True; from securesync.models import Device; Device.objects.all().delete(); from fle_utils.config.models import Settings; Settings.objects.all().delete()"
    echo; printQuestion "Do you want to run the /root/generate_recovery.sh script?"
    echo "    The script will save the *.tar.xz files to /media/RACHEL/recovery"
    echo
    echo "    **WARNING** You MUST be logged in via wifi or you will get disconnected and your script will fail during script execution."
    echo
    read -p "    Select 'n' to exit. (y/N) " -r
    if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
        killall screen 2>/dev/null
        rm -rf $0 $INSTALLTMPDIR $RACHELTMPDIR
        chmod 777 /var/run/screen
        screen -dmS generateUSB /root/generate_recovery.sh $RACHELRECOVERYDIR/
        echo; printStatus "Build USB image process started in the background.  You can safely exit out of this shell without affecting it."
        echo "It takes about 45 minutes to create the 3 images; to check the status, type 'screen -r'"
        echo "If you get a reply of 'No screen...', then your image create is complete.  Check $RACHELRECOVERYDIR" 
        echo
    fi
}

symlink(){
    trap ctrlC INT
    echo; printStatus "Symlinking all .mp4 videos in the module 'kaos-en' to $KALITERCONTENTDIR"

    # Write python file for creating symlinks in kaos-en
    cat > /tmp/symlink.py << 'EOF'
import os

def dirs(MyDir):
  if os.path.isdir(MyDir):
    for f in os.listdir(MyDir):
      kaosname = os.path.join(MyDir,f)
      if os.path.isdir(kaosname):
        dirs(kaosname)
      else:
        if os.path.isfile(kaosname):
          ext = os.path.splitext(f)[1]
          if  ext == ".mp4":
            print kaosname
            kalname = os.path.join("/media/RACHEL/kacontent",f)
            if os.path.exists(kalname):
              if os.path.islink(kalname):
                os.unlink(kalname)
                os.rename(kaosname,kalname)
                os.chmod(kalname, 0755)
              elif os.path.isfile(kalname):
                os.unlink(kaosname)
            else:
              os.rename(kaosname,kalname)
            os.symlink(kalname,kaosname)
            os.chmod(kaosname, 0755)
            print kalname
  return

if __name__ == "__main__":
  import sys
  if len(sys.argv) > 1:
    dirs(sys.argv[1])
  else:
    dirs("/media/RACHEL/rachel/modules/kaos-en")
EOF

    # Execute
    python /tmp/symlink.py 2>> $RACHELLOG 1> /dev/null
    rm -f /tmp/symlink.py

    # Write python file for creating symlinks in khan_health
    cat > /tmp/symlink.py << 'EOF'
import os

def dirs(MyDir):
  if os.path.isdir(MyDir):
    for f in os.listdir(MyDir):
      kaosname = os.path.join(MyDir,f)
      if os.path.isdir(kaosname):
        dirs(kaosname)
      else:
        if os.path.isfile(kaosname):
          ext = os.path.splitext(f)[1]
          if  ext == ".mp4":
            print kaosname
            kalname = os.path.join("/media/RACHEL/kacontent",f)
            if os.path.exists(kalname):
              if os.path.islink(kalname):
                os.unlink(kalname)
                os.rename(kaosname,kalname)
                os.chmod(kalname, 0755)
              elif os.path.isfile(kalname):
                os.unlink(kaosname)
            else:
              os.rename(kaosname,kalname)
            os.symlink(kalname,kaosname)
            os.chmod(kaosname, 0755)
            print kalname
  return

if __name__ == "__main__":
  import sys
  if len(sys.argv) > 1:
    dirs(sys.argv[1])
  else:
    dirs("/media/RACHEL/rachel/modules/khan_health")
EOF

    # Execute
    python /tmp/symlink.py 2>> $RACHELLOG 1> /dev/null
    rm -f /tmp/symlink.py

    printGood "Done."
}

kiwix(){
    echo; printStatus "Installing kiwix."
    $KIWIXINSTALL
    if [[ $INTERNET == "0" ]]; then cd $DIRCONTENTOFFLINE; else cd $RACHELTMPDIR; fi
    tar -C /var -xjvf kiwix-0.9-linux-i686.tar.bz2
    chown -R root:root /var/kiwix
    # Make content directory
    mkdir -p /media/RACHEL/kiwix
    echo; printQuestion "Kiwix will not start successfully until either the sample data or actual content is installed."
    read -p "Do you want to download a small sample data file? (y/n) " -r
    if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
        $KIWIXSAMPLEDATA
        # Download a test file
        tar -C /media/RACHEL/kiwix -xjvf Ray_Charles.tar.bz
        cp /media/RACHEL/kiwix/data/library/wikipedia_en_ray_charles_2015-06.zim.xml  /media/RACHEL/kiwix/data/library/library.xml
        rm Ray_Charles.tar.bz
    fi
    # Start up Kiwix
    echo; printStatus "Starting Kiwix server."
    /var/kiwix/bin/kiwix-serve --daemon --port=81 --library /media/RACHEL/kiwix/data/library/library.xml
    echo; printStatus "Setting Kiwix to start on boot."
    # Remove old kiwix boot lines from $RACHELSCRIPTSFILE
    sed -i '/kiwix/d' $RACHELSCRIPTSFILE
    # Clean up current rachel-scripts.sh file
    sed -i '/kiwix/d' $RACHELSCRIPTSFILE
    # Add lines to $RACHELSCRIPTSFILE that will start kiwix on boot
    sed -i '$e echo "\# Start kiwix on boot"' $RACHELSCRIPTSFILE
    sed -i '$e echo "\/var\/kiwix\/bin\/kiwix-serve --daemon --port=81 --library \/media\/RACHEL\/kiwix\/data\/library\/library.xml"' $RACHELSCRIPTSFILE
}

sphider_plus.sql(){
RESULT=`mysqlshow --user=root --password=root sphider_plus| grep -v Wildcard | grep -o sphider_plus`
if [ "$RESULT" == "sphider_plus" ]; then
    echo; printError "The sphider_plus database is already installed."
else
    echo; printStatus "Installing sphider_plus.sql...be patient, this takes a couple minutes."
    $SPHIDERPLUSSQLINSTALL
    if [[ $INTERNET == "0" ]]; then cd $DIRCONTENTOFFLINE; else cd $RACHELTMPDIR; fi
    echo "create database sphider_plus" | mysql -u root -proot
    mysql -u root -proot sphider_plus < sphider_plus.sql
fi
}

installDefaultWeavedServices(){
    echo; printStatus "Installing Weaved service."
    cd /root
    # Download weaved files
    echo; printStatus "Downloading required files."
    $WEAVEDINSTALL
    commandStatus

    tar xvf weaved_IntelCAP.tar
    commandStatus
    if [[ $ERRORCODE == 0 ]] && [[ -d /root/weaved_software ]]; then
        rm -f /root/weaved_IntelCAP.tar
        echo; printGood "Done."
        # Run installer
        cd /root/weaved_software
        bash install.sh
        echo; printGood "Weaved service install complete."
        printGood "NOTE: An Weaved service uninstaller is available from the Utilities menu of this script."
    else
        echo; printError "One or more files did not download correctly; check log file ($RACHELLOG) and try again."
        cleanup
        echo; exit 1
    fi
}

installWeavedService(){
    if [[ $INTERNET == "0" ]]; then
        echo; printError "The CAP must be online to install/remove Weaved services."
    else
        echo; printStatus "Installing Weaved service."
        cd /root

        # Download weaved files
        echo; printStatus "Downloading required files."
        $WEAVEDSINGLEINSTALL
        commandStatus

        if [[ $ERRORCODE == 0 ]] && [[ -f /root/weaved_software/installer.sh ]]; then
            # Fix OS Arch check in installer.sh
            sed -i 's/\[ "$machineType" = "x86_64" \] && \[ "$osName" = "Linux" \]/\[ "$osName" = "Linux" \]/g' /root/weaved_software/installer.sh
            sed -i 's/\.\/bin/\./g' /root/weaved_software/installer.sh
            # Download required files
            mkdir -p /root/weaved_software/enablements
            wget -c https://github.com/weaved/installer/raw/master/weaved_software/enablements/ssh.linux -O /root/weaved_software/enablements/ssh.linux
            wget -c https://github.com/weaved/installer/raw/master/weaved_software/enablements/tcp.linux -O /root/weaved_software/enablements/tcp.linux
            wget -c https://github.com/weaved/installer/raw/master/weaved_software/enablements/vnc.linux -O /root/weaved_software/enablements/vnc.linux
            wget -c https://github.com/weaved/installer/raw/master/weaved_software/enablements/web.linux -O /root/weaved_software/enablements/web.linux
            wget -c https://github.com/weaved/installer/raw/master/weaved_software/enablements/webssh.linux -O /root/weaved_software/enablements/webssh.linux
            wget -c https://github.com/weaved/installer/raw/master/weaved_software/enablements/webport.pi -O /root/weaved_software/enablements/webport.pi
            wget -c https://github.com/weaved/installer/raw/master/weaved_software/enablements/webiopi.pi -O /root/weaved_software/enablements/webiopi.pi
            wget -c https://github.com/weaved/installer/raw/master/weaved_software/Yo -O /root/weaved_software/Yo
            wget -c https://github.com/weaved/installer/raw/master/weaved_software/scripts/notify.sh -O /root/weaved_software/notify.sh
            wget -c https://github.com/weaved/installer/raw/master/weaved_software/scripts/send_notification.sh -O /root/weaved_software/send_notification.sh
            chmod +x /root/weaved_software/*.sh /root/weaved_software/Yo
            sed -i 's|/scripts||g' /root/weaved_software/installer.sh
            echo; printGood "Done."
            # Run installer
            cd /root/weaved_software
            bash installer.sh

            echo; printGood "Weaved service install complete."
            printGood "NOTE: An Weaved service uninstaller is available from the Utilities menu of this script."
        else
            echo; printError "One or more files did not download correctly; check log file ($RACHELLOG) and try again."
            cleanup
            echo; exit 1
        fi
    fi
}

uninstallAllWeavedServices(){
    echo; printStatus "Uninstalling Weaved service."

    TMP_DIR=/tmp
    # Stop all Weaved services
    for i in `ls /usr/bin/Weaved*.sh`; do
        $i stop
    done

    # Remove Weaved files
    rm /usr/bin/weaved*
    rm /usr/bin/Weaved*
    rm -rf /etc/weaved

    # Remove Weaved from crontab
    crontab -l | grep -v weaved | cat > $TMP_DIR/.crontmp
    crontab $TMP_DIR/.crontmp

    # Ensure user knows to remove from online service list
    echo; printStatus "If you uninstalled Weaved connectd without deleting Services first,"
    echo "there may be orphaned Services in your Services List.  Use the "
    echo "'Settings' link in the web portal Services List to delete these."

    echo; printGood "Weaved service uninstall complete."
}


uninstallWeavedService(){
    weavedUninstaller(){
        bash /root/weaved_software/uninstaller.sh
        echo; printGood "Weaved service uninstall complete."
    }
    echo; printStatus "Uninstalling Weaved service."
    cd /root
    # Run uninstaller
    if [[ -f /root/weaved_software/uninstaller.sh ]]; then 
        weavedUninstaller
    else
        printError "The Weaved uninstaller does not exist. Attempting to download..."
        if [[ $INTERNET == "1" ]]; then
            $WEAVEDUNINSTALLER
            commandStatus
            if [[ $ERRORCODE == 0 ]] && [[ -f /root/weaved_software/uninstaller.sh ]]; then
                weavedUninstaller
            else
                printError "Download failed; check log file ($RACHELLOG) and try again."
            fi
        else
            printError "No internet connection; I can not download the uninstaller."
            echo "    Connect the CAP to the internet and try the uninstaller again."
        fi
    fi
}

backupWeavedService(){
    # Clear current configs
    stty sane
    if [[ `find /etc/weaved/services/ -name 'Weaved*.conf' 2>/dev/null | wc -l` -ge 1 ]]; then
        echo; printStatus "Backing up configuration files to $RACHELRECOVERYDIR/weaved"
        rm -rf $RACHELRECOVERYDIR/Weaved
        mkdir -p $RACHELRECOVERYDIR/Weaved
        # Backup Weaved configs
        cp -f /etc/weaved/services/Weaved*.conf /usr/bin/Weaved*.sh /usr/bin/notify_Weaved*.sh $RACHELRECOVERYDIR/Weaved/ 2>/dev/null
        printGood "Your current configuration is backed up and will be restored if you have to run the USB Recovery."
    elif [[ ! -d /etc/weaved ]]; then
        # Weaved is no longer installed, remove all backups
        rm -rf $RACHELRECOVERYDIR/Weaved
    else
        echo; printError "You do not have any Weaved configuration files to backup."
    fi
    # Add Weaved restore back into rachel-scripts.sh
    # Clean rachel-scripts.sh
    sed -i '/Weaved/d' $RACHELSCRIPTSFILE
    # Write restore commands to rachel-scripts.sh
    sudo sed -i '5 a # Restore Weaved configs, if needed' $RACHELSCRIPTSFILE
    sudo sed -i '6 a echo \$(date) - Checking Weaved install' $RACHELSCRIPTSFILE
    sudo sed -i '7 a if [[ -d '$RACHELRECOVERYDIR'/Weaved ]] && [[ `ls /usr/bin/Weaved*.sh 2>/dev/null | wc -l` == 0 ]]; then' $RACHELSCRIPTSFILE
    sudo sed -i '8 a echo \$(date) - Weaved backup files found but not installed, recovering now' $RACHELSCRIPTSFILE
    sudo sed -i '9 a mkdir -p /etc/weaved/services #Weaved' $RACHELSCRIPTSFILE
    sudo sed -i '10 a cp '$RACHELRECOVERYDIR'/Weaved/Weaved*.conf /etc/weaved/services/' $RACHELSCRIPTSFILE
    sudo sed -i '11 a cp '$RACHELRECOVERYDIR'/Weaved/*.sh /usr/bin/' $RACHELSCRIPTSFILE
    sudo sed -i '12 a reboot #Weaved' $RACHELSCRIPTSFILE
    sudo sed -i '13 a fi #Weaved' $RACHELSCRIPTSFILE
}

downloadOfflineContent(){
    trap ctrlC INT
    printHeader
    echo; printStatus "** BETA ** Downloading RACHEL content for OFFLINE installs."

    echo; printQuestion "The OFFLINE RACHEL content folder is set to:  $DIRCONTENTOFFLINE"
    read -p "    Do you want to change the default location? (y/n) " -r
    if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
        echo; printQuestion "What is the location of your content folder? "; read DIRCONTENTOFFLINE
        if [[ ! -d $DIRCONTENTOFFLINE ]]; then
            echo; printError "The folder location does not exist!  Please identify the full path to your OFFLINE content folder and try again."
            rm -rf $INSTALLTMPDIR $RACHELTMPDIR
            exit 1
        fi
    fi
    wget -c $WGETONLINE/downloads/public_ftp/z-holding/dirlist.txt -O $DIRCONTENTOFFLINE/dirlist.txt        
    # List the current directories on rachelfriends with this command:
    #   for i in $(ls -d */); do echo ${i%%/}; done
    if [[ ! -f $DIRCONTENTOFFLINE/dirlist.txt ]]; then
        echo; printError "The file $DIRCONTENTOFFLINE/dirlist.txt is missing!"
        echo "    This file is a list of rsync folders; without it, I don't know what to rsync."
        echo "    Create a newline separated list of directories to rsync in a file called 'dirlist.txt'."
        echo "    Put the file in the same directory $DIRCONTENTOFFLINE"
    else
        echo; printStatus "Rsyncing core RACHEL content from $RSYNCONLINE"
        while read p; do
            echo; rsync -avz --ignore-existing $RSYNCONLINE/rachelmods/$p $DIRCONTENTOFFLINE/rachelmods
            commandStatus
        done<$DIRCONTENTOFFLINE/dirlist.txt
        printGood "Done."
    fi
    printStatus "Downloading/updating the GitHub repo:  rachelplus"
    if [[ -d $DIRCONTENTOFFLINE/rachelplus ]]; then 
        cd $DIRCONTENTOFFLINE/rachelplus; git fetch; git reset --hard origin
    else
        echo; git clone https://github.com/rachelproject/rachelplus $DIRCONTENTOFFLINE/rachelplus
    fi
    commandStatus
    printGood "Done."

    echo; printStatus "Downloading/updating the GitHub repo:  contentshell"
    if [[ -d $DIRCONTENTOFFLINE/contentshell ]]; then 
        cd $DIRCONTENTOFFLINE/contentshell; git fetch; git reset --hard origin
    else
        echo; git clone https://github.com/rachelproject/contentshell $DIRCONTENTOFFLINE/contentshell
    fi
    commandStatus
    printGood "Done."

    echo; printStatus "Checking/downloading:  KA Lite"
    if [[ -f $DIRCONTENTOFFLINE/$KALITEINSTALLER ]]; then
        # Checking user provided file MD5 against known good version
        checkMD5 $DIRCONTENTOFFLINE/$KALITEINSTALLER
        if [[ $MD5STATUS == 0 ]]; then
            # Downloading current version of KA Lite
            echo; printStatus "Downloading KA Lite Version $KALITECURRENTVERSION"
            $KALITEINSTALL
            commandStatus
            mv $INSTALLTMPDIR/$KALITEINSTALLER $DIRCONTENTOFFLINE/$KALITEINSTALLER
        fi
    fi
    commandStatus
    printGood "Done."

    # Download ka-lite_content.zip
    echo; printStatus "Downloading/updating:  KA Lite content media files"
    rsync -avhP $CONTENTONLINE/kacontent $DIRCONTENTOFFLINE
    commandStatus
    printGood "Done."

    echo; printStatus "Downloading/updating kiwix and data."
    wget -c $WGETONLINE/downloads/public_ftp/z-holding/kiwix-0.9-linux-i686.tar.bz2 -O $DIRCONTENTOFFLINE/kiwix-0.9-linux-i686.tar.bz2
    wget -c $WGETONLINE/downloads/public_ftp/z-holding/Ray_Charles.tar.bz -O $DIRCONTENTOFFLINE/Ray_Charles.tar.bz
    wget -c http://download.kiwix.org/portable/wikipedia/kiwix-0.9+wikipedia_en_for-schools_2013-01.zip -O $DIRCONTENTOFFLINE/kiwix-0.9+wikipedia_en_for-schools_2013-01.zip
    wget -c http://download.kiwix.org/portable/wikipedia/kiwix-0.9+wikipedia_en_all_2015-05.zip -O $DIRCONTENTOFFLINE/kiwix-0.9+wikipedia_en_all_2015-05.zip

    printGood "Done."

    echo; printStatus "Downloading/updating sphider_plus.sql"
    wget -c $WGETONLINE/z-SQLdatabase/sphider_plus.sql -O $DIRCONTENTOFFLINE/sphider_plus.sql
    commandStatus
    printGood "Done."

    # Downloading deb packages
    echo; printStatus "Downloading/updating Git and PHP."
    mkdir $DIRCONTENTOFFLINE/offlinepkgs
    cd $DIRCONTENTOFFLINE/offlinepkgs
    apt-get download php5-cgi php5-common php5-mysql php5-sqlite git git-man liberror-perl python-m2crypto mysql-server mysql-client libapache2-mod-auth-mysql
    printGood "Done."

    # Show list of expected downloaded content
    echo; printGood "Download of offline content complete."
    echo; echo "You should have the following in your offline repository:  $DIRCONTENTOFFLINE"    
    echo "- - - - - - - - - - - -" 
    echo "contentshell [folder]"
    echo "kacontent [folder]"
    echo "$KALITEINSTALLER [file]"
    echo "$KIWIXINSTALLER [file]"
    echo "$KIWIXWIKIALL [file]"
    echo "$KIWIXWIKISCHOOLS [file]"
    echo "offlinekgs [folder]"
    echo "rachelplus [folder]"
    echo "Ray_Charles.tar.bz [file]"
    echo "sphider_plus.sql [file]"
    echo "rachelmods [folder with the following folders]:"
    cat /tmp/module.lst

    echo; printStatus "This is your current offline directory listing:"
    echo "- - - - - - - - - - - -" 
    ls -l $DIRCONTENTOFFLINE/
    echo; echo "Modules downloaded:"
    ls -l $DIRCONTENTOFFLINE/rachelmods/
}

newInstall(){
    trap ctrlC INT
    printHeader
    echo; printStatus "Conducting a new install of RACHEL on a CAP."

    cd $INSTALLTMPDIR

    # Fix hostname issue in /etc/hosts
    echo; printStatus "Fixing hostname in /etc/hosts"
    sed -i 's/ec-server/WRTD-303N-Server/g' /etc/hosts
    printGood "Done."

    ## sources.list - replace the package repos for more reliable ones (/etc/apt/sources.list)
    # Backup current sources.list
    cp /etc/apt/sources.list /etc/apt/sources.list.bak

    # Change the source repositories
    echo; printStatus "Locations for downloading packages:"
    echo "    US) United States"
    echo "    UK) United Kingdom"
    echo "    SG) Singapore"
    echo "    CN) China (CAP Manufacturer's Site)"
    echo; printQuestion "For the package downloads, select the location nearest you? "
    select CLASS in "US" "UK" "SG" "CN"; do
        case $CLASS in
        # US
        US)
            echo; printStatus "Downloading packages from the United States."
            $SOURCEUS
            commandStatus
            break
        ;;

        # UK
        UK)
            echo; printStatus "Downloading packages from the United Kingdom."
            $SOURCEUK
            commandStatus
            break
        ;;

        # Singapore
        SG)
            echo; printStatus "Downloading packages from Singapore."
            $SOURCESG
            commandStatus
            break
        ;;

        # China (Original)
        CN)
            echo; printStatus "Downloading packages from the China - CAP manufacturer's website."
            $SOURCECN
            commandStatus
            break
        ;;
        esac
        printGood "Done."
        break
    done

    # Download/stage GitHub files to $INSTALLTMPDIR
    echo; printStatus "Downloading RACHEL install scripts for CAP to the temp folder $INSTALLTMPDIR."
    ## cap-rachel-first-install-2.sh
    echo; printStatus "Downloading cap-rachel-first-install-2.sh"
    $CAPRACHELFIRSTINSTALL2
    commandStatus
    ## cap-rachel-first-install-3.sh
    echo; printStatus "Downloading cap-rachel-first-install-3.sh"
    $CAPRACHELFIRSTINSTALL3
    commandStatus
    ## lighttpd.conf - RACHEL version (I don't overwrite at this time due to other dependencies)
    echo; printStatus "Downloading lighttpd.conf"
    $LIGHTTPDFILE
    commandStatus

    # Download RACHEL Captive Portal files
    echo; printStatus "Downloading Captive Portal content to $INSTALLTMPDIR."

    echo; printStatus "Downloading captiveportal-redirect.php."
    $CAPTIVEPORTALREDIRECT
    commandStatus

    echo; printStatus "Downloading RACHELbrandLogo-captive.png."
    $RACHELBRANDLOGOCAPTIVE
    commandStatus
    
    echo; printStatus "Downloading HFCbrandLogo-captive.jpg."
    $HFCBRANDLOGOCAPTIVE
    commandStatus
    
    echo; printStatus "Downloading WorldPossiblebrandLogo-captive.png."
    $WORLDPOSSIBLEBRANDLOGOCAPTIVE
    commandStatus

    # Check if files downloaded correctly
    if [[ $ERRORCODE == 0 ]]; then
        echo; printGood "Done."
    else
        echo; printError "One or more files did not download correctly; check log file ($RACHELLOG) and try again."
        cleanup
        echo; exit 1
    fi

    # Show location of the log file
    echo; printStatus "Directory of RACHEL install log files with date/time stamps:"
    echo "$RACHELLOGDIR"

    # Ask if you are ready to install
    echo; printError "WARNING:  This will completely wipe your CAP and restore to RACHEL defaults."
    echo "Any downloaded modules WILL be erased during this process."

    echo; read -p "Are you ready to start the install? (y/n) " -r
    if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
        # Add rachel-scripts.sh script - because it doesn't exist
        sed "s,%RACHELSCRIPTSLOG%,$RACHELSCRIPTSLOG,g" > $RACHELSCRIPTSFILE << 'EOF'
#!/bin/bash
# Send output to log file
rm -f %RACHELSCRIPTSLOG%
exec 1>> %RACHELSCRIPTSLOG% 2>&1
exit 0
EOF

        # Delete previous setup commands from the $RACHELSCRIPTSFILE
        echo; printStatus "Delete previous RACHEL setup commands from $RACHELSCRIPTSFILE"
        sed -i '/cap-rachel/d' $RACHELSCRIPTSFILE
        printGood "Done."

        echo; printStatus "Starting first install script...please wait patiently (about 30 secs) for first reboot."
        printStatus "The entire script (with reboots) takes 2-5 minutes."

        # Update CAP package repositories
        echo; printStatus "Updating CAP package repositories"
        $GPGKEY1
        $GPGKEY2
        apt-get clean; apt-get purge; apt-get update
        printGood "Done."

        # Install packages
        echo; printStatus "Installing packages."
        apt-get -y install php5-cgi git-core python-m2crypto php5-sqlite
        # Add the following line at the end of file
        echo "cgi.fix_pathinfo = 1" >> /etc/php5/cgi/php.ini
        printGood "Done."

        # Checking contentshell is located at /media/RACHEL/rachel
        echo; printStatus "Cloning the RACHEL content shell from GitHub into $(pwd)"
        rm -rf contentshell # in case of previous failed install
        $GITCLONERACHELCONTENTSHELL

        # Install MySQL client and server
        echo; printStatus "Installing mysql client and server."
        debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
        debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'
        cd /
        chown root:root /tmp
        chmod 1777 /tmp
        apt-get -y remove --purge mysql-server mysql-client mysql-common
        apt-get -y install mysql-server mysql-client libapache2-mod-auth-mysql php5-mysql
        printGood "Done."

        # Overwrite the lighttpd.conf file with our customized RACHEL version
        echo; printStatus "Updating lighttpd.conf to RACHEL version"
        mv $INSTALLTMPDIR/lighttpd.conf /usr/local/etc/lighttpd.conf
        printGood "Done."

        cat > /etc/fstab << EOF
# <filesystem> <mountpoint> <type> <options> <dump> <pass>
proc    /proc   proc    nodev,noexec,nosuid     0       0
UUID=44444444-4444-4444-4444-444444444444       /       ext4    nobootwait,errors=remount-ro    0       1
UUID=33333333-3333-3333-3333-333333333333       /boot   ext4    defaults        0       2
UUID=DEAD-BEEF  /boot/efi       vfat    utf8,umask=007,gid=46   0       0
UUID=55555555-5555-5555-5555-555555555555       /recovery       ext4    defaults        0       0
UUID=66666666-6666-6666-6666-666666666666       none    swap    sw      0       0
EOF

        # Repartition external 500GB hard drive into 3 partitions
        echo; printStatus "Backup current partition table to /root/gpt.backup"
        sgdisk -b /root/gpt.backup /dev/sda
        echo; printStatus "Unmounting any mounted partitions."
        umount /dev/sda1 /dev/sda2
        echo; printStatus "Repartitioning hard drive"
        sgdisk -p /dev/sda
        sgdisk -o /dev/sda
        parted -s /dev/sda mklabel gpt
        sgdisk -n 1:2048:41945087 -c 1:"preloaded" -u 1:77777777-7777-7777-7777-777777777777 -t 1:8300 /dev/sda
        sgdisk -n 2:41945088:251660287 -c 2:"uploaded" -u 2:88888888-8888-8888-8888-888888888888 -t 2:8300 /dev/sda
    #            sgdisk -n 2:21G:+100G -c 2:"uploaded" -u 2:88888888-8888-8888-8888-888888888888 -t 2:8300 /dev/sda
        sgdisk -n 3:251660288:-1M -c 3:"RACHEL" -u 3:99999999-9999-9999-9999-999999999999 -t 3:8300 /dev/sda
    #            sgdisk -n 3:122G:-1M -c 3:"RACHEL" -u 3:99999999-9999-9999-9999-999999999999 -t 3:8300 /dev/sda
        sgdisk -p /dev/sda
        printGood "Done."

        # Add rachel-scripts.sh startup in /etc/rc.local
        sed -i '/rachel/d' /etc/rc.local
        sudo sed -i '$e echo "# Add rachel startup scripts"' /etc/rc.local
        sudo sed -i '$e echo "bash /root/rachel-scripts.sh&"' /etc/rc.local

        # Add lines to $RACHELSCRIPTSFILE that will start the next script to run on reboot
        sudo sed -i '$e echo "bash '$INSTALLTMPDIR'\/cap-rachel-first-install-2.sh&"' $RACHELSCRIPTSFILE

        echo; printGood "RACHEL CAP Install - Script ended at $(date)"
        rebootCAP
    else
        echo; printError "User requests not to continue...exiting at $(date)"
        # Deleting the install script commands
        cleanup
        echo; exit 1
    fi
}

checkContentShell(){
    # Clone or update the RACHEL content shell from GitHub
    if [[ $INTERNET == "0" ]]; then cd $DIRCONTENTOFFLINE; else cd $INSTALLTMPDIR; fi
    echo; printStatus "Checking for pre-existing RACHEL content shell."
    if [[ ! -d $RACHELWWW ]]; then
        printStatus "RACHEL content shell does not exist at $RACHELWWW."
        printStatus "Cloning the RACHEL content shell from GitHub into $(pwd)"
        rm -rf contentshell # in case of previous failed install
        $GITCLONERACHELCONTENTSHELL
    else
        if [[ ! -d $RACHELWWW/.git ]]; then
            echo; printStatus "$RACHELWWW exists but it wasn't installed from git; installing RACHEL content shell from GitHub."
            rm -rf contentshell # in case of previous failed install
            $GITCLONERACHELCONTENTSHELL
            cp -rf contentshell/* $RACHELWWW/ # overwrite current content with contentshell
            cp -rf contentshell/.git $RACHELWWW/ # copy over GitHub files
        else
            echo; printStatus "$RACHELWWW exists; updating RACHEL content shell from GitHub."
            cd $RACHELWWW; git pull
        fi
    fi
    printStatus "Restarting lighttpd web server to activate changes."
    killall lighttpd
    printGood "Done."
}

contentModuleInstall(){
    trap ctrlC INT
    if [[ -f /tmp/module.lst ]]; then
        echo; printStatus "Your selected module list:"
        # Sort/unique the module list
        cat /tmp/module.lst
        echo; printQuestion "Do you want to use this module list?"
        read -p "    Enter (Y/n) " REPLY
        if [[ $REPLY =~ ^[Nn]$ ]]; then rm -f /tmp/module.lst; fi
    fi
    SELECTMODULE=1
    MODULELIST=$(rsync --list-only rsync://dev.worldpossible.org/rachelmods | egrep '^d' | awk '{print $5}' | tail -n +2)
    while [[ $SELECTMODULE == 1 ]]; do
        echo; printStatus "What RACHEL module would you like to select for download or update?"
        echo "(Ctrl-C to cancel module install)"
        echo
        select module in $MODULELIST; do 
            echo "$module" >> /tmp/module.lst
            echo; printStatus "Added module $module to the install/update cue."
            break
        done
        echo; printStatus "Your selected module list:"
        sort -u /tmp/module.lst > /tmp/module.tmp; mv /tmp/module.tmp /tmp/module.lst
        cat /tmp/module.lst
        echo; printQuestion "Do you want to select another module?"
        read -p "    Enter (y/N) " REPLY
        if [[ $REPLY =~ ^[Yy]$ ]]; then SELECTMODULE=1; else SELECTMODULE=0; fi
    done
    echo; printQuestion "Are you ready to install your selected modules?"
    read -p "    Enter (y/N) " REPLY
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        while read m; do
            echo; printStatus "Downloading $m"
            rsync -avz $RSYNCDIR/rachelmods/$m $RACHELWWW/modules/
            commandStatus
            printGood "Done."
        done < /tmp/module.lst
    fi
    rm -f /tmp/module.lst
}

contentListInstall(){
    trap ctrlC INT
    printHeader
    ERRORCODE="0"
    echo; printStatus "Installing RACHEL content."
    if [[ $INTERNET == "0" ]]; then cd $DIRCONTENTOFFLINE; else cd $RACHELTMPDIR; fi

    # Add header/date/time to install log file
    echo; printError "CAUTION:  This process may take quite awhile if you do you not have a fast network connection."
    echo "If you get disconnected, you only have to rerun this install again to continue.  It will not re-download content already on the CAP."

    if [[ -d $RACHELWWW/modules ]]; then
        # Check permissions on modules
        echo; printStatus "Verifying proper permissions on modules prior to install."
        chown -R root:root $RACHELWWW/modules
        printGood "Done."
    else
        # Create a modules directory
        mkdir $RACHELWWW/modules
    fi

    echo; printQuestion "What content you would like to install:"
    echo "  - [English] - English content"
    echo "  - [Español] - Español content"
    echo "  - [Français] - Français content"
    echo "  - [Português] - Português content"
    echo "  - [Hindi] - Hindi content"
    echo "  - Exit to the [Main Menu]"
    echo
    select menu in "English" "Español" "Français" "Português" "Hindi" "Main-Menu"; do
        case $menu in
        English)
        echo; printQuestion "What content you would like to install:"
        echo "  - [English-KA] - English content based on KA"
        echo "  - [English-Kaos] - English content based on Kaos"
        echo "  - [English-Justice] - English content for Justice"
        echo "  - Exit to [Content-Menu]"
        echo
        select submenu in "English-KALite" "English-KAOS" "English-Justice" "Kiwix-Wikipedia-ALL" "Kiwix-Wikipedia-Schools" "Return"; do
            case $submenu in
            English-KALite)
            printStatus "Installing content for English (KA Lite)."
            $DOWNLOADCONTENTSCRIPT/en_all_kalite.lst .
            while read p; do
                echo; printStatus "Downloading $p"
                rsync -avz $RSYNCDIR/rachelmods/$p $RACHELWWW/modules/
                commandStatus
                printGood "Done."
            done <en_all_kalite.lst
            break
            ;;

            English-KAOS)
            printStatus "Installing content for English (KA Lite)."
            $DOWNLOADCONTENTSCRIPT/en_all_kaos.lst .
            while read p; do
                echo; printStatus "Downloading $p"
                rsync -avz $RSYNCDIR/rachelmods/$p $RACHELWWW/modules/
                commandStatus
                printGood "Done."
            done <en_all_kaos.lst
            break
            ;;

            English-Justice)
            printStatus "Installing content for English (Justice)."
            $DOWNLOADCONTENTSCRIPT/en_justice.lst .
            while read p; do
                echo; printStatus "Downloading $p"
                rsync -avz $RSYNCDIR/rachelmods/$p $RACHELWWW/modules/
                commandStatus
                printGood "Done."
            done <en_justice.lst
            break
            ;;

            Kiwix-Wikipedia-ALL)
            FILENAME="kiwix-0.9+wikipedia_en_all_2015-05.zip"
            FILES=$(ls $RACHELPARTITION/kiwix/data/content/wikipedia_en_all_2015-05.zim* 2> /dev/null | wc -l)
            if [[ $FILES != "0" ]]; then
                echo; printError "The full Wikipedia is already installed."
                if [[ ! -f $RACHELPARTITION/kiwix/data/library/library.xml ]]; then
                    echo; printError "The database seems to be corrupt, repairing."
                    echo; /var/kiwix/bin/kiwix-manage $RACHELPARTITION/kiwix/data/library/library.xml add $RACHELPARTITION/kiwix/data/content/wikipedia_en_all_2015-05.zim --indexPath=$RACHELPARTITION/kiwix/data/index/wikipedia_en_all_2015-05.zim.idx
                    echo; killall /var/kiwix/bin/kiwix-serve
                    echo; /var/kiwix/bin/kiwix-serve --daemon --port=81 --library /media/RACHEL/kiwix/data/library/library.xml
                    if [[ ! -f $RACHELPARTITION/kiwix/data/library/library.xml ]]; then
                        printError "Repair failed.  Please review the log file for additional details."
                    fi
                fi
            else
                echo; printStatus "Installing Kiwix content - Wikipedia ALL."
                $CONTENTWIKI
                commandStatus
                unzip -o $FILENAME "data/*" -d "$RACHELPARTITION/kiwix/"
                if [[ $ERRORCODE == 1 ]]; then
                    echo; printError "The zip file did not download correctly; if you want to try again, click 'yes' when it asks"
                    echo "  if there were errors. The download will then continue where it left off."
                    echo "  For more information, check the log file ($RACHELLOG)."
                else
                    /var/kiwix/bin/kiwix-manage $RACHELPARTITION/kiwix/data/library/library.xml add $RACHELPARTITION/kiwix/data/content/wikipedia_en_all_2015-05.zim --indexPath=$RACHELPARTITION/kiwix/data/index/wikipedia_en_all_2015-05.zim.idx
                    killall /var/kiwix/bin/kiwix-serve
                    /var/kiwix/bin/kiwix-serve --daemon --port=81 --library /media/RACHEL/kiwix/data/library/library.xml
                fi
            fi
            echo; printGood "View your module by clicking on Wikipedia from the RACHEL homepage."
            printGood "Done."
            break
            ;;

            Kiwix-Wikipedia-Schools)
            FILENAME="kiwix-0.9+wikipedia_en_for-schools_2013-01.zip"
            FILES=$(ls $RACHELPARTITION/kiwix/data/content/wikipedia_en_for_schools_opt_2013.zim* 2> /dev/null | wc -l)
            if [[ $FILES != "0" ]]; then
                echo; printError "Wikipedia for Schools is already installed."                
                if [[ ! -f $RACHELPARTITION/kiwix/data/library/library.xml ]]; then
                    echo; printError "The database seems to be corrupt, repairing."
                    echo; /var/kiwix/bin/kiwix-manage $RACHELPARTITION/kiwix/data/library/library.xml add $RACHELPARTITION/kiwix/data/content/wikipedia_en_for_schools_opt_2013.zim --indexPath=$RACHELPARTITION/kiwix/data/index/wikipedia_en_for_schools_opt_2013.zim.idx
                    echo; killall /var/kiwix/bin/kiwix-serve
                    echo; /var/kiwix/bin/kiwix-serve --daemon --port=81 --library /media/RACHEL/kiwix/data/library/library.xml
                    if [[ ! -f $RACHELPARTITION/kiwix/data/library/library.xml ]]; then
                        printError "Repair failed.  Please review the log file for additional details."
                    fi
                fi
            else
                echo; printStatus "Installing Kiwix content - Wikipedia for Schools."
                $CONTENTWIKI
                commandStatus
                unzip -o $FILENAME "data/*" -d "$RACHELPARTITION/kiwix/"
                if [[ $ERRORCODE == 1 ]]; then
                    echo; printError "The zip file did not download correctly; if you want to try again, click 'yes' when it asks"
                    echo "  if there were errors. The download will then continue where it left off."
                    echo "  For more information, check the log file ($RACHELLOG)."
                else
                    echo; /var/kiwix/bin/kiwix-manage $RACHELPARTITION/kiwix/data/library/library.xml add $RACHELPARTITION/kiwix/data/content/wikipedia_en_for_schools_opt_2013.zim --indexPath=$RACHELPARTITION/kiwix/data/index/wikipedia_en_for_schools_opt_2013.zim.idx
                    echo; killall /var/kiwix/bin/kiwix-serve
                    echo; /var/kiwix/bin/kiwix-serve --daemon --port=81 --library /media/RACHEL/kiwix/data/library/library.xml
                fi
            fi
            printGood "View your module by clicking on Wikipedia from the RACHEL homepage."
            printGood "Done."
            break
            ;;

            Return)
            break
            ;;
            esac
        done
        break
        ;;

        Español)
        printStatus "Installing content for Español."
        $DOWNLOADCONTENTSCRIPT/es_all_kaos.lst .
        while read p; do
            echo; printStatus "Downloading $p"
            rsync -avz $RSYNCDIR/rachelmods/$p $RACHELWWW/modules/
            commandStatus
            printGood "Done."
        done <es_all_kaos.lst
        break
        ;;

        Français)
        printStatus "Installing content for Français."
        $DOWNLOADCONTENTSCRIPT/fr_all_kaos.lst .
        while read p; do
            echo; printStatus "Downloading $p"
            rsync -avz $RSYNCDIR/rachelmods/$p $RACHELWWW/modules/
            commandStatus
            printGood "Done."
        done <fr_all_kaos.lst
        break
        ;;

        Português)
        printStatus "Installing content for Português."
        $DOWNLOADCONTENTSCRIPT/pt_all_kaos.lst .
        while read p; do
            echo; printStatus "Downloading $p"
            rsync -avz $RSYNCDIR/rachelmods/$p $RACHELWWW/modules/
            commandStatus
            printGood "Done."
        done <pt_all_kaos.lst
        break
        ;;

        Hindi)
        printStatus "Installing content for Hindi."
        $DOWNLOADCONTENTSCRIPT/hi_all.lst .
        while read p; do
            echo; printStatus "Downloading $p"
            rsync -avz $RSYNCDIR/rachelmods/$p $RACHELWWW/modules/
            commandStatus
            printGood "Done."
        done <hi_all.lst
        break
        ;;

        Main-Menu)
        break
        ;;
        esac
    done

    # Check for errors is downloads
    if [[ $ERRORCODE == 1 ]]; then
        echo; printError "One or more of the updates did not download correctly; for more information, check the log file ($RACHELLOG)."
    fi

    # Check that all files are owned by root
    echo; printStatus "Verifying proper permissions on modules."
    chown -R root:root $RACHELWWW/modules
    printGood "Done."
}

kaliteRemove(){
    # Removing old version
    echo; printStatus "Cleaning any previous KA Lite installation files."
    if [[ $KALITEVERSIONDATE == 1 ]]; then
        # Stop KA Lite
        /var/ka-lite/bin/kalite stop > /dev/null 2>&1
        # Remove old startup scripts
        rm -f /etc/rc0.d/K20kalite
        rm -f /etc/rc1.d/K20kalite
        rm -f /etc/rc2.d/K80kalite
        rm -f /etc/rc3.d/K80kalite
        rm -f /etc/rc4.d/K80kalite
        rm -f /etc/rc5.d/K80kalite
        rm -f /etc/rc6.d/K20kalite
        # Remove old folders
        rm -rf /var/ka-lite /etc/ka-lite
    elif [[ $KALITEVERSIONDATE == 2 ]]; then
        # Stop KA Lite
        sudo -H -u $KALITEUSER bash -c 'kalite stop'
        # Uninstall KA Lite
        apt-get -y remove ka-lite-bundle --purge
        # Remove old folders
        rm -rf ~/.kalite
        rm -rf /etc/ka-lite
        KALITEUSER="root"
    fi
}

kaliteInstall(){
    # Downloading KA Lite 0.15
    echo; printStatus "Downloading KA Lite Version $KALITECURRENTVERSION"
    $KALITEINSTALL
    # Checking user provided file MD5 against known good version
    checkMD5 $INSTALLTMPDIR/$KALITEINSTALLER
    if [[ $MD5STATUS == 1 ]]; then
        echo; printStatus "Installing KA Lite Version $KALITECURRENTVERSION"
        echo; printError "CAUTION:  When prompted, enter 'yes' for start on boot and change the user to 'root'."
        echo; mkdir -p /etc/ka-lite
        echo "root" > /etc/ka-lite/username
        # Turn off logging b/c KA Lite using a couple graphical screens; if on, causes issues
        exec &>/dev/tty
        dpkg -i $INSTALLTMPDIR/$KALITEINSTALLER
        commandStatus
        # Turn logging back on
        loggingStart
        if [[ $ERRORCODE == 0 ]]; then
            echo; printGood "KA Lite $KALITECURRENTVERSION installed."
        else
            echo; printError "Something went wrong, please check the log file ($RACHELLOG) and try again."
            break
        fi
        update-rc.d ka-lite disable
    fi
}

kaliteSetup(){
    echo; printStatus "Setting up KA Lite."

    # Determine version of KA Lite --> KALITEVERSIONDATE (0=No KA LITE, 1=Version prior to 0.15, 2=Version greater than 0.15)
    if [[ -f /var/ka-lite/kalite/local_settings.py ]]; then
        KALITEVERSION=$(/var/ka-lite/bin/kalite manage --version)
        echo; printError "KA Lite Version $KALITEVERSION is no longer supported and should be updated."
        KALITEVERSIONDATE=1
        printQuestion "Do you want to update to KA Lite Version $KALITECURRENTVERSION?"
        read -p "    Enter (y/N) " REPLY
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Remove previous KA Lite
            kaliteRemove
            # Install KA Lite
            kaliteInstall
        else
            printStatus "Skipping install."
        fi
    elif [[ -f /etc/ka-lite/username ]]; then
        KALITEUSER=$(cat /etc/ka-lite/username)
        KALITEVERSION=$(kalite manage --version)
        if [[ -z $KALITEVERSION ]]; then KALITEVERSION="UNKNOWN"; fi
        printGood "KA Lite installed under user:  $KALITEUSER"
        printGood "Current KA Lite Version Installed:  $KALITEVERSION"
        printGood "Lastest KA Lite Version Available:  $KALITECURRENTVERSION"
        KALITEVERSIONDATE=2
        echo; printQuestion "Do you want to upgrade or re-install KA Lite?"
        read -p "Enter (y/N) " REPLY
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Install KA Lite
            kaliteInstall
        fi
    else
        echo; printStatus "It doesn't look like KA Lite is installed; installing now."
        KALITEUSER="ka-lite"
        KALITEVERSIONDATE=0
        # Remove previous KA Lite
        kaliteRemove
        # Install KA Lite
        kaliteInstall
    fi

    # For debug purposes, print ka-lite user
    echo; printStatus "KA Lite is installed as user:  $(cat /etc/ka-lite/username)"

    # Configure ka-lite
    echo; printStatus "Configuring KA Lite content settings file:  $KALITESETTINGS"
    printStatus "KA Lite content directory being set to:  $KALITERCONTENTDIR"
    sed -i '/^CONTENT_ROOT/d' $KALITESETTINGS
    sed -i '/^DATABASES/d' $KALITESETTINGS
    echo 'CONTENT_ROOT = "/media/RACHEL/kacontent"' >> $KALITESETTINGS
#    echo "DATABASES['assessment_items']['NAME'] = os.path.join(CONTENT_ROOT, 'assessmentitems.sqlite')" >> $KALITESETTINGS

    
    # The current khan_assessment.zip installer provided by KA Lite throws on error on our system 
    echo; printStatus "Fixing the KA Lite provider khan_assessment.zip installer."
    sed -i "s/os.rename/shutil.move/g" /usr/lib/python2.7/dist-packages/kalite/contentload/management/commands/unpack_assessment_zip.py
    sed -i '6 a import shutil' /usr/lib/python2.7/dist-packages/kalite/contentload/management/commands/unpack_assessment_zip.py

    if [[ ! $(dpkg -s ka-lite-bundle) ]]; then
        # Ask if there is local copy of the assessmentitems.json
        echo; printStatus "Downloading assessment items."
        echo; printQuestion "Do you want to use a local copy of the file khan_assessment.zip?"
        read -p "    nter (y/N) " REPLY
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo; printQuestion "What is the full path to the file location for assessment items ZIP file (i.e. /root/khan_assessment.zip)?"; read ASSESSMENTFILE || return
            while :; do
                if [[ ! -f $ASSESSMENTFILE ]]; then
                    echo; printError "FILE NOT FOUND - You must provide a file path of a location accessible from the CAP."
                    echo; printQuestion "What is the full path to the file location for assessment items ZIP file?"; read ASSESSMENTFILE
                else
                    break
                fi
            done
            # Checking user provided file MD5 against known good version
            checkMD5 $ASSESSMENTFILE
            if [[ $MD5STATUS == 1 ]]; then
                echo; printGood "Installing the assessment items."
                kalite manage unpack_assessment_zip $ASSESSMENTFILE -f
            fi
        # If needed, download/install assessmentitems.json
        else
            echo; printQuestion "Do you want to attempt to download khan_assessment.zip from the RACHEL repository online (caution...the file is nearly 500MB)?"
            read -p "    Enter (y/N) " REPLY
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                # Primary download server
                wget -c https://learningequality.org/downloads/ka-lite/0.15/content/khan_assessment.zip -O $INSTALLTMPDIR/khan_assessment.zip
                commandStatus
                    if [[ $ERRORCODE == 1 ]]; then
                    # Secondary download server
                    rsync -avhP $CONTENTONLINE/khan_assessment.zip $INSTALLTMPDIR/khan_assessment.zip
                fi
                # Checking user provided file MD5 against known good version
                checkMD5 $INSTALLTMPDIR/khan_assessment.zip
                if [[ $MD5STATUS == 1 ]]; then
                    echo; printGood "Installing the assessment items."
                    kalite manage unpack_assessment_zip $ASSESSMENTFILE -f
                fi
                # Installing khan_assessment.zip
                echo; printStatus "Installing khan_assessment.zip (the install may take a minute or two)."
                kalite manage unpack_assessment_zip $INSTALLTMPDIR/khan_assessment.zip -f
            else
                echo; printStatus "Skipping assessment items download."
            fi
        fi
    fi

    # Install module for RACHEL index.php
    echo; printStatus "Syncing RACHEL web interface 'KA Lite module'."
    rsync -avz --ignore-existing $RSYNCDIR/rachelmods/ka-lite $RACHELWWW/modules/

    # Delete previous setup commands from /etc/rc.local (not used anymore)
    sudo sed -i '/ka-lite/d' /etc/rc.local
    sudo sed -i '/sleep 20/d' /etc/rc.local

    # Delete previous setup commands from the $RACHELSCRIPTSFILE
#    echo; printStatus "Setting up KA Lite to start at boot..."
    sudo sed -i '/ka-lite/d' $RACHELSCRIPTSFILE
    sudo sed -i '/kalite/d' $RACHELSCRIPTSFILE
    sudo sed -i '/sleep/d' $RACHELSCRIPTSFILE

    # Start KA Lite at boot time
    sudo sed -i '$e echo "# Start kalite at boot time"' $RACHELSCRIPTSFILE
    sudo sed -i '$e echo "sleep 5 #kalite"' $RACHELSCRIPTSFILE
    sudo sed -i '$e echo "sudo /usr/bin/kalite start"' $RACHELSCRIPTSFILE
    printGood "Done."
}

downloadKAContent(){
    ERRORCODE=0
    # Setup KA Lite content
    echo; printStatus "KA Lite Content Installer"
    echo; printQuestion "Do you want to install KA Lite video content located on a local USB or folder?"
    read -p "    Enter (y/N) " REPLY
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        while :; do
            echo; printQuestion "What is the full path to the file location for KA Lite content (i.e. /path/to/your-usb-drive-or-folder)?"; read KACONTENTFOLDER || return
            if [[ ! -d $KACONTENTFOLDER ]]; then
                echo; printError "FOLDER NOT FOUND - You must provide a full path to a location accessible from the CAP."
            else
                break
            fi
        done
        echo; printStatus "Copying KA Lite content files from $KACONTENTFOLDER to $KALITERCONTENTDIR"
        rsync -avhP $KACONTENTFOLDER/ $KALITERCONTENTDIR/
    elif [[ $INTERNET == 1 ]]; then
        echo; printQuestion "Do you want to download or check for updates to your KA Lite video content?"
        read -p "    Enter (y/N) " REPLY
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mkdir -p KALITERCONTENTDIR
            echo; printStatus "Downloading from primary repository."
            echo "WEBSITE:  $CONTENTONLINE/kacontent"
            $KALITECONTENTINSTALL
            commandStatus
            if [[ $ERRORCODE == 1 ]]; then
                echo; printError "Primary repo unavailable, do you want to download the entire zip from the backup repo?"
                read -p "    Enter (y/N) " REPLY
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    echo; printStatus "Attempting to download from the backup repository."
                    echo "WEBSITE:  $WGETONLINE/downloads/public_ftp/z-holding/ka-lite_content.zip"
                    wget -c $WGETONLINE/downloads/public_ftp/z-holding/ka-lite_content.zip -O $RACHELTMPDIR/ka-lite_content.zip
                    # Checking user provided file MD5 against known good version
                    checkMD5 $RACHELTMPDIR/ka-lite_content.zip
                    if [[ $MD5STATUS == 1 ]]; then
                        echo; printGood "Installing the KA Lite Content."
                    fi
                    unzip -o $RACHELTMPDIR/ka-lite_content.zip "kacontent/*" -d "$KALITERCONTENTDIR/"
                    commandStatus
                    if [[ $ERRORCODE == 1 ]]; then printError "Something went wrong; check $RACHELLOG for errors."; fi
                fi
            fi
        else
            echo; printStatus "Skipping content download/check."
        fi
    fi
}

checkCaptivePortal(){
    ERRORCODE=0

    # Download RACHEL Captive Portal files
    echo; printStatus "Checking Captive Portal files."

    if [[ ! -f $RACHELWWW/captiveportal-redirect.php ]]; then
        echo; printStatus "Downloading captiveportal-redirect.php."
        cd $RACHELWWW
        $CAPTIVEPORTALREDIRECT
        commandStatus
    fi

    if [[ ! -f $RACHELWWW/pass_ticket.shtml ]]; then
        echo; printStatus "Downloading pass_ticket.shtml."
        cd $RACHELWWW
        $PASSTICKETSHTML
        chmod +x $RACHELWWW/pass_ticket.shtml
        commandStatus
    fi

    if [[ ! -f $RACHELWWW/redirect.shtml ]]; then
        echo; printStatus "Downloading redirect.shtml."
        cd $RACHELWWW
        $REDIRECTSHTML
        chmod +x $RACHELWWW/redirect.shtml
        commandStatus
    fi

    if [[ ! -f $RACHELWWW/art/RACHELbrandLogo-captive.png ]]; then
        cd $RACHELWWW/art
        echo; printStatus "Downloading RACHELbrandLogo-captive.png."
        $RACHELBRANDLOGOCAPTIVE
        commandStatus
    fi

    if [[ ! -f $RACHELWWW/art/HFCbrandLogo-captive.jpg ]]; then
        cd $RACHELWWW/art
        echo; printStatus "Downloading HFCbrandLogo-captive.jpg."
        $HFCBRANDLOGOCAPTIVE
        commandStatus
    fi

    if [[ ! -f $RACHELWWW/art/WorldPossiblebrandLogo-captive.png ]]; then
        cd $RACHELWWW/art
        echo; printStatus "Downloading WorldPossiblebrandLogo-captive.png."
        $WORLDPOSSIBLEBRANDLOGOCAPTIVE
        commandStatus
    fi

    if [[ $ERRORCODE == 1 ]]; then 
        printError "Something may have gone wrong; check $RACHELLOG for errors."
    else 
        printGood "Done."
    fi
}

repairRachelScripts(){
    # Fixing /root/rachel-scripts.sh
    echo; printStatus "Updating $RACHELSCRIPTSFILE"

    # Add rachel-scripts.sh script
    sed "s,%RACHELSCRIPTSLOG%,$RACHELSCRIPTSLOG,g" > $RACHELSCRIPTSFILE << 'EOF'
#!/bin/bash
# Send output to log file
rm -f %RACHELSCRIPTSLOG%
exec 1>> %RACHELSCRIPTSLOG% 2>&1
echo $(date) - Starting RACHEL script
exit 0
EOF

    # Add rachel-scripts.sh startup in /etc/rc.local
    sed -i '/RACHEL/d' /etc/rc.local
    sed -i '/rachel/d' /etc/rc.local
    sudo sed -i '$e echo "# Add rachel startup scripts"' /etc/rc.local
    sudo sed -i '$e echo "bash /root/rachel-scripts.sh&"' /etc/rc.local

    # Check/re-add Kiwix
    if [[ -d /var/kiwix ]]; then
        echo; printStatus "Setting up Kiwix to start at boot..."
        # Remove old kiwix boot lines from /etc/rc.local
        sed -i '/kiwix/d' /etc/rc.local
        # Clean up current rachel-scripts.sh file
        sed -i '/kiwix/d' $RACHELSCRIPTSFILE
        # Add lines to /etc/rc.local that will start kiwix on boot
        sed -i '$e echo "\# Start kiwix on boot"' $RACHELSCRIPTSFILE
        sed -i '$e echo "echo \\$(date) - Starting kiwix"' $RACHELSCRIPTSFILE
        sed -i '$e echo "\/var\/kiwix\/bin\/kiwix-serve --daemon --port=81 --library \/media\/RACHEL\/kiwix\/data\/library\/library.xml"' $RACHELSCRIPTSFILE
        printGood "Done."
    fi

    if [[ -d $KALITEDIR ]]; then
        # Delete previous setup commands from /etc/rc.local (not used anymore)
        sudo sed -i '/ka-lite/d' /etc/rc.local
        sudo sed -i '/sleep/d' /etc/rc.local
        # Delete previous setup commands from the $RACHELSCRIPTSFILE
        sudo sed -i '/ka-lite/d' $RACHELSCRIPTSFILE
        sudo sed -i '/kalite/d' $RACHELSCRIPTSFILE
        sudo sed -i '/sleep/d' $RACHELSCRIPTSFILE
        echo; printStatus "Setting up KA Lite to start at boot..."
        # Start KA Lite at boot time
        sudo sed -i '$e echo "# Start kalite at boot time"' $RACHELSCRIPTSFILE
        sed -i '$e echo "echo \\$(date) - Starting kalite"' $RACHELSCRIPTSFILE
        sudo sed -i '$e echo "sleep 5 #kalite"' $RACHELSCRIPTSFILE
        sudo sed -i '$e echo "sudo /usr/bin/kalite start"' $RACHELSCRIPTSFILE
        printGood "Done."
    fi

    # Add Weaved restore back into rachel-scripts.sh
    # Clean rachel-scripts.sh
    sed -i '/Weaved/d' $RACHELSCRIPTSFILE
    # Write restore commands to rachel-scripts.sh
    sudo sed -i '5 a # Restore Weaved configs, if needed' $RACHELSCRIPTSFILE
    sudo sed -i '6 a echo \$(date) - Checking Weaved install' $RACHELSCRIPTSFILE
    sudo sed -i '7 a if [[ -d '$RACHELRECOVERYDIR'/Weaved ]] && [[ `ls /usr/bin/Weaved*.sh 2>/dev/null | wc -l` == 0 ]]; then' $RACHELSCRIPTSFILE
    sudo sed -i '8 a echo \$(date) - Weaved backup files found but not installed, recovering now' $RACHELSCRIPTSFILE
    sudo sed -i '9 a mkdir -p /etc/weaved/services #Weaved' $RACHELSCRIPTSFILE
    sudo sed -i '10 a cp '$RACHELRECOVERYDIR'/Weaved/Weaved*.conf /etc/weaved/services/' $RACHELSCRIPTSFILE
    sudo sed -i '11 a cp '$RACHELRECOVERYDIR'/Weaved/*.sh /usr/bin/' $RACHELSCRIPTSFILE
    sudo sed -i '12 a reboot #Weaved' $RACHELSCRIPTSFILE
    sudo sed -i '13 a fi #Weaved' $RACHELSCRIPTSFILE

    # Add battery monitoring start line 
    if [[ -f /root/batteryWatcher.sh ]]; then
        # Clean rachel-scripts.sh
        sed -i '/battery/d' $RACHELSCRIPTSFILE
        sed -i '$e echo "# Start battery monitoring"' $RACHELSCRIPTSFILE
        sed -i '$e echo "echo \\$(date) - Starting battery monitor"' $RACHELSCRIPTSFILE
        sed -i '$e echo "bash /root/batteryWatcher.sh&"' $RACHELSCRIPTSFILE
    fi

    # Check for disable reset button flag
    echo; printStatus "Added check to disable the reset button"
    sed -i '$e echo "\# Check if we should disable reset button"' $RACHELSCRIPTSFILE
    sed -i '$e echo "echo \\$(date) - Checking if we should disable reset button"' $RACHELSCRIPTSFILE
    sed -i '$e echo "if [[ -f /root/disable_reset ]]; then killall reset_button; echo \\"Reset button disabled\\"; fi"' $RACHELSCRIPTSFILE
    printGood "Done."        

    # Add RACHEL script complete line
    sed -i '$e echo "echo \\$(date) - RACHEL startup completed"' $RACHELSCRIPTSFILE
    echo; printGood "Rachel script update completed."
}

repairFirmware(){
    printHeader
    echo; printStatus "Repairing your CAP after a firmware upgrade."
    cd $INSTALLTMPDIR

    # Download/update to latest RACHEL lighttpd.conf
    echo; printStatus "Downloading latest lighttpd.conf"
    ## lighttpd.conf - RACHEL version (I don't overwrite at this time due to other dependencies and ensuring the file downloads correctly)
    $LIGHTTPDFILE
    commandStatus
    if [[ $ERRORCODE == 1 ]]; then
        printError "The lighttpd.conf file did not download correctly; check log file (/var/log/RACHEL/rachel-install.tmp) and try again."
        echo; break
    else
        mv $INSTALLTMPDIR/lighttpd.conf /usr/local/etc/lighttpd.conf
    fi
    printGood "Done."

    # Reapply /etc/fstab entry for /media/RACHEL
    echo; printStatus "Adding /dev/sda3 into /etc/fstab"
    sed -i '/\/dev\/sda3/d' /etc/fstab
    echo -e "/dev/sda3\t/media/RACHEL\t\text4\tauto,nobootwait 0\t0" >> /etc/fstab
    printGood "Done."

    # Fixing /root/rachel-scripts.sh
    repairRachelScripts

    # Check captive portal files
    checkCaptivePortal

    # Remove outdated startup script
    rm -f /root/iptables-rachel.sh

    # Delete previous setwanip commands from /etc/rc.local - not used anymore
    echo; printStatus "Deleting previous setwanip.sh script from /etc/rc.local"
    sed -i '/setwanip/d' /etc/rc.local
    rm -f /root/setwanip.sh
    printGood "Done."

    # Delete previous iptables commands from /etc/rc.local
    echo; printStatus "Deleting previous iptables script from /etc/rc.local"
    sed -i '/iptables/d' /etc/rc.local
    printGood "Done."

    echo; printGood "RACHEL CAP Repair Complete."
    sudo mv $RACHELLOG $RACHELLOGDIR/rachel-repair-$TIMESTAMP.log
    echo; printGood "Log file saved to: $RACHELLOGDIR/rachel-repair-$TIMESTAMP.log"
    cleanup
    rebootCAP
}

repairKalite(){
    echo; printStatus "Fixing KA-Lite"
    # Fixing KA-Lite 
    cp -f /media/RACHEL/kacontent/assessmentitems.sqlite /usr/share/kalite/assessment/khan/.
    sed -i '/assessmentitems.sqlite/d' /root/.kalite/settings.py
    # Turn loggin off for compatibility
    exec &>/dev/tty
    # Restart kalite to use the new assessmentitems.sqlite location
    echo; kalite stop
    echo; kalite manage setup
    # Show diagnostic info
    echo; kalite diagnose
    # Turn logging back on
    loggingStart
    echo; printGood "Done."
}

repairBugs(){
    # Update to the latest contentshell
    checkContentShell

    # Add battery monitor
    installBatteryWatch

    # Fixing issue with 10.10.10.10 redirect and sleep times
    repairRachelScripts

    # Add local content module
    echo; printStatus "Adding the local content module."
    rsync -avz $RSYNCDIR/rachelmods/local_content $RACHELWWW/modules/
    printGood "Done."

    # Fix GCF links
    if [[ -d $RACHELWWW/modules/GCF2015 ]]; then
        echo; printStatus "Fixing GCF index.htmlf links"
        sed -i 's/digital_lifestyle.html/digitalskills.html/g' /media/RACHEL/rachel/modules/GCF2015/index.htmlf
        sed -i 's/job.html/jobsearch.html/g' /media/RACHEL/rachel/modules/GCF2015/index.htmlf
        printGood "Done."
    fi
}

installBatteryWatch(){
    echo; printStatus "Creating /root/batteryWatcher.sh"
    echo "This script will monitor the battery charge level and shutdown this device with less than 3% battery charge."
    # Create batteryWatcher script
    cat > /root/batteryWatcher.sh << 'EOF'
#!/bin/bash
while :; do
    if [[ $(cat /tmp/chargeStatus) -lt -200 ]]; then
        if [[ $(cat /tmp/batteryLastChargeLevel) -lt 3 ]]; then
            echo "$(date) - Low battery shutdown" >> /var/log/RACHEL/shutdown.log
            kalite stop
            shutdown -h now
            exit 0
        fi
    fi
    sleep 10
done
EOF
    chmod +x /root/batteryWatcher.sh
    # Check and kill other scripts running
    printStatus "Checking for and killing previously run battery monitoring scripts"
    pid=$(ps aux | grep -v grep | grep "/bin/bash /root/batteryWatcher.sh" | awk '{print $2}')
    if [[ ! -z $pid ]]; then kill $pid; fi
    # Start script
    /root/batteryWatcher.sh&
    printStatus "Logging shutdowns to /var/log/RACHEL/shutdown.log"
    printGood "Script started...monitoring battery."
}

disableResetButton(){
    echo; printStatus "Disabling the reset button"
    pid=$(ps aux | grep -v grep | grep "reset_button" | awk '{print $2}')
    if [[ ! -z $pid ]]; then 
        kill $pid
        echo; printGood "Reset button disabled; do not delete the file /root/disable_reset unless"
        echo "    you want to re-enable the reset button."
    else 
        echo; printGood "Reset button already disabled."
    fi
    echo "Reset button disabled.  Delete this file to re-enable." > /root/disable_reset
}

# Loop to redisplay main menu
whatToDo(){
    echo; printQuestion "What would you like to do next?"
    echo "1)Initial Install  2)Install KA Lite  3)Install Kiwix  4)Install Default Weaved Services  5)Install Weaved Service  6)Add/Update Module  7)Add/Update Module List  8)Utilities  9)Exit"
}

# Interactive mode menu
interactiveMode(){
    echo; printQuestion "What you would like to do:"
    echo "  - [Initial-Install] of RACHEL on a CAP (completely erases any content)"
    echo "  - [Install-KA-Lite]"
    echo "  - [Install-Kiwix]"
    echo "  - [Install-Default-Weaved-Services] installs the default CAP Weaved services for ports 22, 80, 8080"
    echo "  - [Install-Weaved-Service] adds a Weaved service to an online account you provide during install"
    echo "  - [Add-Update-Module] lists current available modules; installs one at a time"
    echo "  - [Add-Update-Module-List] installs modules from a pre-configured list of modules"
    echo "  - [Download-KA-Content] checks for updated KA Lite video content"
    echo "  - Other [Utilities]"
    echo "    - Install a battery monitor that cleanly shuts down this device with less than 3% battery"
    echo "    - Download RACHEL content to stage for OFFLINE installs"
    echo "    - Backup or Uninstall Weaved services"
    echo "    - Repair an install of a CAP after a firmware upgrade"
    echo "    - Repair a KA Lite assessment file location"
    echo "    - Repairs of general bug fixes"
    echo "    - Sanitize CAP (used for creating the RACHEL USB Multitool)"
    echo "    - Symlink all .mp4 videos in the module kaos-en to /media/RACHEL/kacontent"
    echo "    - Check your local file's MD5 against our database"
    echo "    - Testing script"
    echo "  - [Exit] the installation script"
    echo
    select menu in "Initial-Install" "Install-KA-Lite" "Install-Kiwix" "Install-Default-Weaved-Services" "Install-Weaved-Service" "Add-Update-Module" "Add-Update-Module-List" "Download-KA-Content" "Utilities" "Exit"; do
            case $menu in
            Initial-Install)
            newInstall
            ;;

            Install-KA-Lite)
            kaliteSetup
            downloadKAContent
            # Re-scanning content folder and exercise data 
            echo; printStatus "Restarting KA Lite in order to re-scan the content folder."
            kalite restart
            echo; printGood "Login using wifi at http://192.168.88.1:8008 and register device."
            echo "After you register, click the new tab called 'Manage', then 'Videos' and download all the missing videos."
            repairRachelScripts
            printGood "KA Lite Install Complete."
            whatToDo
            ;;

            Install-Kiwix)
            kiwix
            repairRachelScripts
            whatToDo
            ;;

            Install-Default-Weaved-Services)
            uninstallAllWeavedServices
            installDefaultWeavedServices
            backupWeavedService
            whatToDo
            ;;

            Install-Weaved-Service)
            installWeavedService
            backupWeavedService
            whatToDo
            ;;

            Add-Update-Module)
            contentModuleInstall
            whatToDo
            ;;

            Add-Update-Module-List)
            contentListInstall
            whatToDo
            ;;

            Download-KA-Content)
            downloadKAContent
            whatToDo
            ;;

            Utilities)
            echo; printQuestion "What utility would you like to use?"
            echo "  - [Install-Battery-Watcher] monitors battery and shutdowns the device with less than 3% battery"
            echo "  - [Disable-Reset-Button] removes the ability to reset the device by use of the reset button"
            echo "  - **BETA** [Download-OFFLINE-Content] to stage for OFFLINE (i.e. local) RACHEL installs"
            echo "  - [Backup-Weaved-Services] backs up configs and restores them if they are not found on boot"
            echo "  - [Uninstall-Weaved-Service] removes Weaved services, one at a time"
            echo "  - [Uninstall-ALL-Weaved-Services] removes ALL Weaved services"
            echo "  - [Update-Content-Shell] updates the RACHEL contentshell from GitHub"
            echo "  - [Repair-Firmware] repairs an install of a CAP after a firmware upgrade"
            echo "  - [Repair-KA-Lite] repairs KA Lite's mislocation of the assessment file; runs 'kalite manage setup' as well"
            echo "  - [Repair-Bugs] provides general bug fixes (run when requested)"
            echo "  - [Sanitize] and prepare CAP for delivery to customer"
            echo "  - [Build-USB-Image] is used for creating eMMC images used on the RACHEL USB Multitool"
            echo "  - [Symlink] all .mp4 videos in the module kaos-en to /media/RACHEL/kacontent"
            echo "  - [Check-MD5] will check a file you provide against our hash database"
            echo "  - [Testing] script"
            echo "  - Return to [Main Menu]"
            echo
            select util in "Install-Battery-Watcher" "Disable-Reset-Button" "Download-OFFLINE-Content" "Backup-Weaved-Services" "Uninstall-Weaved-Service" "Uninstall-ALL-Weaved-Services" "Update-Content-Shell" "Repair-Firmware" "Repair-KA-Lite" "Repair-Bugs" "Sanitize" "Build-USB-Image" "Symlink" "Check-MD5" "Test" "Main-Menu"; do
                case $util in
                    Install-Battery-Watcher)
                    installBatteryWatch
                    repairRachelScripts
                    break
                    ;;

                    Disable-Reset-Button)
                    disableResetButton
                    repairRachelScripts
                    break
                    ;;

                    Download-OFFLINE-Content)
                    downloadOfflineContent
                    break
                    ;;

                    Backup-Weaved-Services)
                    backupWeavedService
                    break
                    ;;

                    Uninstall-Weaved-Service)
                    uninstallWeavedService
                    break
                    ;;

                    Uninstall-ALL-Weaved-Services)
                    echo; printError "This uninstaller will completely remove Weaved from your CAP."
                    echo; printQuestion "Do you still wish to continue?"
                    read -p "    Enter (y/N) " REPLY
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        uninstallAllWeavedServices
                        backupWeavedService
                    else
                        printError "Uninstall cancelled."
                    fi
                    break
                    ;;

                    Update-Content-Shell)
                    echo; printStatus "Updating the RACHEL content shell."
                    apt-get update; apt-get -y install php5-sqlite
                    checkContentShell
                    break
                    ;;

                    Repair-Firmware)
                    repairFirmware
                    break
                    ;;

                    Repair-KA-Lite)
                    repairKalite
                    break
                    ;;

                    Repair-Bugs)
                    repairBugs
                    break
                    ;;

                    Sanitize)
                    sanitize
                    break
                    ;;

                    Build-USB-Image)
                    buildUSBImage
                    break
                    ;;

                    Symlink)
                    symlink
                    break
                    ;;

                    Check-MD5)
                    echo; printStatus "This function will compare the MD5 of the file you provide against our list of known hashes."
                    printQuestion "What is the full path to the file you want to check?"; read MD5CHKFILE
                    checkMD5 $MD5CHKFILE
                    break
                    ;;

                    Test)
                    testingScript
                    break
                    ;;

                    Main-Menu )
                    break
                    ;;
                esac
            done
            whatToDo
            ;;

            Exit)
            echo; printStatus "User requested to exit."
            break
            ;;
            esac
    done
}

printHelp(){
    echo "Usage:  cap-rachel-configure.sh [-h] [-i] [-r] [-u]"
    echo; echo "Examples:"
    echo "./cap-rachel-configure.sh -h"
    echo "Displays this help menu."
    echo; echo "./cap-rachel-configure.sh -i"
    echo "Interactive mode."
    echo; echo "./cap-rachel-configure.sh -r"
    echo "Repair issues found in the RACHEL-Plus."
    echo; echo "./cap-rachel-configure.sh -u"
    echo "Update this script with the latest RELEASE version from GitHub."
    echo; stty sane
}

#### MAIN MENU ####

# Logging
loggingStart

# Display current script version
echo; echo "RACHEL CAP Configuration Script - Version $VERSION"
printGood "Started:  $(date)"
printGood "Log directory:  $RACHELLOGDIR"
printGood "Temporary file directory:  $INSTALLTMPDIR"

if [[ $1 == "" || $1 == "--help" || $1 == "-h" ]]; then
    printHelp
else
    IAM=${0##*/} # Short basename
    while getopts ":irtu" opt
    do sc=0 #no option or 1 option arguments
        case $opt in
        (i) # Interactive mode
            # Create temp directories
            mkdir -p $INSTALLTMPDIR $RACHELTMPDIR $RACHELRECOVERYDIR
            # Check OS version
            osCheck
            # Determine the operational mode - ONLINE or OFFLINE
            opMode
            # Build the hash list 
            buildHashList
            # Change directory into $INSTALLTMPDIR
            cd $INSTALLTMPDIR
            interactiveMode
            cleanup
            ;;
        (r) # REPAIR - quick repair; doesn't hurt if run multiple times.
            if [[ $INTERNET == "1" ]]; then
                # Create temp directories
                mkdir -p $INSTALLTMPDIR
                # Determine the operational mode - ONLINE or OFFLINE
                opMode
                # Check OS version
                osCheck
                repairBugs
                echo; printGood "Repair complete."
            else
                echo; printError "You need to be connected to the internet to repair this script."
            fi
            cleanup
            exit 1
            ;;
        (t) # Testing script
            # Check OS version
            osCheck
            # Determine the operational mode - ONLINE or OFFLINE
            opMode
            testingScript
            ;;
        (u) # UPDATE - Update setips.sh to the latest release build.
            # Create temp directories
            mkdir -p $INSTALLTMPDIR $RACHELTMPDIR $RACHELRECOVERYDIR
            # Check OS version
            osCheck
            # Determine the operational mode - ONLINE or OFFLINE
            opMode
            if [[ $INTERNET == "1" ]]; then
                scriptDownloadLink="wget https://raw.githubusercontent.com/rachelproject/rachelplus/master/cap-rachel-configure.sh -O $INSTALLTMPDIR/cap-rachel-configure.sh"
                $scriptDownloadLink >&2
                commandStatus
                if [[ -s $INSTALLTMPDIR/cap-rachel-configure.sh ]]; then
                    mv $INSTALLTMPDIR/cap-rachel-configure.sh /root/cap-rachel-configure.sh
                    chmod +x /root/cap-rachel-configure.sh
                    versionNum=$(cat /root/cap-rachel-configure.sh |grep version|head -n 1|cut -d"=" -f2|cut -d" " -f1)
                    printGood "Success! Your script was updated to v$versionNum; RE-RUN the script to use the new version."
                else
                    printStatus "Fail! Check the log file for more info on what happened:  $RACHELLOG"
                    echo
                fi
            else
                echo; printError "You need to be connected to the internet to update this script."
            fi
            cleanup
            exit 1
            ;;
        (\?) #Invalid options
            echo "$IAM: Invalid option: -$OPTARG"
            printHelp
            exit 1
            ;;
        (:) #Missing arguments
            echo "$IAM: Option -$OPTARG argument(s) missing."
            printHelp
            exit 1
            ;;
        esac
        if [[ $OPTIND != 1 ]]; then #This test fails only if multiple options are stacked after a single "-"
            shift $((OPTIND - 1 + sc))
            OPTIND=1
        fi
    done
fi
