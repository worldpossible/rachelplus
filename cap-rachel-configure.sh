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
VERSION=BETA # To get current version - date +%m%d%y%H%M
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
build_hash_list () {
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

printGood () {
    echo -e "\x1B[01;32m[+]\x1B[0m $1"
}

printError () {
    echo -e "\x1B[01;31m[-]\x1B[0m $1"
}

printStatus () {
    echo -e "\x1B[01;35m[*]\x1B[0m $1"
}

printQuestion () {
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
logging_start () {
    exec &> >(tee "$RACHELLOG")
}

# Capture a users Ctrl-C
ctrlC(){
    stty sane
    echo; printError "Cancelled by user."
    echo; exit $?
}

testing-script () {
    set -x
    trap ctrlC INT

    set +x
    exit 1
}

opmode () {
    trap ctrlC INT
    echo; printQuestion "Do you want to run in ONLINE or OFFLINE mode?"
    select MODE in "ONLINE" "OFFLINE"; do
        case $MODE in
        # ONLINE
        ONLINE)
            echo; printGood "Script set for 'ONLINE' mode."
            INTERNET="1"
            online_variables
            check_internet
            break
        ;;
        # OFFLINE
        OFFLINE)
            echo; printGood "Script set for 'OFFLINE' mode."
            INTERNET="0"
            offline_variables
            echo; printQuestion "The OFFLINE RACHEL content folder is set to:  $DIRCONTENTOFFLINE"
            read -p "Do you want to change the default location? (y/n) " -r
            if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
                echo; printQuestion "What is the location of your content folder? "; read DIRCONTENTOFFLINE
            fi
            if [[ ! -d $DIRCONTENTOFFLINE ]]; then
                printError "The folder location does not exist!  Please identify the full path to your OFFLINE content folder and try again."
                rm -rf $INSTALLTMPDIR $RACHELTMPDIR
                exit 1
            else
                export DIRCONTENTOFFLINE
                offline_variables
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

online_variables () {
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
    RACHELBRANDLOGOCAPTIVE="wget -r $GITRACHELPLUS/captive-portal/RACHELbrandLogo-captive.png -O RACHELbrandLogo-captive.png"
    HFCBRANDLOGOCAPTIVE="wget -r $GITRACHELPLUS/captive-portal/HFCbrandLogo-captive.jpg -O HFCbrandLogo-captive.jpg"
    WORLDPOSSIBLEBRANDLOGOCAPTIVE="wget -r $GITRACHELPLUS/captive-portal/WorldPossiblebrandLogo-captive.png -O WorldPossiblebrandLogo-captive.png"
    GITCLONERACHELCONTENTSHELL="git clone https://github.com/rachelproject/contentshell contentshell"
    RSYNCDIR="$RSYNCONLINE"
    ASSESSMENTITEMSJSON="wget -c $GITRACHELPLUS/assessmentitems.json -O /var/ka-lite/data/khan/assessmentitems.json"
    KALITEINSTALL="rsync -avhz --progress $CONTENTONLINE/$KALITEINSTALLER $INSTALLTMPDIR/$KALITEINSTALLER"
    KALITECONTENTINSTALL="rsync -avhz --progress $CONTENTONLINE/kacontent/ /media/RACHEL/kacontent/"
    KIWIXINSTALL="wget -c $WGETONLINE/z-holding/kiwix-0.9-linux-i686.tar.bz2 -O $RACHELTMPDIR/kiwix-0.9-linux-i686.tar.bz2"
    KIWIXSAMPLEDATA="wget -c $WGETONLINE/z-holding/Ray_Charles.tar.bz -O $RACHELTMPDIR/Ray_Charles.tar.bz"
    WEAVEDZIP="wget -r http://rachelfriends.org/z-holding/weaved_software.zip -O /root/weaved_software.zip"
    SPHIDERPLUSSQLINSTALL="wget -c $WGETONLINE/z-SQLdatabase/sphider_plus.sql -O $RACHELTMPDIR/sphider_plus.sql"
    DOWNLOADCONTENTSCRIPT="wget -c $GITRACHELPLUS/scripts"
    CONTENTWIKI="wget -c http://download.kiwix.org/portable/wikipedia/$FILENAME -O $RACHELTMPDIR/$FILENAME"
}

offline_variables () {
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
    WEAVEDZIP=""
    SPHIDERPLUSSQLINSTALL=""
    DOWNLOADCONTENTSCRIPT="rsync -avhz --progress $DIRCONTENTOFFLINE/rachelplus/scripts"
    CONTENTWIKIALL=""
}

print_header () {
    # Add header/date/time to install log file
    echo; printGood "RACHEL CAP Configuration Script - Version $VERSION"
    printGood "Script started: $(date)"
}

check_internet () {
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
                offline_variables
                INTERNET=0
            fi
        fi
    fi
}

ctrlC () {
#    kill $!; trap 'kill $1' SIGTERM
    echo; printError "Cancelled by user."
    cleanup
    stty sane
    echo; exit $?
}

command_status () {
    export EXITCODE="$?"
    if [[ $EXITCODE != 0 ]]; then
        printError "Command failed.  Exit code: $EXITCODE"
        export ERRORCODE="1"
    else
        printGood "Command successful."
    fi
}

check_sha1 () {
    CALCULATEDHASH=$(openssl sha1 $1)
    KNOWNHASH=$(cat $INSTALLTMPDIR/rachelplus/hashes.txt | grep $1 | cut -f1 -d" ")
    if [[ "SHA1(${1})= $2" == "${CALCULATEDHASH}" ]]; then printGood "Good hash!" && export GOODHASH=1; else printError "Bad hash!"  && export GOODHASH=0; fi
}

check_md5 () {
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

reboot-CAP () {
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

cleanup () {
    # No log as it won't clean up the tmp file
    echo; printQuestion "Were there errors?"
    read -p "Enter 'y' to exit without cleaning up temporary folders/files. (y/N) " REPLY
    if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
        exit 1
    fi
    # Deleting the install script commands
    echo; printStatus "Cleaning up install scripts."
    rm -rf $0 $INSTALLTMPDIR $RACHELTMPDIR&
    printGood "Done."
}

sanitize () {
    # Remove history, clean logs
    echo; printStatus "Sanitizing log files."
    # Clean log files
    rm -rf /var/log/rachel-install* /var/log/RACHEL/*
    # Clean previous cached logins from ssh
    rm -f /root/.ssh/known_hosts
    # Clean off ka-lite_content.zip (if exists)
    rm -f /media/RACHEL/ka-lite_content.zip
    # Clean previous files from running the generate_recovery.sh script 
    rm -rf /recovery/201* $RACHELRECOVERYDIR/201*
    # Clean bash history
    echo "" > /root/.bash_history
    # Clean Weaved services
    rm -rf /usr/bin/notify_Weaved*.sh /usr/bin/Weaved*.sh /etc/weaved/services/Weaved*.conf /root/Weaved*.log
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
        rm -rf $0 $INSTALLTMPDIR $RACHELTMPDIR
        /root/generate_recovery.sh /media/RACHEL/recovery/
    fi
    echo; printGood "Done."
}

symlink () {
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

kiwix () {
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

sphider_plus.sql () {
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

install_weaved_service () {
    if [[ $INTERNET == "0" ]]; then
        echo; printError "The CAP must be online to install/remove Weaved services."
    else
        echo; printStatus "Installing Weaved service."
        cd /root
        # Download weaved files
        echo; printStatus "Downloading required files."
        $WEAVEDZIP
        command_status
        unzip -u weaved_software.zip
        command_status
        if [[ $ERRORCODE == 0 ]] && [[ -d weaved_software ]]; then
            rm -f /root/weaved_software.zip
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

uninstall_weaved_service () {
    if [[ $INTERNET == "0" ]]; then
        echo; printError "The CAP must be online to install/remove Weaved services."
    else
        weaved_uninstaller () {
            bash /root/weaved_software/uninstaller.sh
            echo; printGood "Weaved service uninstall complete."
        }
        echo; printStatus "Uninstalling Weaved service."
        cd /root
        # Run uninstaller
        if [[ -f /root/weaved_software/uninstaller.sh ]]; then 
            weaved_uninstaller
        else
            printError "The Weaved uninstaller does not exist. Attempting to download..."
            if [[ $INTERNET == "1" ]]; then
                $WEAVEDZIP
                command_status
                unzip -u weaved_software.zip
                if [[ $ERRORCODE == 0 ]] && [[ -d /root/weaved_software ]]; then
                    rm -f /root/weaved_software.zip
                    weaved_uninstaller
                else
                    printError "Download failed; check log file ($RACHELLOG) and try again."
                fi
            else
                printError "No internet connection.  Connect the CAP to the internet and try the uninstaller again."
            fi
        fi
    fi
}

backup_weaved_service () {
    # Clear current configs
    if [[ `find /etc/weaved/services/ -name Weaved*.conf 2>/dev/null | wc -l` -ge 1 ]]; then
        echo; printStatus "Backing up configuration files to $RACHELRECOVERYDIR/weaved"
        rm -rf $RACHELRECOVERYDIR/Weaved
        mkdir -p $RACHELRECOVERYDIR/Weaved
        # Backup Weaved configs
        cp -f /etc/weaved/services/Weaved*.conf /usr/bin/Weaved*.sh /usr/bin/notify_Weaved*.sh $RACHELRECOVERYDIR/Weaved/
        printGood "Your current configuration is backed up and will be restored if you have to run the USB Recovery."
    elif [[ ! -d /etc/weaved ]]; then
        # Weaved is no longer installed, remove all backups
        rm -rf $RACHELRECOVERYDIR/Weaved
    else
        echo; printError "You do not have any Weaved configuration files to backup."
    fi
    # Clean rachel-scripts.sh
    sed -i '/Weaved/d' $RACHELSCRIPTSFILE
    # Write restore commands to rachel-scripts.sh
    sudo sed -i '4 a # Restore Weaved configs, if needed' $RACHELSCRIPTSFILE
    sudo sed -i '5 a if [[ -d '$RACHELRECOVERYDIR'/Weaved ]] && [[ `ls /usr/bin/Weaved*.sh 2>/dev/null | wc -l` == 0 ]]; then' $RACHELSCRIPTSFILE
    sudo sed -i '6 a mkdir -p /etc/weaved/services #Weaved' $RACHELSCRIPTSFILE
    sudo sed -i '7 a cp '$RACHELRECOVERYDIR'/Weaved/Weaved*.conf /etc/weaved/services/' $RACHELSCRIPTSFILE
    sudo sed -i '8 a cp '$RACHELRECOVERYDIR'/Weaved/*.sh /usr/bin/' $RACHELSCRIPTSFILE
    sudo sed -i '9 a reboot #Weaved' $RACHELSCRIPTSFILE
    sudo sed -i '10 a fi #Weaved' $RACHELSCRIPTSFILE
}

download_offline_content () {
    trap ctrlC INT
    print_header
    echo; printStatus "** BETA ** Downloading RACHEL content for OFFLINE installs."

    echo; printQuestion "The OFFLINE RACHEL content folder is set to:  $DIRCONTENTOFFLINE"
    read -p "Do you want to change the default location? (y/n) " -r
    if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
        echo; printQuestion "What is the location of your content folder? "; read DIRCONTENTOFFLINE
        if [[ ! -d $DIRCONTENTOFFLINE ]]; then
            printError "The folder location does not exist!  Please identify the full path to your OFFLINE content folder and try again."
            rm -rf $INSTALLTMPDIR $RACHELTMPDIR
            exit 1
        fi
    fi
    wget -c $WGETONLINE/z-holding/dirlist.txt -O $DIRCONTENTOFFLINE/dirlist.txt        
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
            command_status
        done<$DIRCONTENTOFFLINE/dirlist.txt
        printGood "Done."
    fi
    printStatus "Downloading/updating the GitHub repo:  rachelplus"
    if [[ -d $DIRCONTENTOFFLINE/rachelplus ]]; then 
        cd $DIRCONTENTOFFLINE/rachelplus; git pull
    else
        echo; git clone https://github.com/rachelproject/rachelplus $DIRCONTENTOFFLINE/rachelplus
    fi
    command_status
    printGood "Done."

    echo; printStatus "Downloading/updating the GitHub repo:  contentshell"
    if [[ -d $DIRCONTENTOFFLINE/contentshell ]]; then 
        cd $DIRCONTENTOFFLINE/contentshell; git pull
    else
        echo; git clone https://github.com/rachelproject/contentshell $DIRCONTENTOFFLINE/contentshell
    fi
    command_status
    printGood "Done."

    echo; printStatus "Downloading/updating the GitHub repo:  ka-lite"
    if [[ -d $DIRCONTENTOFFLINE/ka-lite ]]; then 
        cd $DIRCONTENTOFFLINE/ka-lite; git pull
    else
        echo; git clone https://github.com/learningequality/ka-lite $DIRCONTENTOFFLINE/ka-lite
    fi
    command_status
    printGood "Done."
    
    echo; printStatus "Downloading/updating ka-lite_content.zip"
    wget -c $WGETONLINE/z-holding/ka-lite_content.zip -O $DIRCONTENTOFFLINE/ka-lite_content.zip
    command_status
    printGood "Done."

    echo; printStatus "Downloading/updating kiwix and data."
    wget -c $WGETONLINE/z-holding/kiwix-0.9-linux-i686.tar.bz2 -O $DIRCONTENTOFFLINE/kiwix-0.9-linux-i686.tar.bz2
    wget -c $WGETONLINE/z-holding/Ray_Charles.tar.bz -O $DIRCONTENTOFFLINE/Ray_Charles.tar.bz
    wget -c http://download.kiwix.org/portable/wikipedia/kiwix-0.9+wikipedia_en_for-schools_2013-01.zip -O $DIRCONTENTOFFLINE/kiwix-0.9+wikipedia_en_for-schools_2013-01.zip
    wget -c http://download.kiwix.org/portable/wikipedia/kiwix-0.9+wikipedia_en_all_2015-05.zip -O $DIRCONTENTOFFLINE/kiwix-0.9+wikipedia_en_all_2015-05.zip

    printGood "Done."

    echo; printStatus "Downloading/updating sphider_plus.sql"
    wget -c $WGETONLINE/z-SQLdatabase/sphider_plus.sql -O $DIRCONTENTOFFLINE/sphider_plus.sql
    command_status
    printGood "Done."
}

new_install () {
    trap ctrlC INT
    print_header
    echo; printStatus "Conducting a new install of RACHEL on a CAP."

    cd $INSTALLTMPDIR

    # Fix hostname issue in /etc/hosts
    echo; printStatus "Fixing hostname in /etc/hosts"
    sed -i 's/ec-server/WRTD-303N-Server/g' /etc/hosts
    printGood "Done."

    # Delete previous setup commands from the $RACHELSCRIPTSFILE
    echo; printStatus "Delete previous RACHEL setup commands from $RACHELSCRIPTSFILE"
    sed -i '/cap-rachel/d' $RACHELSCRIPTSFILE
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
            command_status
            break
        ;;

        # UK
        UK)
            echo; printStatus "Downloading packages from the United Kingdom."
            $SOURCEUK
            command_status
            break
        ;;

        # Singapore
        SG)
            echo; printStatus "Downloading packages from Singapore."
            $SOURCESG
            command_status
            break
        ;;

        # China (Original)
        CN)
            echo; printStatus "Downloading packages from the China - CAP manufacturer's website."
            $SOURCECN
            command_status
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
    command_status
    ## cap-rachel-first-install-3.sh
    echo; printStatus "Downloading cap-rachel-first-install-3.sh"
    $CAPRACHELFIRSTINSTALL3
    command_status
    ## lighttpd.conf - RACHEL version (I don't overwrite at this time due to other dependencies)
    echo; printStatus "Downloading lighttpd.conf"
    $LIGHTTPDFILE
    command_status

    # Download RACHEL Captive Portal files
    echo; printStatus "Downloading Captive Portal content to $INSTALLTMPDIR."

    echo; printStatus "Downloading captiveportal-redirect.php."
    $CAPTIVEPORTALREDIRECT
    command_status

    echo; printStatus "Downloading RACHELbrandLogo-captive.png."
    $RACHELBRANDLOGOCAPTIVE
    command_status
    
    echo; printStatus "Downloading HFCbrandLogo-captive.jpg."
    $HFCBRANDLOGOCAPTIVE
    command_status
    
    echo; printStatus "Downloading WorldPossiblebrandLogo-captive.png."
    $WORLDPOSSIBLEBRANDLOGOCAPTIVE
    command_status

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
    echo; printQuestion "NOTE: If /media/RACHEL/rachel folder exists, it will NOT destroy any content."
    echo "It will update the contentshell files with the latest ones from GitHub."

    echo; read -p "Are you ready to start the install? (y/n) " -r
    if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
        echo; printStatus "Starting first install script...please wait patiently (about 30 secs) for first reboot."
        printStatus "The entire script (with reboots) takes 2-5 minutes."

        # Update CAP package repositories
        echo; printStatus "Updating CAP package repositories"
        $GPGKEY1
        $GPGKEY2
        apt-get clean; apt-get purge; apt-get update
        printGood "Done."

        # Install packages
        echo; printStatus "Installing Git and PHP."
        apt-get -y install php5-cgi git-core python-m2crypto
        # Add the following line at the end of file
        echo "cgi.fix_pathinfo = 1" >> /etc/php5/cgi/php.ini
        printGood "Done."

        # Clone or update the RACHEL content shell from GitHub
        if [[ $INTERNET == "0" ]]; then cd $DIRCONTENTOFFLINE; else cd $INSTALLTMPDIR; fi
        echo; printStatus "Checking for pre-existing RACHEL content shell."
        if [[ ! -d $RACHELWWW ]]; then
            echo; printStatus "RACHEL content shell does not exist at $RACHELWWW."
            echo; printStatus "Cloning the RACHEL content shell from GitHub."
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
        rm -rf $RACHELTMPDIR/contentshell # if online install, remove contentshell temp folder
        printGood "Done."

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
        
        # Check if /media/RACHEL/rachel is already mounted
        if grep -qs '/media/RACHEL' /proc/mounts; then
            echo; printStatus "This hard drive is already partitioned for RACHEL, skipping hard drive repartitioning."
            echo; printGood "RACHEL CAP Install - Script ended at $(date)"
            echo; printGood "RACHEL CAP Install - Script 2 skipped (hard drive repartitioning) at $(date)"
            echo; printStatus "Executing RACHEL CAP Install - Script 3; CAP will reboot when install is complete."
            bash $INSTALLTMPDIR/cap-rachel-first-install-3.sh
        else
            # Repartition external 500GB hard drive into 3 partitions
            echo; printStatus "Repartitioning hard drive"
            sgdisk -p /dev/sda
            sgdisk -o /dev/sda
            parted -s /dev/sda mklabel gpt
            sgdisk -n 1:2048:+20G -c 1:"preloaded" -u 1:77777777-7777-7777-7777-777777777777 -t 1:8300 /dev/sda
            sgdisk -n 2:21G:+100G -c 2:"uploaded" -u 2:88888888-8888-8888-8888-888888888888 -t 2:8300 /dev/sda
            sgdisk -n 3:122G:-1M -c 3:"RACHEL" -u 3:99999999-9999-9999-9999-999999999999 -t 3:8300 /dev/sda
            sgdisk -p /dev/sda
            printGood "Done."

            # Add the new RACHEL partition /dev/sda3 to mount on boot
            echo; printStatus "Adding /dev/sda3 into /etc/fstab"
            sed -i '/\/dev\/sda3/d' /etc/fstab
            echo -e "/dev/sda3\t/media/RACHEL\t\text4\tauto,nobootwait 0\t0" >> /etc/fstab
            printGood "Done."

            # Add lines to $RACHELSCRIPTSFILE that will start the next script to run on reboot
            sudo sed -i '$e echo "bash '$INSTALLTMPDIR'\/cap-rachel-first-install-2.sh&"' $RACHELSCRIPTSFILE

            echo; printGood "RACHEL CAP Install - Script ended at $(date)"
            reboot-CAP
        fi
    else
        echo; printError "User requests not to continue...exiting at $(date)"
        # Deleting the install script commands
        cleanup
        echo; exit 1
    fi
}

content_module_install () {
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
            command_status
            printGood "Done."
        done < /tmp/module.lst
    fi
}

content_list_install () {
    trap ctrlC INT
    print_header
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
                command_status
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
                command_status
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
                command_status
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
                command_status
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
                command_status
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
            command_status
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
            command_status
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
            command_status
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
            command_status
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
    # Cleanup
    mv $RACHELLOG $RACHELLOGDIR/rachel-content-$TIMESTAMP.log
    echo; printGood "Log file saved to: $RACHELLOGDIR/rachel-content-$TIMESTAMP.log"
    printGood "KA Lite Content Install Complete."
    echo; printGood "Refresh the RACHEL homepage to view your new content."
}

ka-lite_remove () {
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

ka-lite_install () {
    # Downloading KA Lite 0.15
    echo; printStatus "Downloading KA Lite Version $KALITECURRENTVERSION"
    $KALITEINSTALL
    # Checking user provided file MD5 against known good version
    check_md5 $INSTALLTMPDIR/$KALITEINSTALLER
    if [[ $MD5STATUS == 1 ]]; then
        echo; printStatus "Installing KA Lite Version $KALITECURRENTVERSION"
        echo; printError "CAUTION:  When prompted, enter 'yes' for start on boot and change the user to 'root'."
        echo; mkdir -p /etc/ka-lite
        echo "root" > /etc/ka-lite/username
        # Turn off logging b/c KA Lite using a couple graphical screens; if on, causes issues
        exec &>/dev/tty
        dpkg -i $INSTALLTMPDIR/$KALITEINSTALLER
        command_status
        # Turn logging back on
        exec &> >(tee -a "$RACHELLOG")
        if [[ $ERRORCODE == 0 ]]; then
            echo; printGood "KA Lite $KALITECURRENTVERSION installed."
        else
            echo; printError "Something went wrong, please check the log file ($RACHELLOG) and try again."
            break
        fi
        update-rc.d ka-lite disable
    fi
}

ka-lite_setup () {
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
            ka-lite_remove
            # Install KA Lite
            ka-lite_install
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
            ka-lite_install
        fi
    else
        echo; printStatus "It doesn't look like KA Lite is installed; installing now."
        KALITEUSER="ka-lite"
        KALITEVERSIONDATE=0
        # Remove previous KA Lite
        ka-lite_remove
        # Install KA Lite
        ka-lite_install
    fi

    # For debug purposes, print ka-lite user
    echo; printStatus "KA Lite is installed as user:  $(cat /etc/ka-lite/username)"

    # Configure ka-lite
    echo; printStatus "Configuring KA Lite content settings file:  $KALITESETTINGS"
    printStatus "KA Lite content directory being set to:  $KALITERCONTENTDIR"
    sed -i '/^CONTENT_ROOT/d' $KALITESETTINGS
    sed -i '/^DATABASES/d' $KALITESETTINGS
    echo 'CONTENT_ROOT = "/media/RACHEL/kacontent"' >> $KALITESETTINGS
    echo "DATABASES['assessment_items']['NAME'] = os.path.join(CONTENT_ROOT, 'assessmentitems.sqlite')" >> $KALITESETTINGS

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
            check_md5 $ASSESSMENTFILE
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
                command_status
                    if [[ $ERRORCODE == 1 ]]; then
                    # Secondary download server
                    rsync -avhP $CONTENTONLINE/khan_assessment.zip $INSTALLTMPDIR/khan_assessment.zip
                fi
                # Checking user provided file MD5 against known good version
                check_md5 $INSTALLTMPDIR/khan_assessment.zip
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
    sudo sed -i '/sleep 20/d' $RACHELSCRIPTSFILE

    # Start KA Lite at boot time
    sudo sed -i '$e echo "# Start kalite at boot time"' $RACHELSCRIPTSFILE
    sudo sed -i '$e echo "sudo /usr/bin/kalite start"' $RACHELSCRIPTSFILE
    printGood "Done."
}

download_ka_content () {
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
            command_status
            if [[ $ERRORCODE == 1 ]]; then
                echo; printError "Primary repository for KA Content is not responding; attempting to download from the backup repository."
                echo "WEBSITE:  $WGETONLINE/z-holding/ka-lite_content.zip"
                wget -c $WGETONLINE/z-holding/ka-lite_content.zip -O $RACHELTMPDIR/ka-lite_content.zip
                # Checking user provided file MD5 against known good version
                check_md5 $RACHELTMPDIR/ka-lite_content.zip
                if [[ $MD5STATUS == 1 ]]; then
                    echo; printGood "Installing the KA Lite Content."
                fi
                unzip -o $RACHELTMPDIR/ka-lite_content.zip "kacontent/*" -d "$KALITERCONTENTDIR/"
                command_status
                if [[ $ERRORCODE == 1 ]]; then printError "Something went wrong; check $RACHELLOG for errors."; fi
            fi
        else
            echo; printStatus "Skipping content download/check."
        fi
    fi
}

repair () {
    print_header
    echo; printStatus "Repairing your CAP after a firmware upgrade."
    cd $INSTALLTMPDIR

    # Download/update to latest RACHEL lighttpd.conf
    echo; printStatus "Downloading latest lighttpd.conf"
    ## lighttpd.conf - RACHEL version (I don't overwrite at this time due to other dependencies and ensuring the file downloads correctly)
    $LIGHTTPDFILE
    command_status
    if [[ $ERRORCODE == 1 ]]; then
        print_error "The lighttpd.conf file did not download correctly; check log file (/var/log/RACHEL/rachel-install.tmp) and try again."
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
    echo; printStatus "Fixing $RACHELSCRIPTSFILE"

    # Add rachel-scripts.sh script
    sed "s,%RACHELSCRIPTSLOG%,$RACHELSCRIPTSLOG,g" > $RACHELSCRIPTSFILE << 'EOF'
#!/bin/bash
# Send output to log file
rm -f %RACHELSCRIPTSLOG%
exec 1>> %RACHELSCRIPTSLOG% 2>&1
# Add the RACHEL iptables rule to redirect 10.10.10.10 to CAP default of 192.168.88.1
# Added sleep to wait for CAP rcConf and rcConfd to finish initializing
#
sleep 60
iptables -t nat -I PREROUTING -d 10.10.10.10 -j DNAT --to-destination 192.168.88.1
exit 0
EOF

    # Add rachel-scripts.sh startup in /etc/rc.local
    sed -i '/scripts/d' /etc/rc.local
    sudo sed -i '$e echo "# Add RACHEL startup scripts"' /etc/rc.local
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
        sed -i '$e echo "\/var\/kiwix\/bin\/kiwix-serve --daemon --port=81 --library \/media\/RACHEL\/kiwix\/data\/library\/library.xml"' $RACHELSCRIPTSFILE
        printGood "Done."
    fi

    if [[ -d $KALITEDIR ]]; then
        echo; printStatus "Setting up KA Lite to start at boot..."
        # Delete previous setup commands from /etc/rc.local (not used anymore)
        sudo sed -i '/ka-lite/d' /etc/rc.local
        sudo sed -i '/sleep 20/d' /etc/rc.local
        # Delete previous setup commands from the $RACHELSCRIPTSFILE
        sudo sed -i '/ka-lite/d' $RACHELSCRIPTSFILE
        sudo sed -i '/kalite/d' $RACHELSCRIPTSFILE
        sudo sed -i '/sleep 20/d' $RACHELSCRIPTSFILE
        # Start KA Lite at boot time
        sudo sed -i '$e echo "# Start kalite at boot time"' $RACHELSCRIPTSFILE
        sudo sed -i '$e echo "sudo /usr/bin/kalite start"' $RACHELSCRIPTSFILE
        printGood "Done."
    fi

    # Add Weaved restore back into rachel-scripts.sh
    # Clean rachel-scripts.sh
    sed -i '/Weaved/d' $RACHELSCRIPTSFILE
    # Write restore commands to rachel-scripts.sh
    sudo sed -i '4 a # Restore Weaved configs, if needed' $RACHELSCRIPTSFILE
    sudo sed -i '5 a if [[ -d '$RACHELRECOVERYDIR'/Weaved ]] && [[ `ls /usr/bin/Weaved*.sh 2>/dev/null | wc -l` == 0 ]]; then' $RACHELSCRIPTSFILE
    sudo sed -i '6 a mkdir -p /etc/weaved/services #Weaved' $RACHELSCRIPTSFILE
    sudo sed -i '7 a cp '$RACHELRECOVERYDIR'/Weaved/Weaved*.conf /etc/weaved/services/' $RACHELSCRIPTSFILE
    sudo sed -i '8 a cp '$RACHELRECOVERYDIR'/Weaved/*.sh /usr/bin/' $RACHELSCRIPTSFILE
    sudo sed -i '9 a reboot #Weaved' $RACHELSCRIPTSFILE
    sudo sed -i '10 a fi #Weaved' $RACHELSCRIPTSFILE

    # Clean up outdated stuff
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
    reboot-CAP
}

# Loop to redisplay main menu
whattodo () {
    echo; printQuestion "What would you like to do next?"
    echo "1)Initial Install  2)Install KA Lite  3)Install Kiwix  4)Install Weaved Service  5)Add/Update Module  6)Add/Update Module List  7)Utilities  8)Exit"
}

#### MAIN MENU ####

# Logging
logging_start

# Display current script version
echo; echo "RACHEL CAP Configuration Script - Version $VERSION"
printGood "Started:  $(date)"
printGood "Log directory:  $RACHELLOGDIR"
printGood "Temporary file directory:  $INSTALLTMPDIR"

# Create temp directories
mkdir -p $INSTALLTMPDIR $RACHELTMPDIR $RACHELRECOVERYDIR

# Check OS version
osCheck

# Determine the operational mode - ONLINE or OFFLINE
opmode

# Build the hash list 
build_hash_list

# Change directory into $INSTALLTMPDIR
cd $INSTALLTMPDIR

echo; printQuestion "What you would like to do:"
echo "  - [Initial-Install] of RACHEL on a CAP"
echo "  - [Install-KA-Lite]"
echo "  - [Install-Kiwix]"
echo "  - [Install-Weaved-Service]"
echo "  - [Add-Update-Module] lists current available modules; installs one at a time"
echo "  - [Add-Update-Module-List] installs modules from a pre-configured list of modules"
echo "  - Other [Utilities]"
echo "    - Check your local file's MD5 against our database"
echo "    - Download RACHEL content to stage for OFFLINE installs"
echo "    - Uninstall a Weaved service"
echo "    - Repair an install of a CAP after a firmware upgrade"
echo "    - Sanitize CAP for imaging"
echo "    - Symlink all .mp4 videos in the module kaos-en to /media/RACHEL/kacontent"
echo "    - Test script"
echo "  - [Exit] the installation script"
echo
select menu in "Initial-Install" "Install-KA-Lite" "Install-Kiwix" "Install-Weaved-Service" "Add-Update-Module" "Add-Update-Module-List" "Utilities" "Exit"; do
        case $menu in
        Initial-Install)
        new_install
        ;;

        Install-KA-Lite)
        ka-lite_setup
        download_ka_content
        # Re-scanning content folder and exercise data 
        echo; printStatus "Restarting KA Lite in order to re-scan the content folder."
        kalite restart
        echo; printGood "Login using wifi at http://192.168.88.1:8008 and register device."
        echo "After you register, click the new tab called 'Manage', then 'Videos' and download all the missing videos."
        echo; printGood "Log file saved to: $RACHELLOGDIR/rachel-kalite-$TIMESTAMP.log"
        printGood "KA Lite Install Complete."
        mv $RACHELLOG $RACHELLOGDIR/rachel-kalite-$TIMESTAMP.log
        whattodo
        ;;

        Install-Kiwix)
        kiwix
        whattodo
        ;;

        Install-Weaved-Service)
        install_weaved_service
        backup_weaved_service
        whattodo
        ;;

        Add-Update-Module)
        content_module_install
        whattodo
        ;;

        Add-Update-Module-List)
        content_list_install
        whattodo
        ;;

        Utilities)
        echo; printQuestion "What utility would you like to use?"
        echo "  - [Check-MD5] will check a file you provide against our hash database"
        echo "  - **BETA** [Download-Installs-Content] for OFFLINE RACHEL installs"
        echo "  - [Uninstall-Weaved-Service]"
        echo "  - [Repair] an install of a CAP after a firmware upgrade"
        echo "  - [Sanitize] CAP for imaging"
        echo "  - [Symlink] all .mp4 videos in the module kaos-en to /media/RACHEL/kacontent"
        echo "  - [Test] script"
        echo "  - Return to [Main Menu]"
        echo
        select util in "Check-MD5" "Download-Installs-Content" "Backup-Weaved-Services" "Uninstall-Weaved-Service" "Repair" "Sanitize" "Symlink" "Test" "Main-Menu"; do
            case $util in
                Check-MD5)
                echo; printStatus "This function will compare the MD5 of the file you provide against our list of known hashes."
                printQuestion "What is the full path to the file you want to check?"; read MD5CHKFILE
                check_md5 $MD5CHKFILE
                break
                ;;

                Download-Installs-Content)
                download_offline_content
                break
                ;;

                Backup-Weaved-Services)
                backup_weaved_service
                break
                ;;

                Uninstall-Weaved-Service)
                uninstall_weaved_service
                backup_weaved_service
                break
                ;;

                Repair)
                repair
                break
                ;;

                Sanitize)
                sanitize
                break
                ;;

                Symlink)
                symlink
                break
                ;;

                Test)
                testing-script
                break
                ;;

                Main-Menu )
                break
                ;;
            esac
        done
        whattodo
        ;;

        Exit)
        cleanup
        echo; printStatus "User requested to exit."
        echo; exit 1
        ;;
        esac
done