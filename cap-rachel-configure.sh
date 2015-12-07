#!/bin/sh
# FILE: cap-rachel-configure.sh
# ONELINER Download/Install: sudo wget https://raw.githubusercontent.com/rachelproject/rachelplus/master/cap-rachel-configure.sh -O /root/cap-rachel-configure.sh; bash cap-rachel-configure.sh

# For offline builds, run the Download-Offline-Content script in the Utilities menu.

# COMMON VARIABLES - Change as needed
DIRCONTENTOFFLINE="/media/nas/rachel-content" # Enter directory of downloaded RACHEL content for offline install (e.g. I mounted my external USB on my CAP but plugging the external USB into and running the command 'fdisk -l' to find the right drive, then 'mkdir /media/RACHEL-Content' to create a folder to mount to, then 'mount /dev/sdb1 /media/RACHEL-Content' to mount the USB drive.)
RSYNCONLINE="rsync://dev.worldpossible.org" # The current RACHEL rsync repository
#CONTENTONLINE="rsync://rachel.golearn.us/content" # Another RACHEL rsync repository
CONTENTONLINE="rsync://192.168.255.4/content" # Another RACHEL rsync repository
WGETONLINE="http://rachelfriends.org" # RACHEL large file repo (ka-lite_content, etc)
GITRACHELPLUS="https://raw.githubusercontent.com/rachelproject/rachelplus/master" # RACHELPlus Scripts GitHub Repo
GITCONTENTSHELL="https://raw.githubusercontent.com/rachelproject/contentshell/master" # RACHELPlus ContentShell GitHub Repo

# CORE RACHEL VARIABLES - Change **ONLY** if you know what you are doing
VERSION=1027151630 # To get current version - date +%m%d%y%H%M
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
KALITEDIR="/var/ka-lite"
KALITERCONTENTDIR="/media/RACHEL/kacontent"
KALITESETTINGS="/root/.kalite/settings.py"
INSTALLTMPDIR="/root/cap-rachel-install.tmp"
RACHELTMPDIR="/media/RACHEL/cap-rachel-install.tmp"
mkdir -p $INSTALLTMPDIR $RACHELTMPDIR
DOWNLOADERROR="0"

# Check root
if [ "$(id -u)" != "0" ]; then
    printError "This step must be run as root; sudo password is 123lkj"
    exit 1
fi

# Logging
#exec &> >(tee "$HOME/$RACHELLOG")

# Fix backspace
stty sane

#in case you wish to kill it
trap 'exit 3' 1 2 3 15

# Capture a users Ctrl-C
ctrlC(){
    stty sane
    echo; printError "Cancelled by user."
    echo; exit $?
}

testing-script () {
    set -x
    trap ctrlC INT

    exit 1
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

opmode () {
    trap ctrlC INT
    echo; printQuestion "Do you want to run in ONLINE or OFFLINE mode?" | tee -a $RACHELLOG
    select MODE in "ONLINE" "OFFLINE"; do
        case $MODE in
        # ONLINE
        ONLINE)
            echo; printGood "Script set for 'ONLINE' mode." | tee -a $RACHELLOG
            INTERNET="1"
            online_variables
            check_internet
            break
        ;;
        # OFFLINE
        OFFLINE)
            echo; printGood "Script set for 'OFFLINE' mode." | tee -a $RACHELLOG
            INTERNET="0"
            offline_variables
            echo; printQuestion "The OFFLINE RACHEL content folder is set to:  $DIRCONTENTOFFLINE"
            read -p "Do you want to change the default location? (y/n) " -r <&1
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
        printGood "Done." | tee -a $RACHELLOG
        break
    done
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
    KALITEINSTALL="git clone https://github.com/learningequality/ka-lite /var/ka-lite"
    KALITEUPDATE="git pull"
    KALITECONTENTINSTALL="rsync -avhz --progress $CONTENTONLINE/kacontent/ /media/RACHEL/kacontent/"
#    KALITECONTENTINSTALL="wget -c $WGETONLINE/z-holding/ka-lite_content.zip -O $RACHELTMPDIR/ka-lite_content.zip"
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
    KALITEINSTALL="rsync -avhz --progress $DIRCONTENTOFFLINE/ka-lite /var/"
    KALITEUPDATE="rsync -avhz --progress $DIRCONTENTOFFLINE/ka-lite /var/"
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
    echo; printGood "RACHEL CAP Configuration Script - Version $VERSION" | tee $RACHELLOG
    printGood "Script started: $(date)" | tee -a $RACHELLOG
}

check_internet () {
    trap ctrlC INT
    if [[ $INTERNET == "1" || -z $INTERNET ]]; then
        # Check internet connecivity
        WGET=`which wget`
        $WGET -q --tries=10 --timeout=5 --spider http://google.com 1>> $RACHELLOG 2>&1
        if [[ $? -eq 0 ]]; then
            echo; printGood "Internet connection confirmed...continuing install." | tee -a $RACHELLOG
            INTERNET=1
        else
            echo; printError "No internet connectivity; waiting 10 seconds and then I will try again." | tee -a $RACHELLOG
            # Progress bar to visualize wait period
            while true;do echo -n .;sleep 1;done & 
            sleep 10
            kill $!; trap 'kill $!' SIGTERM
            $WGET -q --tries=10 --timeout=5 --spider http://google.com
            if [[ $? -eq 0 ]]; then
                echo; printGood "Internet connected confirmed...continuing install." | tee -a $RACHELLOG
                INTERNET=1
            else
                echo; printError "No internet connectivity; entering 'OFFLINE' mode." | tee -a $RACHELLOG
                offline_variables
                INTERNET=0
            fi
        fi
    fi
}

ctrlC () {
    kill $!; trap 'kill $1' SIGTERM
    echo; printError "Cancelled by user."
#    whattodo
#    rm $RACHELLOG
    cleanup
    echo; exit 1
}

command_status () {
    export EXITCODE="$?"
    if [[ $EXITCODE != 0 ]]; then
        printError "Command failed.  Exit code: $EXITCODE" | tee -a $RACHELLOG
        export DOWNLOADERROR="1"
    else
        printGood "Command successful." | tee -a $RACHELLOG
    fi
}

check_sha1 () {
    CALCULATEDHASH=$(openssl sha1 $1)
    KNOWNHASH=$(cat $INSTALLTMPDIR/rachelplus/hashes.txt | grep $1 | cut -f1 -d" ")
    if [ "SHA1(${1})= $2" = "${CALCULATEDHASH}" ]; then printGood "Good hash!" && export GOODHASH=1; else printError "Bad hash!"  && export GOODHASH=0; fi
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
    read -p "Enter 'y' to exit without cleaning up temporary folders/files. (y/N) " REPLY <&1
    if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
        exit 1
    fi
    # Deleting the install script commands
    echo; printStatus "Cleaning up install scripts."
    rm -rf $INSTALLTMPDIR $RACHELTMPDIR $0
    printGood "Done."
}

sanitize () {
    # Remove history, clean logs
    echo; printStatus "Sanitizing log files."
    rm -rf /var/log/rachel-install* /var/log/RACHEL/*
    rm -f /root/.ssh/known_hosts
    rm -f /media/RACHEL/ka-lite_content.zip
    rm -rf /recovery/2015*
    echo "" > /root/.bash_history
    # Stop script from defaulting the SSID
    sed -i 's/redis-cli del WlanSsidT0_ssid/#redis-cli del WlanSsidT0_ssid/g' /root/generate_recovery.sh
    # KA Lite
    echo; printStatus "Stopping KA Lite."
    /var/ka-lite/bin/kalite stop
    # Delete the Device ID and crypto keys from the database (without affecting the admin user you have already set up)
    echo; printStatus "Delete KA Lite Device ID and clearing crypto keys from the database"
    /var/ka-lite/bin/kalite manage runcode "from django.conf import settings; settings.DEBUG_ALLOW_DELETIONS = True; from securesync.models import Device; Device.objects.all().delete(); from fle_utils.config.models import Settings; Settings.objects.all().delete()"
    echo; printQuestion "Do you want to run the /root/generate_recovery.sh script?"
    read -p "    Select 'n' to exit. (y/n) " -r <&1
    if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
        rm -rf $INSTALLTMPDIR $RACHELTMPDIR
        /root/generate_recovery.sh
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

    printGood "Done." | tee -a $RACHELLOG
}

kiwix () {
    echo; printStatus "Installing kiwix." | tee -a $RACHELLOG
    $KIWIXINSTALL
    if [[ $INTERNET == "0" ]]; then cd $DIRCONTENTOFFLINE; else cd $RACHELTMPDIR; fi
    tar -C /var -xjvf kiwix-0.9-linux-i686.tar.bz2
    chown -R root:root /var/kiwix
    # Make content directory
    mkdir -p /media/RACHEL/kiwix
    echo; printQuestion "Kiwix will not start successfully until either the sample data or actual content is installed."
    read -p "Do you want to download a small sample data file? (y/n) " -r <&1
    if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
        $KIWIXSAMPLEDATA
        # Download a test file
        tar -C /media/RACHEL/kiwix -xjvf Ray_Charles.tar.bz
        cp /media/RACHEL/kiwix/data/library/wikipedia_en_ray_charles_2015-06.zim.xml  /media/RACHEL/kiwix/data/library/library.xml
        rm Ray_Charles.tar.bz
    fi
    # Start up Kiwix
    echo; printStatus "Starting Kiwix server." | tee -a $RACHELLOG
    /var/kiwix/bin/kiwix-serve --daemon --port=81 --library /media/RACHEL/kiwix/data/library/library.xml 1>> $RACHELLOG 2>&1
    echo; printStatus "Setting Kiwix to start on boot." | tee -a $RACHELLOG
    # Remove old kiwix boot lines from /etc/rc.local
    sed -i '/kiwix/d' /etc/rc.local 1>> $RACHELLOG 2>&1
    # Clean up current rachel-scripts.sh file
    sed -i '/kiwix/d' $RACHELSCRIPTSFILE 1>> $RACHELLOG 2>&1
    # Add lines to /etc/rc.local that will start kiwix on boot
    sed -i '$e echo "\# Start kiwix on boot"' $RACHELSCRIPTSFILE 1>> $RACHELLOG 2>&1
    sed -i '$e echo "\/var\/kiwix\/bin\/kiwix-serve --daemon --port=81 --library \/media\/RACHEL\/kiwix\/data\/library\/library.xml"' $RACHELSCRIPTSFILE 1>> $RACHELLOG 2>&1
}

sphider_plus.sql () {
RESULT=`mysqlshow --user=root --password=root sphider_plus| grep -v Wildcard | grep -o sphider_plus`
if [ "$RESULT" == "sphider_plus" ]; then
    echo; printError "The sphider_plus database is already installed."
else
    echo; printStatus "Installing sphider_plus.sql...be patient, this takes a couple minutes." | tee -a $RACHELLOG
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
        echo; printStatus "Installing Weaved service." | tee -a $RACHELLOG
        cd /root
        # Download weaved files
        echo; printStatus "Downloading required files."
        $WEAVEDZIP 1>> $RACHELLOG 2>&1
        command_status
        unzip -u weaved_software.zip 1>> $RACHELLOG 2>&1
        command_status
        if [[ $DOWNLOADERROR == 0 ]] && [[ -d weaved_software ]]; then
            rm -f /root/weaved_software.zip
            echo; printGood "Done." | tee -a $RACHELLOG
            # Run installer
            cd /root/weaved_software
            bash installer.sh
            echo; printGood "Weaved service install complete." | tee -a $RACHELLOG
            printGood "NOTE: An Weaved service uninstaller is available from the Utilities menu of this script." | tee -a $RACHELLOG
        else
            echo; printError "One or more files did not download correctly; check log file ($RACHELLOG) and try again." | tee -a $RACHELLOG
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
            cd /root/weaved_software
            bash uninstaller.sh
            echo; printGood "Weaved service uninstall complete." | tee -a $RACHELLOG
        }
        echo; printStatus "Uninstalling Weaved service." | tee -a $RACHELLOG
        cd /root
        # Run uninstaller
        if [[ -f /root/weaved_software/uninstaller.sh ]]; then 
            weaved_uninstaller
        else
            printError "The Weaved uninstaller does not exist. Attempting to download..." | tee -a $RACHELLOG
            if [[ $INTERNET == "1" ]]; then
                $WEAVEDZIP 1>> $RACHELLOG 2>&1
                command_status
                unzip -u weaved_software.zip 1>> $RACHELLOG 2>&1
                if [[ $DOWNLOADERROR == 0 ]] && [[ -d /root/weaved_software ]]; then
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

download_offline_content () {
    trap ctrlC INT
    print_header
    echo; printStatus "** BETA ** Downloading RACHEL content for OFFLINE installs." | tee -a $RACHELLOG

    echo; printQuestion "The OFFLINE RACHEL content folder is set to:  $DIRCONTENTOFFLINE" | tee -a $RACHELLOG
    read -p "Do you want to change the default location? (y/n) " -r <&1
    if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
        echo; printQuestion "What is the location of your content folder? "; read DIRCONTENTOFFLINE
        if [[ ! -d $DIRCONTENTOFFLINE ]]; then
            printError "The folder location does not exist!  Please identify the full path to your OFFLINE content folder and try again." | tee -a $RACHELLOG
            rm -rf $INSTALLTMPDIR $RACHELTMPDIR
            exit 1
        fi
    fi
    wget -c $WGETONLINE/z-holding/dirlist.txt -O $DIRCONTENTOFFLINE/dirlist.txt        
    # List the current directories on rachelfriends with this command:
    #   for i in $(ls -d */); do echo ${i%%/}; done
    if [[ ! -f $DIRCONTENTOFFLINE/dirlist.txt ]]; then
        echo; printError "The file $DIRCONTENTOFFLINE/dirlist.txt is missing!" | tee -a $RACHELLOG
        echo "    This file is a list of rsync folders; without it, I don't know what to rsync." | tee -a $RACHELLOG
        echo "    Create a newline separated list of directories to rsync in a file called 'dirlist.txt'." | tee -a $RACHELLOG
        echo "    Put the file in the same directory $DIRCONTENTOFFLINE" | tee -a $RACHELLOG
    else
        echo; printStatus "Rsyncing core RACHEL content from $RSYNCONLINE" | tee -a $RACHELLOG
        while read p; do
            echo; rsync -avz --ignore-existing $RSYNCONLINE/rachelmods/$p $DIRCONTENTOFFLINE/rachelmods
            command_status
        done<$DIRCONTENTOFFLINE/dirlist.txt
        printGood "Done." | tee -a $RACHELLOG
    fi
    printStatus "Downloading/updating the GitHub repo:  rachelplus" | tee -a $RACHELLOG
    if [[ -d $DIRCONTENTOFFLINE/rachelplus ]]; then 
        cd $DIRCONTENTOFFLINE/rachelplus; git pull
    else
        echo; git clone https://github.com/rachelproject/rachelplus $DIRCONTENTOFFLINE/rachelplus
    fi
    command_status
    printGood "Done." | tee -a $RACHELLOG

    echo; printStatus "Downloading/updating the GitHub repo:  contentshell" | tee -a $RACHELLOG
    if [[ -d $DIRCONTENTOFFLINE/contentshell ]]; then 
        cd $DIRCONTENTOFFLINE/contentshell; git pull
    else
        echo; git clone https://github.com/rachelproject/contentshell $DIRCONTENTOFFLINE/contentshell
    fi
    command_status
    printGood "Done." | tee -a $RACHELLOG

    echo; printStatus "Downloading/updating the GitHub repo:  ka-lite" | tee -a $RACHELLOG
    if [[ -d $DIRCONTENTOFFLINE/ka-lite ]]; then 
        cd $DIRCONTENTOFFLINE/ka-lite; git pull
    else
        echo; git clone https://github.com/learningequality/ka-lite $DIRCONTENTOFFLINE/ka-lite
    fi
    command_status
    printGood "Done." | tee -a $RACHELLOG
    
    echo; printStatus "Downloading/updating ka-lite_content.zip" | tee -a $RACHELLOG
    wget -c $WGETONLINE/z-holding/ka-lite_content.zip -O $DIRCONTENTOFFLINE/ka-lite_content.zip
    command_status
    printGood "Done." | tee -a $RACHELLOG

    echo; printStatus "Downloading/updating kiwix and data." | tee -a $RACHELLOG
    wget -c $WGETONLINE/z-holding/kiwix-0.9-linux-i686.tar.bz2 -O $DIRCONTENTOFFLINE/kiwix-0.9-linux-i686.tar.bz2
    wget -c $WGETONLINE/z-holding/Ray_Charles.tar.bz -O $DIRCONTENTOFFLINE/Ray_Charles.tar.bz
    wget -c http://download.kiwix.org/portable/wikipedia/kiwix-0.9+wikipedia_en_for-schools_2013-01.zip -O $DIRCONTENTOFFLINE/kiwix-0.9+wikipedia_en_for-schools_2013-01.zip
    wget -c http://download.kiwix.org/portable/wikipedia/kiwix-0.9+wikipedia_en_all_2015-05.zip -O $DIRCONTENTOFFLINE/kiwix-0.9+wikipedia_en_all_2015-05.zip

    printGood "Done." | tee -a $RACHELLOG

    echo; printStatus "Downloading/updating sphider_plus.sql" | tee -a $RACHELLOG
    wget -c $WGETONLINE/z-SQLdatabase/sphider_plus.sql -O $DIRCONTENTOFFLINE/sphider_plus.sql
    command_status
    printGood "Done." | tee -a $RACHELLOG
}

new_install () {
    trap ctrlC INT
    print_header
    echo; printStatus "Conducting a new install of RACHEL on a CAP."

    cd $INSTALLTMPDIR

    # Fix hostname issue in /etc/hosts
    echo; printStatus "Fixing hostname in /etc/hosts" | tee -a $RACHELLOG
    sed -i 's/ec-server/WRTD-303N-Server/g' /etc/hosts 1>> $RACHELLOG 2>&1
    printGood "Done." | tee -a $RACHELLOG

    # Delete previous setup commands from the /etc/rc.local
    echo; printStatus "Delete previous RACHEL setup commands from /etc/rc.local" | tee -a $RACHELLOG
    sed -i '/cap-rachel/d' /etc/rc.local 1>> $RACHELLOG 2>&1
    printGood "Done." | tee -a $RACHELLOG

    ## sources.list - replace the package repos for more reliable ones (/etc/apt/sources.list)
    # Backup current sources.list
    cp /etc/apt/sources.list /etc/apt/sources.list.bak 1>> $RACHELLOG 2>&1

    # Change the source repositories
    echo; printStatus "Locations for downloading packages:" | tee -a $RACHELLOG
    echo "    US) United States" | tee -a $RACHELLOG
    echo "    UK) United Kingdom" | tee -a $RACHELLOG
    echo "    SG) Singapore" | tee -a $RACHELLOG
    echo "    CN) China (CAP Manufacturer's Site)" | tee -a $RACHELLOG
    echo; printQuestion "For the package downloads, select the location nearest you? " | tee -a $RACHELLOG
    select CLASS in "US" "UK" "SG" "CN"; do
        case $CLASS in
        # US
        US)
            echo; printStatus "Downloading packages from the United States." | tee -a $RACHELLOG
            $SOURCEUS 1>> $RACHELLOG 2>&1
            command_status
            break
        ;;

        # UK
        UK)
            echo; printStatus "Downloading packages from the United Kingdom." | tee -a $RACHELLOG
            $SOURCEUK 1>> $RACHELLOG 2>&1
            command_status
            break
        ;;

        # Singapore
        SG)
            echo; printStatus "Downloading packages from Singapore." | tee -a $RACHELLOG
            $SOURCESG 1>> $RACHELLOG 2>&1
            command_status
            break
        ;;

        # China (Original)
        CN)
            echo; printStatus "Downloading packages from the China - CAP manufacturer's website." | tee -a $RACHELLOG
            $SOURCECN 1>> $RACHELLOG 2>&1
            command_status
            break
        ;;
        esac
        printGood "Done." | tee -a $RACHELLOG
        break
    done

    # Download/stage GitHub files to $INSTALLTMPDIR
    echo; printStatus "Downloading RACHEL install scripts for CAP to the temp folder $INSTALLTMPDIR." | tee -a $RACHELLOG
    ## cap-rachel-first-install-2.sh
    echo; printStatus "Downloading cap-rachel-first-install-2.sh" | tee -a $RACHELLOG
    $CAPRACHELFIRSTINSTALL2 1>> $RACHELLOG 2>&1
    command_status
    ## cap-rachel-first-install-3.sh
    echo; printStatus "Downloading cap-rachel-first-install-3.sh" | tee -a $RACHELLOG
    $CAPRACHELFIRSTINSTALL3 1>> $RACHELLOG 2>&1
    command_status
    ## lighttpd.conf - RACHEL version (I don't overwrite at this time due to other dependencies)
    echo; printStatus "Downloading lighttpd.conf" | tee -a $RACHELLOG
    $LIGHTTPDFILE 1>> $RACHELLOG 2>&1
    command_status

    # Download RACHEL Captive Portal files
    echo; printStatus "Downloading Captive Portal content to $INSTALLTMPDIR." | tee -a $RACHELLOG

    echo; printStatus "Downloading captiveportal-redirect.php." | tee -a $RACHELLOG
    $CAPTIVEPORTALREDIRECT 1>> $RACHELLOG 2>&1
    command_status

    echo; printStatus "Downloading RACHELbrandLogo-captive.png." | tee -a $RACHELLOG
    $RACHELBRANDLOGOCAPTIVE 1>> $RACHELLOG 2>&1
    command_status
    
    echo; printStatus "Downloading HFCbrandLogo-captive.jpg." | tee -a $RACHELLOG
    $HFCBRANDLOGOCAPTIVE 1>> $RACHELLOG 2>&1
    command_status
    
    echo; printStatus "Downloading WorldPossiblebrandLogo-captive.png." | tee -a $RACHELLOG
    $WORLDPOSSIBLEBRANDLOGOCAPTIVE 1>> $RACHELLOG 2>&1
    command_status

    # Check if files downloaded correctly
    if [[ $DOWNLOADERROR == 0 ]]; then
        echo; printGood "Done." | tee -a $RACHELLOG
    else
        echo; printError "One or more files did not download correctly; check log file ($RACHELLOG) and try again." | tee -a $RACHELLOG
        cleanup
        echo; exit 1
    fi

    # Show location of the log file
    echo; printStatus "Directory of RACHEL install log files with date/time stamps:" | tee -a $RACHELLOG
    echo "$RACHELLOGDIR" | tee -a $RACHELLOG

    # Ask if you are ready to install
    echo; printQuestion "NOTE: If /media/RACHEL/rachel folder exists, it will NOT destroy any content." | tee -a $RACHELLOG
    echo "It will update the contentshell files with the latest ones from GitHub." | tee -a $RACHELLOG

    echo; read -p "Are you ready to start the install? (y/n) " -r <&1
    if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
        echo; printStatus "Starting first install script...please wait patiently (about 30 secs) for first reboot." | tee -a $RACHELLOG
        printStatus "The entire script (with reboots) takes 2-5 minutes." | tee -a $RACHELLOG

        # Update CAP package repositories
        echo; printStatus "Updating CAP package repositories"
        $GPGKEY1 1>> $RACHELLOG 2>&1
        $GPGKEY2 1>> $RACHELLOG 2>&1
        apt-get clean; apt-get purge; apt-get update
        printGood "Done."

        # Install packages
        echo; printStatus "Installing Git and PHP." | tee -a $RACHELLOG
        apt-get -y install php5-cgi git-core python-m2crypto 1>> $RACHELLOG 2>&1
        # Add the following line at the end of file
        echo "cgi.fix_pathinfo = 1" >> /etc/php5/cgi/php.ini
        printGood "Done." | tee -a $RACHELLOG

        # Clone or update the RACHEL content shell from GitHub
        if [[ $INTERNET == "0" ]]; then cd $DIRCONTENTOFFLINE; else cd $INSTALLTMPDIR; fi
        echo; printStatus "Checking for pre-existing RACHEL content shell." | tee -a $RACHELLOG
        if [[ ! -d $RACHELWWW ]]; then
            echo; printStatus "RACHEL content shell does not exist at $RACHELWWW." | tee -a $RACHELLOG
            echo; printStatus "Cloning the RACHEL content shell from GitHub." | tee -a $RACHELLOG
            $GITCLONERACHELCONTENTSHELL
        else
            if [[ ! -d $RACHELWWW/.git ]]; then
                echo; printStatus "$RACHELWWW exists but it wasn't installed from git; installing RACHEL content shell from GitHub." | tee -a $RACHELLOG
                rm -rf contentshell 1>> $RACHELLOG 2>&1 # in case of previous failed install
                $GITCLONERACHELCONTENTSHELL
                cp -rf contentshell/* $RACHELWWW/ 1>> $RACHELLOG 2>&1 # overwrite current content with contentshell
                cp -rf contentshell/.git $RACHELWWW/ 1>> $RACHELLOG 2>&1 # copy over GitHub files
            else
                echo; printStatus "$RACHELWWW exists; updating RACHEL content shell from GitHub." | tee -a $RACHELLOG
                cd $RACHELWWW; git pull 1>> $RACHELLOG 2>&1
            fi
        fi
        rm -rf $RACHELTMPDIR/contentshell 1>> $RACHELLOG 2>&1 # if online install, remove contentshell temp folder
        printGood "Done." | tee -a $RACHELLOG

        # Install MySQL client and server
        echo; printStatus "Installing mysql client and server." | tee -a $RACHELLOG
        debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
        debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'
        cd /
        chown root:root /tmp 1>> $RACHELLOG 2>&1
        chmod 1777 /tmp 1>> $RACHELLOG 2>&1
        apt-get -y remove --purge mysql-server mysql-client mysql-common 1>> $RACHELLOG 2>&1
        apt-get -y install mysql-server mysql-client libapache2-mod-auth-mysql php5-mysql 1>> $RACHELLOG 2>&1
        printGood "Done."

        # Overwrite the lighttpd.conf file with our customized RACHEL version
        echo; printStatus "Updating lighttpd.conf to RACHEL version" | tee -a $RACHELLOG
        mv $INSTALLTMPDIR/lighttpd.conf /usr/local/etc/lighttpd.conf 1>> $RACHELLOG 2>&1
        printGood "Done." | tee -a $RACHELLOG
        
        # Check if /media/RACHEL/rachel is already mounted
        if grep -qs '/media/RACHEL' /proc/mounts; then
            echo; printStatus "This hard drive is already partitioned for RACHEL, skipping hard drive repartitioning." | tee -a $RACHELLOG
            echo; printGood "RACHEL CAP Install - Script ended at $(date)" | tee -a $RACHELLOG
            echo; printGood "RACHEL CAP Install - Script 2 skipped (hard drive repartitioning) at $(date)" | tee -a $RACHELLOG
            echo; printStatus "Executing RACHEL CAP Install - Script 3; CAP will reboot when install is complete."
            bash $INSTALLTMPDIR/cap-rachel-first-install-3.sh
        else
            # Repartition external 500GB hard drive into 3 partitions
            echo; printStatus "Repartitioning hard drive" | tee -a $RACHELLOG
            sgdisk -p /dev/sda 1>> $RACHELLOG 2>&1
            sgdisk -o /dev/sda 1>> $RACHELLOG 2>&1
            parted -s /dev/sda mklabel gpt 1>> $RACHELLOG 2>&1
            sgdisk -n 1:2048:+20G -c 1:"preloaded" -u 1:77777777-7777-7777-7777-777777777777 -t 1:8300 /dev/sda 1>> $RACHELLOG 2>&1
            sgdisk -n 2:21G:+100G -c 2:"uploaded" -u 2:88888888-8888-8888-8888-888888888888 -t 2:8300 /dev/sda 1>> $RACHELLOG 2>&1
            sgdisk -n 3:122G:-1M -c 3:"RACHEL" -u 3:99999999-9999-9999-9999-999999999999 -t 3:8300 /dev/sda 1>> $RACHELLOG 2>&1
            sgdisk -p /dev/sda 1>> $RACHELLOG 2>&1
            printGood "Done." | tee -a $RACHELLOG

            # Add the new RACHEL partition /dev/sda3 to mount on boot
            echo; printStatus "Adding /dev/sda3 into /etc/fstab" | tee -a $RACHELLOG
            sed -i '/\/dev\/sda3/d' /etc/fstab 1>> $RACHELLOG 2>&1
            echo -e "/dev/sda3\t/media/RACHEL\t\text4\tauto,nobootwait 0\t0" >> /etc/fstab
            printGood "Done." | tee -a $RACHELLOG

            # Add lines to /etc/rc.local that will start the next script to run on reboot
            sudo sed -i '$e echo "bash '$INSTALLTMPDIR'\/cap-rachel-first-install-2.sh&"' /etc/rc.local 1>> $RACHELLOG 2>&1

            echo; printGood "RACHEL CAP Install - Script ended at $(date)" | tee -a $RACHELLOG
            reboot-CAP
        fi
    else
        echo; printError "User requests not to continue...exiting at $(date)" | tee -a $RACHELLOG
        # Deleting the install script commands
        cleanup
        echo; exit 1
    fi
}

content_install () {
    trap ctrlC INT
    print_header
    DOWNLOADERROR="0"
    echo; printStatus "Installing RACHEL content." | tee -a $RACHELLOG
    if [[ $INTERNET == "0" ]]; then cd $DIRCONTENTOFFLINE; else cd $RACHELTMPDIR; fi

    # Add header/date/time to install log file
    echo; printError "CAUTION:  This process may take quite awhile if you do you not have a fast network connection." | tee -a $RACHELLOG
    echo "If you get disconnected, you only have to rerun this install again to continue.  It will not re-download content already on the CAP." | tee -a $RACHELLOG

    if [[ -d $RACHELWWW/modules ]]; then
        # Check permissions on modules
        echo; printStatus "Verifying proper permissions on modules prior to install." | tee -a $RACHELLOG
        chown -R root:root $RACHELWWW/modules
        printGood "Done." | tee -a $RACHELLOG
    else
        # Create a modules directory
        mkdir $RACHELWWW/modules
    fi

    echo; printQuestion "What content you would like to install:" | tee -a $RACHELLOG
    echo "  - [English] - English content" | tee -a $RACHELLOG
    echo "  - [Español] - Español content" | tee -a $RACHELLOG
    echo "  - [Français] - Français content" | tee -a $RACHELLOG
    echo "  - [Português] - Português content" | tee -a $RACHELLOG
    echo "  - [Hindi] - Hindi content" | tee -a $RACHELLOG
    echo "  - Exit to the [Main Menu]" | tee -a $RACHELLOG
    echo
    select menu in "English" "Español" "Français" "Português" "Hindi" "Main-Menu"; do
        case $menu in
        English)
        echo; printQuestion "What content you would like to install:" | tee -a $RACHELLOG
        echo "  - [English-KA] - English content based on KA" | tee -a $RACHELLOG
        echo "  - [English-Kaos] - English content based on Kaos" | tee -a $RACHELLOG
        echo "  - [English-Justice] - English content for Justice" | tee -a $RACHELLOG
        echo "  - Exit to [Content-Menu]" | tee -a $RACHELLOG
        echo
        select submenu in "English-KALite" "English-KAOS" "English-Justice" "Kiwix-Wikipedia-ALL" "Kiwix-Wikipedia-Schools" "Return"; do
            case $submenu in
            English-KALite)
            printStatus "Installing content for English (KA Lite)." | tee -a $RACHELLOG
            $DOWNLOADCONTENTSCRIPT/en_all_kalite.lst .
            while read p; do
                echo; printStatus "Downloading $p" | tee -a $RACHELLOG
                rsync -avz $RSYNCDIR/rachelmods/$p $RACHELWWW/modules/
                command_status
                printGood "Done." | tee -a $RACHELLOG
            done <en_all_kalite.lst
            break
            ;;

            English-KAOS)
            printStatus "Installing content for English (KA Lite)." | tee -a $RACHELLOG
            $DOWNLOADCONTENTSCRIPT/en_all_kaos.lst .
            while read p; do
                echo; printStatus "Downloading $p" | tee -a $RACHELLOG
                rsync -avz $RSYNCDIR/rachelmods/$p $RACHELWWW/modules/
                command_status
                printGood "Done." | tee -a $RACHELLOG
            done <en_all_kaos.lst
            break
            ;;

            English-Justice)
            printStatus "Installing content for English (Justice)." | tee -a $RACHELLOG
            $DOWNLOADCONTENTSCRIPT/en_justice.lst .
            while read p; do
                echo; printStatus "Downloading $p" | tee -a $RACHELLOG
                rsync -avz $RSYNCDIR/rachelmods/$p $RACHELWWW/modules/
                command_status
                printGood "Done." | tee -a $RACHELLOG
            done <en_justice.lst
            break
            ;;

            Kiwix-Wikipedia-ALL)
            FILENAME="kiwix-0.9+wikipedia_en_all_2015-05.zip"
            FILES=$(ls $RACHELPARTITION/kiwix/data/content/wikipedia_en_all_2015-05.zim* 2> /dev/null | wc -l)
            if [[ $FILES != "0" ]]; then
                echo; printError "The full Wikipedia is already installed." | tee -a $RACHELLOG
                if [[ ! -f $RACHELPARTITION/kiwix/data/library/library.xml ]]; then
                    echo; printError "The database seems to be corrupt, repairing." | tee -a $RACHELLOG
                    echo; /var/kiwix/bin/kiwix-manage $RACHELPARTITION/kiwix/data/library/library.xml add $RACHELPARTITION/kiwix/data/content/wikipedia_en_all_2015-05.zim --indexPath=$RACHELPARTITION/kiwix/data/index/wikipedia_en_all_2015-05.zim.idx 1>> $RACHELLOG 2>&1
                    echo; killall /var/kiwix/bin/kiwix-serve 1>> $RACHELLOG 2>&1
                    echo; /var/kiwix/bin/kiwix-serve --daemon --port=81 --library /media/RACHEL/kiwix/data/library/library.xml 1>> $RACHELLOG 2>&1
                    if [[ ! -f $RACHELPARTITION/kiwix/data/library/library.xml ]]; then
                        printError "Repair failed.  Please review the log file for additional details."
                    fi
                fi
            else
                echo; printStatus "Installing Kiwix content - Wikipedia ALL." | tee -a $RACHELLOG
                $CONTENTWIKI
                command_status
                unzip -o $FILENAME "data/*" -d "$RACHELPARTITION/kiwix/"
                if [[ $DOWNLOADERROR == 1 ]]; then
                    echo; printError "The zip file did not download correctly; if you want to try again, click 'yes' when it asks" | tee -a $RACHELLOG
                    echo "  if there were errors. The download will then continue where it left off." | tee -a $RACHELLOG
                    echo "  For more information, check the log file ($RACHELLOG)." | tee -a $RACHELLOG
                else
                    /var/kiwix/bin/kiwix-manage $RACHELPARTITION/kiwix/data/library/library.xml add $RACHELPARTITION/kiwix/data/content/wikipedia_en_all_2015-05.zim --indexPath=$RACHELPARTITION/kiwix/data/index/wikipedia_en_all_2015-05.zim.idx 1>> $RACHELLOG 2>&1
                    killall /var/kiwix/bin/kiwix-serve 1>> $RACHELLOG 2>&1
                    /var/kiwix/bin/kiwix-serve --daemon --port=81 --library /media/RACHEL/kiwix/data/library/library.xml 1>> $RACHELLOG 2>&1
                fi
            fi
            echo; printGood "View your module by clicking on Wikipedia from the RACHEL homepage."
            printGood "Done." | tee -a $RACHELLOG
            break
            ;;

            Kiwix-Wikipedia-Schools)
            FILENAME="kiwix-0.9+wikipedia_en_for-schools_2013-01.zip"
            FILES=$(ls $RACHELPARTITION/kiwix/data/content/wikipedia_en_for_schools_opt_2013.zim* 2> /dev/null | wc -l)
            if [[ $FILES != "0" ]]; then
                echo; printError "Wikipedia for Schools is already installed."                
                if [[ ! -f $RACHELPARTITION/kiwix/data/library/library.xml ]]; then
                    echo; printError "The database seems to be corrupt, repairing." | tee -a $RACHELLOG
                    echo; /var/kiwix/bin/kiwix-manage $RACHELPARTITION/kiwix/data/library/library.xml add $RACHELPARTITION/kiwix/data/content/wikipedia_en_for_schools_opt_2013.zim --indexPath=$RACHELPARTITION/kiwix/data/index/wikipedia_en_for_schools_opt_2013.zim.idx 1>> $RACHELLOG 2>&1
                    echo; killall /var/kiwix/bin/kiwix-serve 1>> $RACHELLOG 2>&1
                    echo; /var/kiwix/bin/kiwix-serve --daemon --port=81 --library /media/RACHEL/kiwix/data/library/library.xml 1>> $RACHELLOG 2>&1
                    if [[ ! -f $RACHELPARTITION/kiwix/data/library/library.xml ]]; then
                        printError "Repair failed.  Please review the log file for additional details."
                    fi
                fi
            else
                echo; printStatus "Installing Kiwix content - Wikipedia for Schools." | tee -a $RACHELLOG
                $CONTENTWIKI
                command_status
                unzip -o $FILENAME "data/*" -d "$RACHELPARTITION/kiwix/"
                if [[ $DOWNLOADERROR == 1 ]]; then
                    echo; printError "The zip file did not download correctly; if you want to try again, click 'yes' when it asks" | tee -a $RACHELLOG
                    echo "  if there were errors. The download will then continue where it left off." | tee -a $RACHELLOG
                    echo "  For more information, check the log file ($RACHELLOG)." | tee -a $RACHELLOG
                else
                    echo; /var/kiwix/bin/kiwix-manage $RACHELPARTITION/kiwix/data/library/library.xml add $RACHELPARTITION/kiwix/data/content/wikipedia_en_for_schools_opt_2013.zim --indexPath=$RACHELPARTITION/kiwix/data/index/wikipedia_en_for_schools_opt_2013.zim.idx 1>> $RACHELLOG 2>&1
                    echo; killall /var/kiwix/bin/kiwix-serve 1>> $RACHELLOG 2>&1
                    echo; /var/kiwix/bin/kiwix-serve --daemon --port=81 --library /media/RACHEL/kiwix/data/library/library.xml 1>> $RACHELLOG 2>&1
                fi
            fi
            printGood "View your module by clicking on Wikipedia from the RACHEL homepage."
            printGood "Done." | tee -a $RACHELLOG
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
        printStatus "Installing content for Español." | tee -a $RACHELLOG
        $DOWNLOADCONTENTSCRIPT/es_all_kaos.lst .
        while read p; do
            echo; printStatus "Downloading $p" | tee -a $RACHELLOG
            rsync -avz $RSYNCDIR/rachelmods/$p $RACHELWWW/modules/
            command_status
            printGood "Done." | tee -a $RACHELLOG
        done <es_all_kaos.lst
        break
        ;;

        Français)
        printStatus "Installing content for Français." | tee -a $RACHELLOG
        $DOWNLOADCONTENTSCRIPT/fr_all_kaos.lst .
        while read p; do
            echo; printStatus "Downloading $p" | tee -a $RACHELLOG
            rsync -avz $RSYNCDIR/rachelmods/$p $RACHELWWW/modules/
            command_status
            printGood "Done." | tee -a $RACHELLOG
        done <fr_all_kaos.lst
        break
        ;;

        Português)
        printStatus "Installing content for Português." | tee -a $RACHELLOG
        $DOWNLOADCONTENTSCRIPT/pt_all_kaos.lst .
        while read p; do
            echo; printStatus "Downloading $p" | tee -a $RACHELLOG
            rsync -avz $RSYNCDIR/rachelmods/$p $RACHELWWW/modules/
            command_status
            printGood "Done." | tee -a $RACHELLOG
        done <pt_all_kaos.lst
        break
        ;;

        Hindi)
        printStatus "Installing content for Hindi." | tee -a $RACHELLOG
        $DOWNLOADCONTENTSCRIPT/hi_all.lst .
        while read p; do
            echo; printStatus "Downloading $p" | tee -a $RACHELLOG
            rsync -avz $RSYNCDIR/rachelmods/$p $RACHELWWW/modules/
            command_status
            printGood "Done." | tee -a $RACHELLOG
        done <hi_all.lst
        break
        ;;

        Main-Menu)
        break
        ;;
        esac
    done

    # Check for errors is downloads
    if [[ $DOWNLOADERROR == 1 ]]; then
        echo; printError "One or more of the updates did not download correctly; for more information, check the log file ($RACHELLOG)." | tee -a $RACHELLOG
    fi

    # Check that all files are owned by root
    echo; printStatus "Verifying proper permissions on modules." | tee -a $RACHELLOG
    chown -R root:root $RACHELWWW/modules
    printGood "Done." | tee -a $RACHELLOG
    # Cleanup
    mv $RACHELLOG $RACHELLOGDIR/rachel-content-$TIMESTAMP.log
    echo; printGood "Log file saved to: $RACHELLOGDIR/rachel-content-$TIMESTAMP.log"
    printGood "KA Lite Content Install Complete."
    echo; printGood "Refresh the RACHEL homepage to view your new content."
}

repair () {
    print_header
    echo; printStatus "Repairing your CAP after a firmware upgrade."
    cd $INSTALLTMPDIR

    # Download/update to latest RACHEL lighttpd.conf
    echo; printStatus "Downloading latest lighttpd.conf" | tee -a $RACHELLOG
    ## lighttpd.conf - RACHEL version (I don't overwrite at this time due to other dependencies and ensuring the file downloads correctly)
    $LIGHTTPDFILE 1>> $RACHELLOG 2>&1
    command_status
    if [[ $DOWNLOADERROR == 1 ]]; then
        printError "The lighttpd.conf file did not download correctly; check log file (/var/log/RACHEL/rachel-install.tmp) and try again." | tee -a $RACHELLOG
        echo; break
    else
        mv $INSTALLTMPDIR/lighttpd.conf /usr/local/etc/lighttpd.conf
    fi
    printGood "Done." | tee -a $RACHELLOG

    # Reapply /etc/fstab entry for /media/RACHEL
    echo; printStatus "Adding /dev/sda3 into /etc/fstab" | tee -a $RACHELLOG
    sed -i '/\/dev\/sda3/d' /etc/fstab
    echo -e "/dev/sda3\t/media/RACHEL\t\text4\tauto,nobootwait 0\t0" >> /etc/fstab
    printGood "Done." | tee -a $RACHELLOG

    # Fixing /root/rachel-scripts.sh
    echo; printStatus "Fixing $RACHELSCRIPTSFILE" | tee -a $RACHELLOG

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
        echo; printStatus "Setting up Kiwix to start at boot..." | tee -a $RACHELLOG
        # Remove old kiwix boot lines from /etc/rc.local
        sed -i '/kiwix/d' /etc/rc.local 1>> $RACHELLOG 2>&1
        # Clean up current rachel-scripts.sh file
        sed -i '/kiwix/d' $RACHELSCRIPTSFILE 1>> $RACHELLOG 2>&1
        # Add lines to /etc/rc.local that will start kiwix on boot
        sed -i '$e echo "\# Start kiwix on boot"' $RACHELSCRIPTSFILE 1>> $RACHELLOG 2>&1
        sed -i '$e echo "\/var\/kiwix\/bin\/kiwix-serve --daemon --port=81 --library \/media\/RACHEL\/kiwix\/data\/library\/library.xml"' $RACHELSCRIPTSFILE 1>> $RACHELLOG 2>&1
        printGood "Done." | tee -a $RACHELLOG
    fi

    if [[ -d /var/ka-lite ]]; then
        echo; printStatus "Setting up KA Lite to start at boot..." | tee -a $RACHELLOG
        # Delete previous setup commands from the /etc/rc.local
        sed -i '/ka-lite/d' /etc/rc.local 1>> $RACHELLOG 2>&1
        sed -i '/sleep 20/d' /etc/rc.local 1>> $RACHELLOG 2>&1
        # Clean up current rachel-scripts.sh file
        sed -i '/ka-lite/d' $RACHELSCRIPTSFILE 1>> $RACHELLOG 2>&1
        sed -i '/sleep 20/d' $RACHELSCRIPTSFILE 1>> $RACHELLOG 2>&1
        # Start KA Lite at boot time
        sed -i '$e echo "# Start ka-lite at boot time"' $RACHELSCRIPTSFILE 1>> $RACHELLOG 2>&1
        sed -i '$e echo "sleep 20"' $RACHELSCRIPTSFILE 1>> $RACHELLOG 2>&1
        sed -i '$e echo "/var/ka-lite/bin/kalite restart"' $RACHELSCRIPTSFILE 1>> $RACHELLOG 2>&1
        printGood "Done." | tee -a $RACHELLOG
    fi

    # Clean up outdated stuff
    # Remove outdated startup script
    rm -f /root/iptables-rachel.sh

    # Delete previous setwanip commands from /etc/rc.local - not used anymore
    echo; printStatus "Deleting previous setwanip.sh script from /etc/rc.local" | tee -a $RACHELLOG
    sed -i '/setwanip/d' /etc/rc.local
    rm -f /root/setwanip.sh
    printGood "Done." | tee -a $RACHELLOG

    # Delete previous iptables commands from /etc/rc.local
    echo; printStatus "Deleting previous iptables script from /etc/rc.local" | tee -a $RACHELLOG
    sed -i '/iptables/d' /etc/rc.local
    printGood "Done." | tee -a $RACHELLOG

    echo; printGood "RACHEL CAP Repair Complete." | tee -a $RACHELLOG
    sudo mv $RACHELLOG $RACHELLOGDIR/rachel-repair-$TIMESTAMP.log
    echo; printGood "Log file saved to: $RACHELLOGDIR/rachel-repair-$TIMESTAMP.log" | tee -a $RACHELLOG
    cleanup
    reboot-CAP
}

ka-lite_install () {
    # Logging
    exec &> >(tee "$RACHELLOG")
    
    print_header
    echo; printStatus "Installing KA Lite."

#    # Let's install KA Lite under /var 
#    if [[ ! -d $KALITEDIR ]]; then
#      echo; printStatus "Cloning KA Lite from GitHub." | tee -a $RACHELLOG
#      $KALITEINSTALL 1>> $RACHELLOG 2>&1
#    else
#      echo; printStatus "KA Lite already exists; updating to latest build." | tee -a $RACHELLOG
#      cd $KALITEDIR; $KALITEUPDATE
#    fi
#    printGood "Done." | tee -a $RACHELLOG

    echo; printStatus "Checking KA Lite version."
    if [[ -f $KALITEDIR/kalite/local_settings.py ]]; then
        echo; printStatus "You are currently running an older version of KA Lite (pre 0.15)."
        # If needed, install KA Lite 0.15
        echo; read -p "Do you want to update to 0.15? (y/N) " -n 1 -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Removing old version
            echo; printStatus "Removing previous version of KA Lite."
            ## NEED TO KILL PREVIOUS KA-LITE PROCESS
            rm -rf /var/ka-lite

            # Downloading KA Lite 0.15
            echo; printStatus "Downloading KA Lite 0.15"
            wget -c https://learningequality.org/r/deb-bundle-installer-0-15 -O /tmp/ka-lite-bundle-0.15.0.deb
            echo; printStatus "Installing KA Lite 0.15"
            echo "NOTE:  When prompted, press enter on the default entries for the questions asked."
            echo; dpkg -i /tmp/ka-lite-bundle-0.15.0.deb
        else
            echo; printStatus "Exiting."
            echo; break
        fi
    fi
    printGood "KA Lite 0.15 installed."

    # Ask if there is local copy of the assessmentitems.json
    echo; printStatus "Downloading assessment items."

    echo; read -p "Do you have a local copy of the file khan_assessment.zip? (y/N) " -n 1 -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo; printQuestion "What is the full path to the file location for assessment items ZIP file (i.e. /root/khan_assessment.zip)?"; read JSONFILE || return
        while :; do
            if [[ ! -f $JSONFILE ]]; then
                echo; printError "FILE NOT FOUND - You must provide a file path of a location accessible from the CAP."
                echo; printQuestion "What is the full path to the file location for assessment items ZIP file?"; read JSONFILE
            else
                break
            fi
        done
        echo; printGood "Installing the assessment items."
        kalite manage unpack_assessment_zip $JSONFILE -f
    # If needed, download/install assessmentitems.json
    else
        echo; read -p "Do you want to attempt to download khan_assessment.zip from KA Lite online (warning, this file is near 500MB)? (y/N) " -n 1 -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kalite manage unpack_assessment_zip https://learningequality.org/downloads/ka-lite/0.15/content/assessment.zip -f
        else
            echo; printStatus "Skipping assessment items download."
        fi
    fi

    # Configure ka-lite
    echo; printStatus "Configuring KA Lite content directory in $KALITESETTINGS"
    sed -i '/CONTENT_ROOT/d' $KALITESETTINGS
    echo 'CONTENT_ROOT = "/media/RACHEL/kacontent"' >> $KALITESETTINGS

    # Install module for RACHEL index.php
    echo; printStatus "Syncing RACHEL web interface 'KA Lite module'."
    rsync -avz --ignore-existing $RSYNCDIR/rachelmods/ka-lite $RACHELWWW/modules/

    # Delete previous setup commands from the /etc/rc.local
#    echo; printStatus "Setting up KA Lite to start at boot..." | tee -a $RACHELLOG
    sudo sed -i '/ka-lite/d' /etc/rc.local
    sudo sed -i '/sleep 20/d' /etc/rc.local

    # Start KA Lite at boot time
#    sudo sed -i '$e echo "# Start ka-lite at boot time"' /etc/rc.local 1>> $RACHELLOG 2>&1
#    sudo sed -i '$e echo "sleep 20"' /etc/rc.local 1>> $RACHELLOG 2>&1
#    sudo sed -i '$e echo "/var/ka-lite/bin/kalite start"' /etc/rc.local 1>> $RACHELLOG 2>&1
#    printGood "Done." | tee -a $RACHELLOG

    # Starting KA Lite
#    echo; printStatus "Starting KA Lite..." | tee -a $RACHELLOG
#    /var/ka-lite/bin/kalite start 1>> $RACHELLOG 2>&1
#    printGood "Done." | tee -a $RACHELLOG

    # Add RACHEL IP
    echo; printGood "Login using wifi at http://192.168.88.1:8008 and register device."
    echo "After you register, click the new tab called 'Manage', then 'Videos' and download all the missing videos."
    echo; printGood "Log file saved to: $RACHELLOGDIR/rachel-kalite-$TIMESTAMP.log"
    printGood "KA Lite Install Complete."
    mv $RACHELLOG $RACHELLOGDIR/rachel-kalite-$TIMESTAMP.log

    # Reboot CAP
#    cleanup
#    reboot-CAP
}

download_ka_content () {
    # Setup KA Lite content
    echo; printStatus "The KA Lite content needs to downloaded/updated to its new home."
    mkdir -p KALITERCONTENTDIR
    $KALITECONTENTINSTALL
#    if [[ $INTERNET == "0" ]]; then cd $DIRCONTENTOFFLINE; else cd $RACHELTMPDIR; fi
#    echo; printStatus "Unzipping the archive to the correct folder...be patient, this takes about 45 minutes."
#    if [[ -d kacontent ]]; then
#        rsync -avzP ./kacontent /media/RACHEL
#    elif [[ -f ka-lite_content.zip ]]; then
#        unzip -u ka-lite_content.zip -d /media/RACHEL/
#        mv /media/RACHEL/content /media/RACHEL/kacontent 
#        if [[ -d /media/RACHEL/kacontent ]]; then
#            rm /media/RACHEL/ka-lite_content.zip
#        else
#            echo; printError "Failed to create the /media/RACHEL/kacontent folder; check the log file for more details."
#            echo "Zip file was NOT deleted and is available at /media/RACHEL/ka-lite_content.zip"
#        fi
#    else
#        echo; printError "KA Lite content not found."
#    fi
}

# Loop to redisplay mhf
whattodo () {
    echo; printQuestion "What would you like to do next?"
    echo "1)Initial Install  2)Install KA Lite  3)Install Kiwix  4)Install Sphider  5) Install Weaved Service  6)Install Content  7)Utilities  8)Exit"
}

## MAIN MENU
# Display current script version
echo; printGood "RACHEL CAP Configuration Script - Version $VERSION"

# Determine the operational mode - ONLINE or OFFLINE
opmode

# Change directory into $INSTALLTMPDIR
cd $INSTALLTMPDIR

echo; printQuestion "What you would like to do:" | tee -a $RACHELLOG
echo "  - [Initial-Install] of RACHEL on a CAP" | tee -a $RACHELLOG
echo "  - [Install-KA-Lite]" | tee -a $RACHELLOG
echo "  - [Install-Kiwix]" | tee -a $RACHELLOG
echo "  - [Install-Sphider]" | tee -a $RACHELLOG
echo "  - [Install-Weaved-Service]" | tee -a $RACHELLOG
echo "  - Install/Update RACHEL [Content]" | tee -a $RACHELLOG
echo "  - Other [Utilities]" | tee -a $RACHELLOG
echo "    - Repair an install of a CAP after a firmware upgrade" | tee -a $RACHELLOG
echo "    - Sanitize CAP for imaging" | tee -a $RACHELLOG
echo "    - Symlink all .mp4 videos in the module kaos-en to /media/RACHEL/kacontent" | tee -a $RACHELLOG
echo "    - Test script" | tee -a $RACHELLOG
echo "  - [Exit] the installation script" | tee -a $RACHELLOG
echo
select menu in "Initial-Install" "Install-KA-Lite" "Install-Kiwix" "Install-Sphider" "Install-Weaved-Service" "Content" "Utilities" "Exit"; do
        case $menu in
        Initial-Install)
        new_install
        ;;

        Install-KA-Lite)
        ka-lite_install `
        download_ka_content
        # Re-scanning content folder 
        echo; printStatus "Restarting KA Lite in order to re-scan the content folder."
        kalite restart
        whattodo
        ;;

        Install-Kiwix)
        kiwix
        whattodo
        ;;

        Install-Sphider)
        sphider_plus.sql
        whattodo
        ;;

        Install-Weaved-Service)
        install_weaved_service
        whattodo
        ;;

        Content)
        content_install
        whattodo
        ;;

        Utilities)
        echo; printQuestion "What utility would you like to use?" | tee -a $RACHELLOG
        echo "  - **BETA** [Download-Content] for OFFLINE RACHEL installs" | tee -a $RACHELLOG
        echo "  - [Uninstall-Weaved-Service]" | tee -a $RACHELLOG
        echo "  - [Repair] an install of a CAP after a firmware upgrade" | tee -a $RACHELLOG
        echo "  - [Sanitize] CAP for imaging" | tee -a $RACHELLOG
        echo "  - [Symlink] all .mp4 videos in the module kaos-en to /media/RACHEL/kacontent" | tee -a $RACHELLOG
        echo "  - [Test] script" | tee -a $RACHELLOG
        echo "  - Return to [Main Menu]" | tee -a $RACHELLOG
        echo
        select util in "Download-Content" "Uninstall-Weaved-Service" "Repair" "Sanitize" "Symlink" "Test" "Main-Menu"; do
            case $util in
                Download-Content)
                download_offline_content
                break
                ;;

                Uninstall-Weaved-Service)
                uninstall_weaved_service
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

