#!/bin/sh
# FILE: cap-rachel-configure-dev.sh
# ONELINER Download/Install: sudo wget https://raw.githubusercontent.com/rachelproject/rachelplus/master/cap-rachel-configure.sh -O /root/cap-rachel-configure.sh; bash cap-rachel-configure.sh

# For offline builds, run the Download-Offline-Content script in the Utilities menu.

# COMMON VARIABLES - Change as needed
VERSION=0814151223 # To get current version - date +%m%d%y%H%M
DIRCONTENTOFFLINE="/media/nascontent/rachel-content" # Enter directory of downloaded RACHEL content for offline install (e.g. I mounted my external USB on my CAP but plugging the external USB into and running the command 'fdisk -l' to find the right drive, then 'mkdir /media/RACHEL-Content' to create a folder to mount to, then 'mount /dev/sdb1 /media/RACHEL-Content' to mount the USB drive.)
RSYNCONLINE="rsync://dev.worldpossible.org" # The current RACHEL rsync repository
WGETONLINE="http://rachelfriends.org" # RACHEL large file repo (ka-lite_content, etc)
GITRACHELPLUS="https://raw.githubusercontent.com/rachelproject/rachelplus/master" # RACHELPlus Scripts GitHub Repo
GITCONTENTSHELL="https://raw.githubusercontent.com/rachelproject/contentshell/master" # RACHELPlus ContentShell GitHub Repo

# CORE RACHEL VARIABLES - Change **ONLY** if you know what you are doing
TIMESTAMP=$(date +"%b-%d-%Y-%H%M%Z")
INTERNET="1" # Enter 0 (Offline), 1 (Online - DEFAULT)
RACHELLOGDIR="/var/log/RACHEL"
mkdir -p $RACHELLOGDIR
RACHELLOGFILE="rachel-install.tmp"
RACHELLOG="$RACHELLOGDIR/$RACHELLOGFILE"
RACHELPARTITION="/media/RACHEL"
RACHELWWW="$RACHELPARTITION/rachel"
KALITEDIR="/var/ka-lite"
KALITERCONTENTDIR="/media/RACHEL/kacontent"
INSTALLTMPDIR="/root/cap-rachel-install.tmp"
RACHELTMPDIR="/media/RACHEL/cap-rachel-install.tmp"
mkdir -p $INSTALLTMPDIR $RACHELTMPDIR
DOWNLOADERROR="0"

# Check root
if [ "$(id -u)" != "0" ]; then
    print_error "This step must be run as root; sudo password is 123lkj"
    exit 1
fi

function testing-script () {
    set -x
    echo; print_status "Syncing 'Scratch'." | tee -a $RACHELLOG
    rsync -avz --ignore-existing $RSYNCDIR/rachelmods/scratch $RACHELWWW/modules/
    command_status
    print_good "Done." | tee -a $RACHELLOG
    # Great Books of the World
    echo; print_status "Syncing 'Great Books of the World'." | tee -a $RACHELLOG
    rsync -avz --ignore-existing $RSYNCDIR/rachelmods/ebooks-en $RACHELWWW/modules/
    command_status
    print_good "Done." | tee -a $RACHELLOG
    if [[ $DOWNLOADERROR == 1 ]]; then
        echo; print_error "One or more of the updates did not download correctly; for more information, check the log file ($RACHELLOG)." | tee -a $RACHELLOG
    fi
    exit 1
}

function print_good () {
    echo -e "\x1B[01;32m[+]\x1B[0m $1"
}

function print_error () {
    echo -e "\x1B[01;31m[-]\x1B[0m $1"
}

function print_status () {
    echo -e "\x1B[01;35m[*]\x1B[0m $1"
}

function print_question () {
    echo -e "\x1B[01;33m[?]\x1B[0m $1"
}

function opmode () {
    trap ctrl_c INT
    echo; print_question "Do you want to run in ONLINE or OFFLINE mode?" | tee -a $RACHELLOG
    select MODE in "ONLINE" "OFFLINE"; do
        case $MODE in
        # ONLINE
        ONLINE)
            echo; print_good "Script set for 'ONLINE' mode." | tee -a $RACHELLOG
            INTERNET="1"
            online_variables
            check_internet
            break
        ;;
        # OFFLINE
        OFFLINE)
            echo; print_good "Script set for 'OFFLINE' mode." | tee -a $RACHELLOG
            INTERNET="0"
            offline_variables
            echo; print_question "The OFFLINE RACHEL content folder is set to:  $DIRCONTENTOFFLINE"
            read -p "Do you want to change the default location? (y/n) " -r <&1
            if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
                echo; print_question "What is the location of your content folder? "; read DIRCONTENTOFFLINE
            fi
            if [[ ! -d $DIRCONTENTOFFLINE ]]; then
                print_error "The folder location does not exist!  Please identify the full path to your OFFLINE content folder and try again."
                rm -rf $INSTALLTMPDIR $RACHELTMPDIR
                exit 1
            else
                export DIRCONTENTOFFLINE
            fi
            break
        ;;
        esac
        print_good "Done." | tee -a $RACHELLOG
        break
    done
}

function online_variables () {
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
    RACHELBRANDLOGOCAPTIVE="wget -r $GITRACHELPLUS/captive-portal/RACHELbrandLogo-captive.png -O art/RACHELbrandLogo-captive.png"
    HFCBRANDLOGOCAPTIVE="wget -r $GITRACHELPLUS/captive-portal/HFCbrandLogo-captive.jpg -O art/HFCbrandLogo-captive.jpg"
    WORLDPOSSIBLEBRANDLOGOCAPTIVE="wget -r $GITRACHELPLUS/captive-portal/WorldPossiblebrandLogo-captive.png -O art/WorldPossiblebrandLogo-captive.png"
    GITCLONERACHELCONTENTSHELL="git clone https://github.com/rachelproject/contentshell $RACHELTMPDIR/contentshell"
    RSYNCDIR="$RSYNCONLINE"
    ASSESSMENTITEMSJSON="wget -c $GITRACHELPLUS/assessmentitems.json -O /var/ka-lite/data/khan/assessmentitems.json"
    KALITEINSTALL="git clone https://github.com/learningequality/ka-lite /var/ka-lite"
    KALITEUPDATE="git pull"
    KALITECONTENTINSTALL="wget -c http://rachelfriends.org/z-holding/ka-lite_content.zip -O $RACHELTMPDIR/ka-lite_content.zip"
    KIWIXINSTALL="wget -c http://rachelfriends.org/z-holding/kiwix-0.9-linux-i686.tar.bz2 -O $RACHELTMPDIR/kiwix-0.9-linux-i686.tar.bz2"
    SPHIDERPLUSSQLINSTALL="wget -c http://rachelfriends.org/z-SQLdatabase/sphider_plus.sql -O $RACHELTMPDIR/sphider_plus.sql"
}

function offline_variables () {
    GPGKEY1="apt-key add $DIRCONTENTOFFLINE/rachelplus/gpg-keys/437D05B5"
    GPGKEY2="apt-key add $DIRCONTENTOFFLINE/rachelplus/gpg-keys/3E5C1192"
    SOURCEUS="cp $DIRCONTENTOFFLINE/rachelplus/sources.list/sources-us.list /etc/apt/sources.list"
    SOURCEUK="cp $DIRCONTENTOFFLINE/rachelplus/sources.list/sources-uk.list /etc/apt/sources.list"
    SOURCESG="cp $DIRCONTENTOFFLINE/rachelplus/sources.list/sources-sg.list /etc/apt/sources.list"
    SOURCECN="cp $DIRCONTENTOFFLINE/rachelplus/sources.list/sources-cn.list /etc/apt/sources.list"
    CAPRACHELFIRSTINSTALL2="cp $DIRCONTENTOFFLINE/rachelplus/install/cap-rachel-first-install-2.sh ."
    CAPRACHELFIRSTINSTALL3="cp $DIRCONTENTOFFLINE/rachelplus/install/cap-rachel-first-install-3.sh ."
    LIGHTTPDFILE="cp $DIRCONTENTOFFLINE/rachelplus/lighttpd.conf ."
    CAPTIVEPORTALREDIRECT="cp $DIRCONTENTOFFLINE/rachelplus/captive-portal/captiveportal-redirect.php ."
    RACHELBRANDLOGOCAPTIVE="cp $DIRCONTENTOFFLINE/rachelplus/captive-portal/RACHELbrandLogo-captive.png ."
    HFCBRANDLOGOCAPTIVE="cp $DIRCONTENTOFFLINE/rachelplus/captive-portal/HFCbrandLogo-captive.jpg ."
    WORLDPOSSIBLEBRANDLOGOCAPTIVE="cp $DIRCONTENTOFFLINE/rachelplus/captive-portal/WorldPossiblebrandLogo-captive.png ."
    GITCLONERACHELCONTENTSHELL=""
    RSYNCDIR="$DIRCONTENTOFFLINE"
    ASSESSMENTITEMSJSON="cp $DIRCONTENTOFFLINE/rachelplus/assessmentitems.json /var/ka-lite/data/khan/assessmentitems.json"
    KALITEINSTALL="cp -r $DIRCONTENTOFFLINE/ka-lite /var/"
    KALITEUPDATE="cp -r $DIRCONTENTOFFLINE/ka-lite /var/"
    KALITECONTENTINSTALL=""
    KIWIXINSTALL=""
    SPHIDERPLUSSQLINSTALL=""
}

function print_header () {
    # Add header/date/time to install log file
    echo; print_good "RACHEL CAP Configuration Script - Version $VERSION" | tee $RACHELLOG
    print_good "Script started: $(date)" | tee -a $RACHELLOG
}

function check_internet () {
    trap ctrl_c INT
    if [[ $INTERNET == "1" || -z $INTERNET ]]; then
        # Check internet connecivity
        WGET=`which wget`
        $WGET -q --tries=10 --timeout=5 --spider http://google.com 1>> $RACHELLOG 2>&1
        if [[ $? -eq 0 ]]; then
            echo; print_good "Internet connection confirmed...continuing install." | tee -a $RACHELLOG
            INTERNET=1
        else
            echo; print_error "No internet connectivity; waiting 10 seconds and then I will try again." | tee -a $RACHELLOG
            # Progress bar to visualize wait period
            while true;do echo -n .;sleep 1;done & 
            sleep 10
            kill $!; trap 'kill $!' SIGTERM
            $WGET -q --tries=10 --timeout=5 --spider http://google.com
            if [[ $? -eq 0 ]]; then
                echo; print_good "Internet connected confirmed...continuing install." | tee -a $RACHELLOG
                INTERNET=1
            else
                echo; print_error "No internet connectivity; entering 'OFFLINE' mode." | tee -a $RACHELLOG
                offline_variables
                INTERNET=0
            fi
        fi
    fi
}

function ctrl_c () {
    kill $!; trap 'kill $1' SIGTERM
    echo; print_error "Cancelled by user."
#    whattodo
#    rm $RACHELLOG
    cleanup
    echo; exit 1
}

function command_status () {
    export EXITCODE="$?"
    if [[ $EXITCODE != 0 ]]; then
        print_error "Command failed.  Exit code: $EXITCODE" | tee -a $RACHELLOG
        export DOWNLOADERROR="1"
    else
        print_good "Command successful." | tee -a $RACHELLOG
    fi
}

function check_sha1 () {
    CALCULATEDHASH=$(openssl sha1 $1)
    KNOWNHASH=$(cat $INSTALLTMPDIR/rachelplus/hashes.txt | grep $1 | cut -f1 -d" ")
    if [ "SHA1(${1})= $2" = "${CALCULATEDHASH}" ]; then print_good "Good hash!" && export GOODHASH=1; else print_error "Bad hash!"  && export GOODHASH=0; fi
}

function reboot-CAP () {
    trap ctrl_c INT
    # No log as it won't clean up the tmp file
    echo; print_status "I need to reboot; new installs will reboot twice more automatically."
    echo; print_status "The file, $RACHELLOG, will be renamed to a dated log file when the script is complete."
    print_status "Rebooting in 10 seconds...Ctrl-C to cancel reboot."
    # Progress bar to visualize wait period
    # trap ctrl-c and call ctrl_c()
    while true; do
        echo -n .; sleep 1
    done & 
    sleep 10
    kill $!; trap 'kill $!' SIGTERM   
    reboot
}

function cleanup () {
    # No log as it won't clean up the tmp file
    echo; print_question "Were there errors?"
    read -p "Enter 'y' to exit without cleaning up temporary folders/files. (y/n) " -r <&1
    if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
        exit 1
    fi
    # Deleting the install script commands
    echo; print_status "Cleaning up install scripts."
    rm -rf /root/cap-rachel-* $RACHELTMPDIR
    print_good "Done."
}

function sanitize () {
    # Remove history, clean logs
    echo; print_status "Sanitizing log files."
    rm -rf /var/log/rachel-install* /var/log/RACHEL/*
    rm -f /root/.ssh/known_hosts
    rm -f /media/RACHEL/ka-lite_content.zip
    rm -rf /recovery/2015*
    echo "" > /root/.bash_history
    # Stop script from defaulting the SSID
    sed -i 's/redis-cli del WlanSsidT0_ssid/#redis-cli del WlanSsidT0_ssid/g' /root/generate_recovery.sh
    # KA Lite
    echo; print_status "Stopping KA Lite."
    /var/ka-lite/bin/kalite stop
    # Delete the Device ID and crypto keys from the database (without affecting the admin user you have already set up)
    echo; print_status "Delete KA Lite Device ID and clearing crypto keys from the database"
    /var/ka-lite/bin/kalite manage runcode "from django.conf import settings; settings.DEBUG_ALLOW_DELETIONS = True; from securesync.models import Device; Device.objects.all().delete(); from fle_utils.config.models import Settings; Settings.objects.all().delete()"
    echo; print_question "Do you want to run the /root/generate_recovery.sh script?"
    read -p "    Select 'n' to exit. (y/n) " -r <&1
    if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
        cleanup
        /root/generate_recovery.sh
    fi
    echo; print_good "Done."
}

function symlink () {
    trap ctrl_c INT
    print_header
    echo; print_status "Symlinking all .mp4 videos in the module 'kaos-en' to $KALITERCONTENTDIR"

    # Write python file for creating symlinks
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
    print_good "Done." | tee -a $RACHELLOG
}

function kiwix () {
    echo; print_status "Setting up kiwix." | tee -a $RACHELLOG
    $KIWIXINSTALL
    if [[ $INTERNET == "0" ]]; then cd $DIRCONTENTOFFLINE; else cd $RACHELTMPDIR; fi
    tar -C /var/ -xjvf kiwix-0.9-linux-i686.tar.bz2
    chown -R root:root /var/kiwix
    find /var/kiwix -type d -exec chmod 0755 {} \;
    find /var/kiwix -type f -exec chmod 0644 {} \;
    # Remove old kiwix boot lines from /etc/rc.local
    sed -i '/kiwix/d' /etc/rc.local 1>> $RACHELLOG 2>&1
    # Add lines to /etc/rc.local that will start kiwix on boot
    sed -i '$e echo "\# Start kiwix on boot"' /etc/rc.local 1>> $RACHELLOG 2>&1
    sed -i '$e echo "bash \/var\/kiwix\/bin\/kiwix-serve --daemon --port=81 --library \/media\/RACHEL\/kiwix\/data\/library\/library.xml"' /etc/rc.local 1>> $RACHELLOG 2>&1
    cleanup
}

function sphider_plus.sql () {
    echo; print_status "Installing sphider_plus.sql...be patient, this takes a couple minutes." | tee -a $RACHELLOG
    $SPHIDERPLUSSQLINSTALL
    if [[ $INTERNET == "0" ]]; then cd $DIRCONTENTOFFLINE; else cd $RACHELTMPDIR; fi
    mysql -u root -proot sphider_plus < sphider_plus.sql
    cleanup
}

function download_offline_content () {
    trap ctrl_c INT
    print_header
    echo; print_status "**BETA** Downloading RACHEL content for OFFLINE installs." | tee -a $RACHELLOG

    echo; print_question "The OFFLINE RACHEL content folder is set to:  $DIRCONTENTOFFLINE" | tee -a $RACHELLOG
    read -p "Do you want to change the default location? (y/n) " -r <&1
    if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
        echo; print_question "What is the location of your content folder? "; read DIRCONTENTOFFLINE
        if [[ ! -d $DIRCONTENTOFFLINE ]]; then
            print_error "The folder location does not exist!  Please identify the full path to your OFFLINE content folder and try again." | tee -a $RACHELLOG
            rm -rf $INSTALLTMPDIR $RACHELTMPDIR
            exit 1
        fi
    fi
    # List the current directories on rachelfriends with this command:
    #   for i in $(ls -d */); do echo ${i%%/}; done
    if [[ ! -f ./dirlist.txt ]]; then
        echo; print_error "The file $DIRCONTENTOFFLINE/dirlist.txt is missing!" | tee -a $RACHELLOG
        echo "    This file is a list of rsync folders; without it, I don't know what to rsync." | tee -a $RACHELLOG
        echo "    Create a newline separated list of directories to rsync in a file called 'dirlist.txt'." | tee -a $RACHELLOG
        echo "    Put the file in the same directory $DIRCONTENTOFFLINE" | tee -a $RACHELLOG
    else
        echo; print_status "Rsyncing core RACHEL content from $RSYNCONLINE" | tee -a $RACHELLOG
        while read p; do
            echo; rsync -avz --ignore-existing $RSYNCONLINE/rachelmods/$p $DIRCONTENTOFFLINE/rachelmods
            command_status
        done<$DIRCONTENTOFFLINE/dirlist.txt
        print_good "Done." | tee -a $RACHELLOG
    fi
    print_status "Downloading/updating the GitHub repo:  rachelplus" | tee -a $RACHELLOG
    if [[ -d $DIRCONTENTOFFLINE/rachelplus ]]; then 
        cd $DIRCONTENTOFFLINE/rachelplus; git pull
    else
        echo; git clone https://github.com/rachelproject/rachelplus $DIRCONTENTOFFLINE/rachelplus
    fi
    command_status
    print_good "Done." | tee -a $RACHELLOG

    echo; print_status "Downloading/updating the GitHub repo:  contentshell" | tee -a $RACHELLOG
    if [[ -d $DIRCONTENTOFFLINE/contentshell ]]; then 
        cd $DIRCONTENTOFFLINE/contentshell; git pull
    else
        echo; git clone https://github.com/rachelproject/contentshell $DIRCONTENTOFFLINE/contentshell
    fi
    command_status
    print_good "Done." | tee -a $RACHELLOG

    echo; print_status "Downloading/updating the GitHub repo:  ka-lite" | tee -a $RACHELLOG
    if [[ -d $DIRCONTENTOFFLINE/ka-lite ]]; then 
        cd $DIRCONTENTOFFLINE/ka-lite; git pull
    else
        echo; git clone https://github.com/learningequality/ka-lite $DIRCONTENTOFFLINE/ka-lite
    fi
    command_status
    print_good "Done." | tee -a $RACHELLOG
    
    echo; print_status "Downloading/updating ka-lite_content.zip" | tee -a $RACHELLOG
    wget -c $WGETONLINE/z-holding/ka-lite_content.zip -O $DIRCONTENTOFFLINE/ka-lite_content.zip
    command_status
    print_good "Done." | tee -a $RACHELLOG

    echo; print_status "Downloading/updating kiwix" | tee -a $RACHELLOG
    wget -c $WGETONLINE/z-holding/kiwix-0.9-linux-i686.tar.bz2 -O $DIRCONTENTOFFLINE/kiwix-0.9-linux-i686.tar.bz2
    command_status
    print_good "Done." | tee -a $RACHELLOG

    echo; print_status "Downloading/updating sphider_plus.sql" | tee -a $RACHELLOG
    wget -c $WGETONLINE/z-SQLdatabase/sphider_plus.sql -O $DIRCONTENTOFFLINE/sphider_plus.sql
    command_status
    print_good "Done." | tee -a $RACHELLOG
}

function new_install () {
    trap ctrl_c INT
    print_header
    echo; print_status "Conducting a new install of RACHEL on a CAP."

    cd $INSTALLTMPDIR

    # Fix hostname issue in /etc/hosts
    echo; print_status "Fixing hostname in /etc/hosts" | tee -a $RACHELLOG
    sed -i 's/ec-server/WRTD-303N-Server/g' /etc/hosts 1>> $RACHELLOG 2>&1
    print_good "Done." | tee -a $RACHELLOG

    # Delete previous setup commands from the /etc/rc.local
    echo; print_status "Delete previous RACHEL setup commands from /etc/rc.local" | tee -a $RACHELLOG
    sed -i '/cap-rachel/d' /etc/rc.local 1>> $RACHELLOG 2>&1
    print_good "Done." | tee -a $RACHELLOG

    ## sources.list - replace the package repos for more reliable ones (/etc/apt/sources.list)
    # Backup current sources.list
    cp /etc/apt/sources.list /etc/apt/sources.list.bak 1>> $RACHELLOG 2>&1

    # Change the source repositories
    echo; print_status "Locations for downloading packages:" | tee -a $RACHELLOG
    echo "    US) United States" | tee -a $RACHELLOG
    echo "    UK) United Kingdom" | tee -a $RACHELLOG
    echo "    SG) Singapore" | tee -a $RACHELLOG
    echo "    CN) China (CAP Manufacturer's Site)" | tee -a $RACHELLOG
    echo; print_question "For the package downloads, select the location nearest you? " | tee -a $RACHELLOG
    select CLASS in "US" "UK" "SG" "CN"; do
        case $CLASS in
        # US
        US)
            echo; print_status "Downloading packages from the United States." | tee -a $RACHELLOG
            $SOURCEUS 1>> $RACHELLOG 2>&1
            command_status
            break
        ;;

        # UK
        UK)
            echo; print_status "Downloading packages from the United Kingdom." | tee -a $RACHELLOG
            $SOURCEUK 1>> $RACHELLOG 2>&1
            command_status
            break
        ;;

        # Singapore
        SG)
            echo; print_status "Downloading packages from Singapore." | tee -a $RACHELLOG
            $SOURCESG 1>> $RACHELLOG 2>&1
            command_status
            break
        ;;

        # China (Original)
        CN)
            echo; print_status "Downloading packages from the China - CAP manufacturer's website." | tee -a $RACHELLOG
            $SOURCECN 1>> $RACHELLOG 2>&1
            command_status
            break
        ;;
        esac
        print_good "Done." | tee -a $RACHELLOG
        break
    done

    # Download/stage GitHub files to $INSTALLTMPDIR
    echo; print_status "Downloading RACHEL install scripts for CAP to the temp folder $INSTALLTMPDIR." | tee -a $RACHELLOG
    ## cap-rachel-first-install-2.sh
    echo; print_status "Downloading cap-rachel-first-install-2.sh" | tee -a $RACHELLOG
    $CAPRACHELFIRSTINSTALL2 1>> $RACHELLOG 2>&1
    command_status
    ## cap-rachel-first-install-3.sh
    echo; print_status "Downloading cap-rachel-first-install-3.sh" | tee -a $RACHELLOG
    $CAPRACHELFIRSTINSTALL3 1>> $RACHELLOG 2>&1
    command_status
    ## lighttpd.conf - RACHEL version (I don't overwrite at this time due to other dependencies)
    echo; print_status "Downloading lighttpd.conf" | tee -a $RACHELLOG
    $LIGHTTPDFILE 1>> $RACHELLOG 2>&1
    command_status

    # RACHEL Captive Portal file download
    echo; print_status "Downloading Captive Portal content to $INSTALLTMPDIR." | tee -a $RACHELLOG
    $CAPTIVEPORTALREDIRECT 1>> $RACHELLOG 2>&1
    command_status
    print_good "Downloaded captiveportal-redirect.php." | tee -a $RACHELLOG
    if [[ ! -f $RACHELWWW/art/RACHELbrandLogo-captive.png ]]; then
        $RACHELBRANDLOGOCAPTIVE 1>> $RACHELLOG 2>&1
        command_status
        echo; print_good "Downloaded RACHELbrandLogo-captive.png." | tee -a $RACHELLOG
    else
        echo; print_good "$RACHELWWW/art/RACHELbrandLogo-captive.png exists, skipping." | tee -a $RACHELLOG
    fi
    if [[ ! -f $RACHELWWW/art/HFCbrandLogo-captive.jpg ]]; then
        $HFCBRANDLOGOCAPTIVE 1>> $RACHELLOG 2>&1
        command_status
        echo; print_good "Downloaded HFCbrandLogo-captive.jpg." | tee -a $RACHELLOG
    else
        echo; print_good "$RACHELWWW/art/HFCbrandLogo-captive.jpg exists, skipping." | tee -a $RACHELLOG
    fi
    if [[ ! -f $RACHELWWW/art/WorldPossiblebrandLogo-captive.png ]]; then
        $WORLDPOSSIBLEBRANDLOGOCAPTIVE 1>> $RACHELLOG 2>&1
        command_status
        echo; print_good "Downloaded WorldPossiblebrandLogo-captive.png." | tee -a $RACHELLOG
    else
        echo; print_good "$RACHELWWW/art/WorldPossiblebrandLogo-captive.png exists, skipping." | tee -a $RACHELLOG
    fi

    # Check if files downloaded correctly
    if [[ $DOWNLOADERROR == 0 ]]; then
        echo; print_good "Done." | tee -a $RACHELLOG
    else
        echo; print_error "One or more files did not download correctly; check log file ($RACHELLOG) and try again." | tee -a $RACHELLOG
        cleanup
        echo; exit 1
    fi

    # Show location of the log file
    echo; print_status "Directory of RACHEL install log files with date/time stamps:" | tee -a $RACHELLOG
    echo "$RACHELLOGDIR" | tee -a $RACHELLOG

    # Ask if you are ready to install
    echo; print_question "NOTE: If /media/RACHEL/rachel folder exists, it will NOT destroy any content." | tee -a $RACHELLOG
    echo "It will update the contentshell files with the latest ones from GitHub." | tee -a $RACHELLOG

    echo; read -p "Are you ready to start the install? (y/n) " -r <&1
    if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
        echo; print_status "Starting first install script...please wait patiently (about 30 secs) for first reboot." | tee -a $RACHELLOG
        print_status "The entire script (with reboots) takes 2-5 minutes." | tee -a $RACHELLOG

        # Update CAP package repositories
        echo; print_status "Updating CAP package repositories"
        $GPGKEY1 1>> $RACHELLOG 2>&1
        $GPGKEY2 1>> $RACHELLOG 2>&1
        apt-get clean; apt-get purge; apt-get update
        print_good "Done."

        # Install packages
        echo; print_status "Installing Git and PHP." | tee -a $RACHELLOG
        apt-get -y install php5-cgi git-core python-m2crypto 1>> $RACHELLOG 2>&1
        # Add the following line at the end of file
        echo "cgi.fix_pathinfo = 1" >> /etc/php5/cgi/php.ini
        print_good "Done." | tee -a $RACHELLOG

        # Clone or update the RACHEL content shell from GitHub
        echo; print_status "Checking for pre-existing RACHEL content shell." | tee -a $RACHELLOG
        if [[ ! -d $RACHELWWW ]]; then
            echo; print_status "RACHEL content shell does not exist at $RACHELWWW." | tee -a $RACHELLOG
            echo; print_status "Cloning the RACHEL content shell from GitHub." | tee -a $RACHELLOG
            $GITCLONERACHELCONTENTSHELL
            if [[ $INTERNET == "0" ]]; then cd $DIRCONTENTOFFLINE; else cd $RACHELTMPDIR; fi
            cp -r contentshell/* $RACHELWWW/
        else
            if [[ ! -d $RACHELWWW/.git ]]; then
                echo; print_status "$RACHELWWW exists but it wasn't installed from git; installing RACHEL content shell from GitHub." | tee -a $RACHELLOG
                rm -rf $RACHELTMPDIR/contentshell 1>> $RACHELLOG 2>&1 # in case of previous failed install
                $GITCLONERACHELCONTENTSHELL
                cp -rf $RACHELTMPDIR/contentshell/* $RACHELWWW/ 1>> $RACHELLOG 2>&1 # overwrite current content with contentshell
                cp -rf $RACHELTMPDIR/contentshell/.git $RACHELWWW/ 1>> $RACHELLOG 2>&1 # copy over GitHub files
            else
                echo; print_status "$RACHELWWW exists; updating RACHEL content shell from GitHub." | tee -a $RACHELLOG
                cd $RACHELWWW; git pull 1>> $RACHELLOG 2>&1
            fi
        fi
        rm -rf $RACHELTMPDIR/contentshell 1>> $RACHELLOG 2>&1 # if online install, remove contentshell temp folder
        print_good "Done." | tee -a $RACHELLOG

        # Install MySQL client and server
        echo; print_status "Installing mysql client and server." | tee -a $RACHELLOG
        debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
        debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'
        cd /
        chown root:root /tmp 1>> $RACHELLOG 2>&1
        chmod 1777 /tmp 1>> $RACHELLOG 2>&1
        apt-get -y remove --purge mysql-server mysql-client mysql-common 1>> $RACHELLOG 2>&1
        apt-get -y install mysql-server mysql-client libapache2-mod-auth-mysql php5-mysql 1>> $RACHELLOG 2>&1
        print_good "Done."

        # Overwrite the lighttpd.conf file with our customized RACHEL version
        echo; print_status "Updating lighttpd.conf to RACHEL version" | tee -a $RACHELLOG
        mv $INSTALLTMPDIR/lighttpd.conf /usr/local/etc/lighttpd.conf 1>> $RACHELLOG 2>&1
        print_good "Done." | tee -a $RACHELLOG
        
        # Check if /media/RACHEL/rachel is already mounted
        if grep -qs '/media/RACHEL' /proc/mounts; then
            echo; print_status "This hard drive is already partitioned for RACHEL, skipping hard drive repartitioning." | tee -a $RACHELLOG
            echo; print_good "RACHEL CAP Install - Script ended at $(date)" | tee -a $RACHELLOG
            echo; print_good "RACHEL CAP Install - Script 2 skipped (hard drive repartitioning) at $(date)" | tee -a $RACHELLOG
            echo; print_status "Executing RACHEL CAP Install - Script 3; CAP will reboot when install is complete."
            bash $INSTALLTMPDIR/cap-rachel-first-install-3.sh
        else
            # Repartition external 500GB hard drive into 3 partitions
            echo; print_status "Repartitioning hard drive" | tee -a $RACHELLOG
            sgdisk -p /dev/sda 1>> $RACHELLOG 2>&1
            sgdisk -o /dev/sda 1>> $RACHELLOG 2>&1
            parted -s /dev/sda mklabel gpt 1>> $RACHELLOG 2>&1
            sgdisk -n 1:2048:+20G -c 1:"preloaded" -u 1:77777777-7777-7777-7777-777777777777 -t 1:8300 /dev/sda 1>> $RACHELLOG 2>&1
            sgdisk -n 2:21G:+100G -c 2:"uploaded" -u 2:88888888-8888-8888-8888-888888888888 -t 2:8300 /dev/sda 1>> $RACHELLOG 2>&1
            sgdisk -n 3:122G:-1M -c 3:"RACHEL" -u 3:99999999-9999-9999-9999-999999999999 -t 3:8300 /dev/sda 1>> $RACHELLOG 2>&1
            sgdisk -p /dev/sda 1>> $RACHELLOG 2>&1
            print_good "Done." | tee -a $RACHELLOG

            # Add the new RACHEL partition /dev/sda3 to mount on boot
            echo; print_status "Adding /dev/sda3 into /etc/fstab" | tee -a $RACHELLOG
            sed -i '/\/dev\/sda3/d' /etc/fstab 1>> $RACHELLOG 2>&1
            echo -e "/dev/sda3\t/media/RACHEL\t\text4\tauto,nobootwait 0\t0" >> /etc/fstab
            print_good "Done." | tee -a $RACHELLOG

            # Add lines to /etc/rc.local that will start the next script to run on reboot
            sudo sed -i '$e echo "bash '$INSTALLTMPDIR'\/cap-rachel-first-install-2.sh&"' /etc/rc.local 1>> $RACHELLOG 2>&1

            echo; print_good "RACHEL CAP Install - Script ended at $(date)" | tee -a $RACHELLOG
            reboot-CAP
        fi
    else
        echo; print_error "User requests not to continue...exiting at $(date)" | tee -a $RACHELLOG
        # Deleting the install script commands
        cleanup
        echo; exit 1
    fi
}

function repair () {
    print_header
    echo; print_status "Repairing your CAP after a firmware upgrade."
    # Download/update to latest RACHEL lighttpd.conf
    echo; print_status "Downloading latest lighttpd.conf" | tee -a $RACHELLOG
    ## lighttpd.conf - RACHEL version (I don't overwrite at this time due to other dependencies and ensuring the file downloads correctly)
    $LIGHTTPDFILE 1>> $RACHELLOG 2>&1
    command_status
    if [[ $DOWNLOADERROR == 1 ]]; then
        print_error "The lighttpd.conf file did not download correctly; check log file (/var/log/RACHEL/rachel-install.tmp) and try again." | tee -a $RACHELLOG
        echo; break
    fi
    print_good "Done." | tee -a $RACHELLOG

    # Reapply /etc/fstab entry for /media/RACHEL
    echo; print_status "Adding /dev/sda3 into /etc/fstab" | tee -a $RACHELLOG
    sed -i '/\/dev\/sda3/d' /etc/fstab
    echo -e "/dev/sda3\t/media/RACHEL\t\text4\tauto,nobootwait 0\t0" >> /etc/fstab
    print_good "Done." | tee -a $RACHELLOG

    # Fixing /etc/rc.local to start KA Lite on boot
    echo; print_status "Fixing /etc/rc.local" | tee -a $RACHELLOG
    # Delete previous setup commands from the /etc/rc.local
    echo; print_status "Setting up KA Lite to start at boot..." | tee -a $RACHELLOG
    sed -i '/ka-lite/d' /etc/rc.local 1>> $RACHELLOG 2>&1
    sed -i '/sleep 20/d' /etc/rc.local 1>> $RACHELLOG 2>&1

    # Start KA Lite at boot time
    sed -i '$e echo "# Start ka-lite at boot time"' /etc/rc.local 1>> $RACHELLOG 2>&1
    sed -i '$e echo "sleep 20"' /etc/rc.local 1>> $RACHELLOG 2>&1
    sed -i '$e echo "/var/ka-lite/bin/kalite start"' /etc/rc.local 1>> $RACHELLOG 2>&1
    print_good "Done." | tee -a $RACHELLOG

    # Delete previous setwanip commands from /etc/rc.local
    echo; print_status "Deleting previous setwanip.sh script from /etc/rc.local" | tee -a $RACHELLOG
    sed -i '/setwanip/d' /etc/rc.local
    rm -f /root/setwanip.sh
    print_good "Done." | tee -a $RACHELLOG

    # Delete previous iptables commands from /etc/rc.local
    echo; print_status "Deleting previous iptables script from /etc/rc.local" | tee -a $RACHELLOG
    sed -i '/iptables/d' /etc/rc.local
    print_good "Done." | tee -a $RACHELLOG

    # Fix the iptables-rachel.sh script
    cat > /root/iptables-rachel.sh << 'EOF'
#!/bin/bash
# Add the RACHEL iptables rule to redirect 10.10.10.10 to CAP default of 192.168.88.1
# Added sleep to wait for CAP rcConf and rcConfd to finish initializing
#
sleep 60
iptables -t nat -I PREROUTING -d 10.10.10.10 -j DNAT --to-destination 192.168.88.1
EOF

    # Add 10.10.10.10 redirect on every reboot
    sudo sed -i '$e echo "# RACHEL iptables - Redirect from 10.10.10.10 to 192.168.88.1"' /etc/rc.local
    #sudo sed -i '$e echo "iptables -t nat -A OUTPUT -d 10.10.10.10 -j DNAT --to-destination 192.168.88.1&"' /etc/rc.local
    sudo sed -i '$e echo "bash /root/iptables-rachel.sh&"' /etc/rc.local

    echo; print_good "RACHEL CAP Repair Complete." | tee -a $RACHELLOG
    sudo mv $RACHELLOG $RACHELLOGDIR/rachel-repair-$TIMESTAMP.log
    echo; print_good "Log file saved to: $RACHELLOGDIR/rachel-repair-$TIMESTAMP.log" | tee -a $RACHELLOG
    cleanup
    reboot-CAP
}

function content_install () {
    trap ctrl_c INT
    print_header
    DOWNLOADERROR="0"
    echo; print_status "Installing RACHEL content." | tee -a $RACHELLOG
    # Add header/date/time to install log file
    echo; print_good "RACHEL Content Install Script - Version $(date +%m%d%y%H%M)" | tee -a $RACHELLOG
    print_good "Install started: $(date)" | tee -a $RACHELLOG   
    echo; print_error "CAUTION:  This process may take quite awhile if you do you not have a fast network connection." | tee -a $RACHELLOG
    echo "If you get disconnected, you only have to rerun this install again to continue.  It will not re-download content already on the CAP." | tee -a $RACHELLOG

    # Check permissions on modules
    echo; print_status "Verifying proper permissions on modules prior to install." | tee -a $RACHELLOG
    chown -R root:root $RACHELWWW/modules
    print_good "Done." | tee -a $RACHELLOG
    # Ask what content language the user wants to download
    echo; print_question "What language would you like to download content for? " | tee -a $RACHELLOG
    echo; select class in "English" "Español" "Français" "Português" "Hindi" "Exit"; do
        case $class in
        English)
            # Great Books of the World
            echo; print_status "Syncing 'Great Books of the World'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/ebooks-en $RACHELWWW/modules/
            command_status
            print_good "Done." | tee -a $RACHELLOG
            # Hesperian Health Guides
            echo; print_status "Syncing 'Hesperian Health Guides'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/hesperian_health $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            # UNESCO's IICBA Electronic Library
            echo; print_status "Syncing 'UNESCO's IICBA Electronic Library'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/iicba $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            # Infonet-Biovision
            echo; print_status "Syncing 'Infonet-Biovision'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/infonet $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            # Khan Academy
            echo; print_status "Syncing 'Khan Academy'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/kaos-en $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            # Khan Academy Health & Medicine
            echo; print_status "Syncing 'Khan Academy Health & Medicine'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/khan_health $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            # Math Expression
            echo; print_status "Syncing 'Math Expression'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/math_expression $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            # MedlinePlus Medical Encyclopedia
            echo; print_status "Syncing 'MedlinePlus Medical Encyclopedia'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/medline_plus $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            # Music Theory
            echo; print_status "Syncing 'Music Theory'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/musictheory $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            # OLPC Educational Packages
            echo; print_status "Syncing 'OLPC Educational Packagess'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/olpc $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            # Powertyping
            echo; print_status "Syncing 'Powertyping'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/powertyping $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            # Practical Action
            echo; print_status "Syncing 'Practical Action'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/practical_action $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            # MIT Scratch
            echo; print_status "Syncing 'MIT Scratch'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/scratch $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            # Understanding Algebra
            echo; print_status "Syncing 'Understanding Algebra'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/understanding_algebra $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            # Wikipedia for Schools
            echo; print_status "Syncing 'Wikipedia for Schools'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/wikipedia_for_schools $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            # CK-12 Textbooks
            echo; print_status "Syncing 'CK-12 Textbooks'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/ck12 $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            # Rasp Pi User Guide
            echo; print_status "Syncing 'Rasp Pi User Guide'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/rpi_guide $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            # Windows Applications
            echo; print_status "Syncing 'Windows Applications'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/windows_apps $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            # Medical Information
            echo; print_status "Syncing 'Medical Information'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/asst_medical $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            # PhET
            echo; print_status "Syncing 'PhET'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/PhET $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            # TED
            echo; print_status "Syncing 'TED'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/TED $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            # GCF
            echo; print_status "Syncing 'GCF'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/GCF $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            # radiolab
            echo; print_status "Syncing 'radiolab'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/radiolab $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            break
        ;;
        Español)
            # Grandes Libros del Mundo
            echo; print_status "Syncing 'Grandes Libros del Mundo'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/ebooks-es $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            # Khan Academy
            echo; print_status "Syncing 'Khan Academy'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/kaos-es $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            # Aplicaciones Didacticas
            echo; print_status "Syncing 'Aplicaciones Didacticas'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/ap_didact $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            # Currículum Nacional Base Guatemala
            echo; print_status "Syncing 'Currículum Nacional Base Guatemala'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/cnbguatemala $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            break
        ;;
        Français)
            # Khan Academy
            echo; print_status "Syncing 'Khan Academy'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/kaos-fr $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            break
        ;;
        Português)
            # Khan Academy
            echo; print_status "Syncing 'Khan Academy'." | tee -a $RACHELLOG
            rsync -avz --ignore-existing $RSYNCDIR/rachelmods/kaos-pt $RACHELWWW/modules/ 
            command_status
            print_good "Done." | tee -a $RACHELLOG
            break
        ;;
        Hindi)
            # Toys from Trash
            echo; print_status "Syncing 'Toys from Trash'." | tee -a $RACHELLOG
            rsync -avz rsync://dev.worldpossible.org/rachelmods/bibliofilo ./
            command_status
            print_good "Done." | tee -a $RACHELLOG
            break
        ;;
        Exit)
            echo; break
        ;;
        esac
    done
    if [[ $DOWNLOADERROR == 1 ]]; then
        echo; print_error "One or more of the updates did not download correctly; for more information, check the log file ($RACHELLOG)." | tee -a $RACHELLOG
    fi
    # Check that all KA videos are symlinked to /media/RACHEL/kacontent
    echo; print_status "Symbolically linking all KAOS videos to $KALITERCONTENTDIR." | tee -a $RACHELLOG
    symlink
    # Check that all files are owned by root
    echo; print_status "Verifying proper permissions on modules." | tee -a $RACHELLOG
    chown -R root:root $RACHELWWW/modules
    print_good "Done." | tee -a $RACHELLOG
    # Cleanup
    mv $RACHELLOG $RACHELLOGDIR/rachel-content-$TIMESTAMP.log
    echo; print_good "Log file saved to: $RACHELLOGDIR/rachel-content-$TIMESTAMP.log"
    print_good "KA Lite Content Install Complete."
    echo; print_good "Refresh the RACHEL homepage to view your new content."
}

function ka-lite_install () {
    print_header
    echo; print_status "Installing KA Lite."

    # Let's install KA Lite under /var 
    if [[ ! -d $KALITEDIR ]]; then
      echo; print_status "Cloning KA Lite from GitHub." | tee -a $RACHELLOG
      $KALITEINSTALL 1>> $RACHELLOG 2>&1
    else
      echo; print_status "KA Lite already exists; updating files." | tee -a $RACHELLOG
      cd $KALITEDIR; $KALITEUPDATE
    fi
    print_good "Done." | tee -a $RACHELLOG

    # Download/install assessmentitems.json
    echo; print_status "Downloading latest assessmentitems.json from GitHub." | tee -a $RACHELLOG
    $ASSESSMENTITEMSJSON
    print_good "Done." | tee -a $RACHELLOG

    # Linux setup of KA Lite
    echo; print_status "Use the following inputs when answering the setup questions:" | tee -a $RACHELLOG
    echo; print_question "For new installs:"
    echo "User - rachel"  | tee -a $RACHELLOG
    echo "Password (x2) - rachel" | tee -a $RACHELLOG
    echo "Name and describe server as desired" | tee -a $RACHELLOG
    echo "Download exercise pack? no" | tee -a $RACHELLOG
    echo "Already downloaded? no" | tee -a $RACHELLOG
    echo "Start at boot? n" | tee -a $RACHELLOG
    echo; print_question "For previous installs:"
    echo "Keep database file - yes (if you want to keep your progress data)"
    echo "Keep database file - no (if you want to destroy your progress data and start over)"
    echo "Download exercise pack? no" | tee -a $RACHELLOG
    echo "Already downloaded? no" | tee -a $RACHELLOG
    echo "Start at boot? n" | tee -a $RACHELLOG
    echo
    $KALITEDIR/setup_unix.sh

    # Configure ka-lite
    echo; print_status "Configuring KA Lite." | tee -a $RACHELLOG
    sed -i '/CONTENT_ROOT/d' /var/ka-lite/kalite/local_settings.py 1>> $RACHELLOG 2>&1
    echo 'CONTENT_ROOT = "/media/RACHEL/kacontent/"' >> /var/ka-lite/kalite/local_settings.py

    # Setup KA Lite content
    echo; print_status "The KA Lite content needs to copied to its new home." | tee -a $RACHELLOG
    $KALITECONTENTINSTALL
    if [[ $INTERNET == "0" ]]; then cd $DIRCONTENTOFFLINE; else cd $RACHELTMPDIR; fi
    echo; print_status "Unzipping the archive to the correct folder...be patient, this takes about 45 minutes."
    if [[ -d kacontent ]]; then
        rsync -avzP ./kacontent /media/RACHEL
    elif [[ -f ka-lite_content.zip ]]; then
        unzip -u ka-lite_content.zip -d /media/RACHEL/
        mv /media/RACHEL/content /media/RACHEL/kacontent
        if [[ -d /media/RACHEL/kacontent ]]; then
            rm /media/RACHEL/ka-lite_content.zip
        else
            echo; print_error "Failed to create the /media/RACHEL/kacontent folder; check the log file for more details."
            echo "Zip file was NOT deleted and is available at /media/RACHEL/ka-lite_content.zip"
        fi
    else
        echo; print_error "KA Lite content not found."
    fi

    # Install module for RACHEL index.php
    echo; print_status "Syncing 'KA Lite module'." | tee -a $RACHELLOG
    rsync -avz --ignore-existing $RSYNCDIR/rachelmods/ka-lite $RACHELWWW/modules/
    print_good "Done." | tee -a $RACHELLOG

    # Delete previous setup commands from the /etc/rc.local
    echo; print_status "Setting up KA Lite to start at boot..." | tee -a $RACHELLOG
    sudo sed -i '/ka-lite/d' /etc/rc.local 1>> $RACHELLOG 2>&1
    sudo sed -i '/sleep 20/d' /etc/rc.local 1>> $RACHELLOG 2>&1

    # Start KA Lite at boot time
    sudo sed -i '$e echo "# Start ka-lite at boot time"' /etc/rc.local 1>> $RACHELLOG 2>&1
    sudo sed -i '$e echo "sleep 20"' /etc/rc.local 1>> $RACHELLOG 2>&1
    sudo sed -i '$e echo "/var/ka-lite/bin/kalite start"' /etc/rc.local 1>> $RACHELLOG 2>&1
    print_good "Done." | tee -a $RACHELLOG

    # Starting KA Lite
    echo; print_status "Starting KA Lite..." | tee -a $RACHELLOG
    /var/ka-lite/bin/kalite start 1>> $RACHELLOG 2>&1
    print_good "Done." | tee -a $RACHELLOG

    # Add RACHEL IP
    echo; print_good "Login using wifi at http://192.168.88.1:8008 and register device." | tee -a $RACHELLOG
    echo "After you register, click the new tab called 'Manage', then 'Videos' and download all the missing videos." | tee -a $RACHELLOG
    echo; print_good "Log file saved to: $RACHELLOGDIR/rachel-kalite-$TIMESTAMP.log" | tee -a $RACHELLOG
    print_good "KA Lite Install Complete." | tee -a $RACHELLOG
    mv $RACHELLOG $RACHELLOGDIR/rachel-kalite-$TIMESTAMP.log

    # Reboot CAP
    cleanup
    reboot-CAP
}

# Loop function to redisplay mhf
function whattodo {
    echo; print_question "What would you like to do next?"
    echo "1)New Install  2)Install Content  3)Install KA Lite  4)Install Kiwix  5)Install Sphider  6)Utilities  7)Exit"
}

## MAIN MENU
# Display current script version
echo; print_good "RACHEL CAP Configuration Script - Version $VERSION"

# Determine the operational mode - ONLINE or OFFLINE
opmode

# Change directory into $INSTALLTMPDIR
cd $INSTALLTMPDIR

echo; print_question "What you would like to do:" | tee -a $RACHELLOG
echo "  - New [Install] RACHEL on a CAP" | tee -a $RACHELLOG
echo "  - Install/Update RACHEL [Content]" | tee -a $RACHELLOG
echo "  - [Install-KA-Lite]" | tee -a $RACHELLOG
echo "  - [Install-Kiwix]" | tee -a $RACHELLOG
echo "  - [Install-Sphider]" | tee -a $RACHELLOG
echo "  - Other [Utilities]" | tee -a $RACHELLOG
echo "    - Repair an install of a CAP after a firmware upgrade" | tee -a $RACHELLOG
echo "    - Sanitize CAP for imaging" | tee -a $RACHELLOG
echo "    - Symlink all .mp4 videos in the module kaos-en to /media/RACHEL/kacontent" | tee -a $RACHELLOG
echo "    - Test script" | tee -a $RACHELLOG
echo "  - [Exit] the installation script" | tee -a $RACHELLOG
echo
select menu in "Install" "Content" "Install-KA-Lite" "Install-Kiwix" "Install-Sphider" "Utilities" "Exit"; do
        case $menu in
        Install)
        new_install
        ;;

        Content)
        content_install
        whattodo
        ;;

        Install-KA-Lite)
        ka-lite_install
        whattodo
        ;;

        Install-Kiwix)
        kiwix
        break
        ;;

        Install-Sphider)
        sphider_plus.sql
        break
        ;;

        Utilities)
        echo; print_question "What utility would you like to use?" | tee -a $RACHELLOG
        echo "  - **BETA** [Download-RACHEL] content for OFFLINE installs" | tee -a $RACHELLOG
        echo "  - [Repair] an install of a CAP after a firmware upgrade" | tee -a $RACHELLOG
        echo "  - [Sanitize] CAP for imaging" | tee -a $RACHELLOG
        echo "  - [Symlink] all .mp4 videos in the module kaos-en to /media/RACHEL/kacontent" | tee -a $RACHELLOG
        echo "  - [Test] script" | tee -a $RACHELLOG
        echo "  - Return to [Main Menu]" | tee -a $RACHELLOG
        echo
        select util in "Download-RACHEL" "Repair" "Sanitize" "Symlink" "Test" "Main-Menu"; do
            case $util in
                Download-RACHEL)
                download_offline_content
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
        echo; print_status "User requested to exit."
        echo; exit 1
        ;;
        esac
done
