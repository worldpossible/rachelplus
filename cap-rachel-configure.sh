#!/bin/sh
# FILE: cap-rachel-configure.sh
# ONELINER Download/Install: sudo wget https://raw.githubusercontent.com/rachelproject/rachelplus/master/cap-rachel-configure.sh -O /root/cap-rachel-configure.sh; bash cap-rachel-configure.sh

# For offline builds, run the Download-Offline-Content script in the Utilities menu.

# COMMON VARIABLES - Change as needed
DIRCONTENTOFFLINE="/media/nascontent/rachel-content" # Enter directory of downloaded RACHEL content for offline install (e.g. I mounted my external USB on my CAP but plugging the external USB into and running the command 'fdisk -l' to find the right drive, then 'mkdir /media/RACHEL-Content' to create a folder to mount to, then 'mount /dev/sdb1 /media/RACHEL-Content' to mount the USB drive.)
RSYNCONLINE="rsync://dev.worldpossible.org" # The current RACHEL rsync repository
WGETONLINE="http://rachelfriends.org" # RACHEL large file repo (ka-lite_content, etc)
GITRACHELPLUS="https://raw.githubusercontent.com/rachelproject/rachelplus/master" # RACHELPlus Scripts GitHub Repo
GITCONTENTSHELL="https://raw.githubusercontent.com/rachelproject/contentshell/master" # RACHELPlus ContentShell GitHub Repo

# CORE RACHEL VARIABLES - Change **ONLY** if you know what you are doing
VERSION=0821151051 # To get current version - date +%m%d%y%H%M
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
    trap ctrl_c INT
    print_header
    DOWNLOADERROR="0"
    echo; print_status "Installing RACHEL content." | tee -a $RACHELLOG
    if [[ $INTERNET == "0" ]]; then cd $DIRCONTENTOFFLINE; else cd $RACHELTMPDIR; fi

    select menu in "English-Test" "Main-Menu"; do
        case $menu in
        English-Test)
        print_status "Installing content for test." | tee -a $RACHELLOG
        wget -c $DOWNLOADCONTENTSCRIPT/en_test.lst
        command_status
        while read p; do
            echo; print_status "Downloading $p" | tee -a $RACHELLOG
            rsync -avz $RSYNCDIR/rachelmods/$p $RACHELWWW/modules/
            command_status
            print_good "Done." | tee -a $RACHELLOG
        done <en_test.lst
        break
        ;;

        Main-Menu)
        break
        ;;
        esac
    done

    # Check for errors is downloads
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
                offline_variables
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
    RACHELBRANDLOGOCAPTIVE="wget -r $GITRACHELPLUS/captive-portal/RACHELbrandLogo-captive.png -O RACHELbrandLogo-captive.png"
    HFCBRANDLOGOCAPTIVE="wget -r $GITRACHELPLUS/captive-portal/HFCbrandLogo-captive.jpg -O HFCbrandLogo-captive.jpg"
    WORLDPOSSIBLEBRANDLOGOCAPTIVE="wget -r $GITRACHELPLUS/captive-portal/WorldPossiblebrandLogo-captive.png -O WorldPossiblebrandLogo-captive.png"
    GITCLONERACHELCONTENTSHELL="git clone https://github.com/rachelproject/contentshell contentshell"
    RSYNCDIR="$RSYNCONLINE"
    ASSESSMENTITEMSJSON="wget -c $GITRACHELPLUS/assessmentitems.json -O /var/ka-lite/data/khan/assessmentitems.json"
    KALITEINSTALL="git clone https://github.com/learningequality/ka-lite /var/ka-lite"
    KALITEUPDATE="git pull"
    KALITECONTENTINSTALL="wget -c $WGETONLINE/z-holding/ka-lite_content.zip -O $RACHELTMPDIR/ka-lite_content.zip"
    KIWIXINSTALL="wget -c $WGETONLINE/z-holding/kiwix-0.9-linux-i686.tar.bz2 -O $RACHELTMPDIR/kiwix-0.9-linux-i686.tar.bz2"
    KIWIXSAMPLEDATA="wget -c $WGETONLINE/z-holding/Ray_Charles.tar.bz -O $RACHELTMPDIR/Ray_Charles.tar.bz"
    SPHIDERPLUSSQLINSTALL="wget -c $WGETONLINE/z-SQLdatabase/sphider_plus.sql -O $RACHELTMPDIR/sphider_plus.sql"
    DOWNLOADCONTENTSCRIPT="http://dev.worldpossible.org/mods/scripts"
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
    KIWIXSAMPLEDATA=""
    SPHIDERPLUSSQLINSTALL=""
    DOWNLOADCONTENTSCRIPT="$DIRCONTENTOFFLINE/rachelplus/scripts"
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
    rm -rf $INSTALLTMPDIR $RACHELTMPDIR $0
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
        rm -rf $INSTALLTMPDIR $RACHELTMPDIR
        /root/generate_recovery.sh
    fi
    echo; print_good "Done."
}

function symlink () {
    trap ctrl_c INT
    echo; print_status "Symlinking all .mp4 videos in the module 'kaos-en' to $KALITERCONTENTDIR"

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

    print_good "Done." | tee -a $RACHELLOG
}

function kiwix () {
    echo; print_status "Installing kiwix." | tee -a $RACHELLOG
    $KIWIXINSTALL
    $KIWIXSAMPLEDATA
    if [[ $INTERNET == "0" ]]; then cd $DIRCONTENTOFFLINE; else cd $RACHELTMPDIR; fi
    tar -C /var -xjvf kiwix-0.9-linux-i686.tar.bz2
    chown -R root:root /var/kiwix
    # Make content directory
    mkdir -p /media/RACHEL/kiwix
    # Download a test file
    tar -C /media/RACHEL/kiwix -xjvf Ray_Charles.tar.bz
    cp /media/RACHEL/kiwix/data/library/wikipedia_en_ray_charles_2015-06.zim.xml  /media/RACHEL/kiwix/data/library/library.xml
    rm Ray_Charles.tar.bz
    # Start up Kiwix
    echo; print_status "Starting Kiwix server." | tee -a $RACHELLOG
    /var/kiwix/bin/kiwix-serve --daemon --port=81 --library /media/RACHEL/kiwix/data/library/library.xml 1>> $RACHELLOG 2>&1
    echo; print_status "Setting Kiwix to start on boot." | tee -a $RACHELLOG
    # Remove old kiwix boot lines from /etc/rc.local
    sed -i '/kiwix/d' /etc/rc.local 1>> $RACHELLOG 2>&1
    # Clean up current rachel-scripts.sh file
    sed -i '/kiwix/d' $RACHELSCRIPTSFILE 1>> $RACHELLOG 2>&1
    # Add lines to /etc/rc.local that will start kiwix on boot
    sed -i '$e echo "\# Start kiwix on boot"' $RACHELSCRIPTSFILE 1>> $RACHELLOG 2>&1
    sed -i '$e echo "bash \/var\/kiwix\/bin\/kiwix-serve --daemon --port=81 --library \/media\/RACHEL\/kiwix\/data\/library\/library.xml"' $RACHELSCRIPTSFILE 1>> $RACHELLOG 2>&1
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

    echo; print_status "Downloading/updating kiwix and sample data." | tee -a $RACHELLOG
    wget -c $WGETONLINE/z-holding/kiwix-0.9-linux-i686.tar.bz2 -O $DIRCONTENTOFFLINE/kiwix-0.9-linux-i686.tar.bz2
    wget -c $WGETONLINE/z-holding/Ray_Charles.tar.bz -O $DIRCONTENTOFFLINE/Ray_Charles.tar.bz
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

    # Download RACHEL Captive Portal files
    echo; print_status "Downloading Captive Portal content to $INSTALLTMPDIR." | tee -a $RACHELLOG

    echo; print_status "Downloading captiveportal-redirect.php." | tee -a $RACHELLOG
    $CAPTIVEPORTALREDIRECT 1>> $RACHELLOG 2>&1
    command_status

    echo; print_status "Downloading RACHELbrandLogo-captive.png." | tee -a $RACHELLOG
    $RACHELBRANDLOGOCAPTIVE 1>> $RACHELLOG 2>&1
    command_status
    
    echo; print_status "Downloading HFCbrandLogo-captive.jpg." | tee -a $RACHELLOG
    $HFCBRANDLOGOCAPTIVE 1>> $RACHELLOG 2>&1
    command_status
    
    echo; print_status "Downloading WorldPossiblebrandLogo-captive.png." | tee -a $RACHELLOG
    $WORLDPOSSIBLEBRANDLOGOCAPTIVE 1>> $RACHELLOG 2>&1
    command_status

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
        if [[ $INTERNET == "0" ]]; then cd $DIRCONTENTOFFLINE; else cd $INSTALLTMPDIR; fi
        echo; print_status "Checking for pre-existing RACHEL content shell." | tee -a $RACHELLOG
        if [[ ! -d $RACHELWWW ]]; then
            echo; print_status "RACHEL content shell does not exist at $RACHELWWW." | tee -a $RACHELLOG
            echo; print_status "Cloning the RACHEL content shell from GitHub." | tee -a $RACHELLOG
            $GITCLONERACHELCONTENTSHELL
        else
            if [[ ! -d $RACHELWWW/.git ]]; then
                echo; print_status "$RACHELWWW exists but it wasn't installed from git; installing RACHEL content shell from GitHub." | tee -a $RACHELLOG
                rm -rf contentshell 1>> $RACHELLOG 2>&1 # in case of previous failed install
                $GITCLONERACHELCONTENTSHELL
                cp -rf contentshell/* $RACHELWWW/ 1>> $RACHELLOG 2>&1 # overwrite current content with contentshell
                cp -rf contentshell/.git $RACHELWWW/ 1>> $RACHELLOG 2>&1 # copy over GitHub files
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
    cd $INSTALLTMPDIR

    # Download/update to latest RACHEL lighttpd.conf
    echo; print_status "Downloading latest lighttpd.conf" | tee -a $RACHELLOG
    ## lighttpd.conf - RACHEL version (I don't overwrite at this time due to other dependencies and ensuring the file downloads correctly)
    $LIGHTTPDFILE 1>> $RACHELLOG 2>&1
    command_status
    if [[ $DOWNLOADERROR == 1 ]]; then
        print_error "The lighttpd.conf file did not download correctly; check log file (/var/log/RACHEL/rachel-install.tmp) and try again." | tee -a $RACHELLOG
        echo; break
    else
        mv $INSTALLTMPDIR/lighttpd.conf /usr/local/etc/lighttpd.conf
    fi
    print_good "Done." | tee -a $RACHELLOG

    # Reapply /etc/fstab entry for /media/RACHEL
    echo; print_status "Adding /dev/sda3 into /etc/fstab" | tee -a $RACHELLOG
    sed -i '/\/dev\/sda3/d' /etc/fstab
    echo -e "/dev/sda3\t/media/RACHEL\t\text4\tauto,nobootwait 0\t0" >> /etc/fstab
    print_good "Done." | tee -a $RACHELLOG

    # Fixing /root/rachel-scripts.sh
    echo; print_status "Fixing $RACHELSCRIPTSFILE" | tee -a $RACHELLOG

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
        echo; print_status "Setting up Kiwix to start at boot..." | tee -a $RACHELLOG
        # Remove old kiwix boot lines from /etc/rc.local
        sed -i '/kiwix/d' /etc/rc.local 1>> $RACHELLOG 2>&1
        # Clean up current rachel-scripts.sh file
        sed -i '/kiwix/d' $RACHELSCRIPTSFILE 1>> $RACHELLOG 2>&1
        # Add lines to /etc/rc.local that will start kiwix on boot
        sed -i '$e echo "\# Start kiwix on boot"' $RACHELSCRIPTSFILE 1>> $RACHELLOG 2>&1
        sed -i '$e echo "bash \/var\/kiwix\/bin\/kiwix-serve --daemon --port=81 --library \/media\/RACHEL\/kiwix\/data\/library\/library.xml"' $RACHELSCRIPTSFILE 1>> $RACHELLOG 2>&1
        print_good "Done." | tee -a $RACHELLOG
    fi

    if [[ -d /var/ka-lite ]]; then
        echo; print_status "Setting up KA Lite to start at boot..." | tee -a $RACHELLOG
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
        print_good "Done." | tee -a $RACHELLOG
    fi

    # Clean up outdated stuff
    # Remove outdated startup script
    rm -f /root/iptables-rachel.sh

    # Delete previous setwanip commands from /etc/rc.local - not used anymore
    echo; print_status "Deleting previous setwanip.sh script from /etc/rc.local" | tee -a $RACHELLOG
    sed -i '/setwanip/d' /etc/rc.local
    rm -f /root/setwanip.sh
    print_good "Done." | tee -a $RACHELLOG

    # Delete previous iptables commands from /etc/rc.local
    echo; print_status "Deleting previous iptables script from /etc/rc.local" | tee -a $RACHELLOG
    sed -i '/iptables/d' /etc/rc.local
    print_good "Done." | tee -a $RACHELLOG

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
    if [[ $INTERNET == "0" ]]; then cd $DIRCONTENTOFFLINE; else cd $RACHELTMPDIR; fi

    # Add header/date/time to install log file
    echo; print_error "CAUTION:  This process may take quite awhile if you do you not have a fast network connection." | tee -a $RACHELLOG
    echo "If you get disconnected, you only have to rerun this install again to continue.  It will not re-download content already on the CAP." | tee -a $RACHELLOG

    # Check permissions on modules
    echo; print_status "Verifying proper permissions on modules prior to install." | tee -a $RACHELLOG
    chown -R root:root $RACHELWWW/modules
    print_good "Done." | tee -a $RACHELLOG

    # Export the RSYNCDIR variable so other scripts can use it
#    export $RSYNCDIR


## INSERT CONTENT FIX HERE

    # import file
    # for loop

    echo; print_question "What content you would like to install:" | tee -a $RACHELLOG
    echo "  - [English-KA] - English content based on KA" | tee -a $RACHELLOG
    echo "  - [English-Kaos] - English content based on Kaos" | tee -a $RACHELLOG
    echo "  - [English-Justice] - English content for Justice" | tee -a $RACHELLOG
    echo "  - Exit to the [Main Menu]" | tee -a $RACHELLOG
    echo
    select menu in "English-KALite" "English-Kaos" "English-Justice" "Español" "Français" "Português" "Hindi" "Main-Menu"; do
        case $menu in
        English-KALite)
        print_status "Installing content for English (KA Lite)." | tee -a $RACHELLOG
        wget -c $DOWNLOADCONTENTSCRIPT/en_all_kalite.lst
        command_status
        while read p; do
            echo; print_status "Downloading $p" | tee -a $RACHELLOG
            rsync -avz $RSYNCDIR/rachelmods/$p $RACHELWWW/modules/
            command_status
            print_good "Done." | tee -a $RACHELLOG
        done <en_all_kalite.lst
        break
        ;;

        English-Kaos)
        print_status "Installing content for English (KA Lite)." | tee -a $RACHELLOG
        wget -c $DOWNLOADCONTENTSCRIPT/en_all_kaos.lst
        command_status
        while read p; do
            echo; print_status "Downloading $p" | tee -a $RACHELLOG
            rsync -avz $RSYNCDIR/rachelmods/$p $RACHELWWW/modules/
            command_status
            print_good "Done." | tee -a $RACHELLOG
        done <en_all_kaos.lst
        break
        ;;

        English-Justice)
        print_status "Installing content for English (Justice)." | tee -a $RACHELLOG
        wget -c $DOWNLOADCONTENTSCRIPT/en_justice.lst
        command_status
        while read p; do
            echo; print_status "Downloading $p" | tee -a $RACHELLOG
            rsync -avz $RSYNCDIR/rachelmods/$p $RACHELWWW/modules/
            command_status
            print_good "Done." | tee -a $RACHELLOG
        done <en_justice.lst
        break
        ;;

        Español)
        print_status "Installing content for Español." | tee -a $RACHELLOG
        wget -c $DOWNLOADCONTENTSCRIPT/es_all_kaos.lst
        command_status
        while read p; do
            echo; print_status "Downloading $p" | tee -a $RACHELLOG
            rsync -avz $RSYNCDIR/rachelmods/$p $RACHELWWW/modules/
            command_status
            print_good "Done." | tee -a $RACHELLOG
        done <es_all_kaos.lst
        break
        ;;

        Français)
        print_status "Installing content for Français." | tee -a $RACHELLOG
        wget -c $DOWNLOADCONTENTSCRIPT/fr_all_kaos.lst
        command_status
        while read p; do
            echo; print_status "Downloading $p" | tee -a $RACHELLOG
            rsync -avz $RSYNCDIR/rachelmods/$p $RACHELWWW/modules/
            command_status
            print_good "Done." | tee -a $RACHELLOG
        done <fr_all_kaos.lst
        break
        ;;

        Português)
        print_status "Installing content for Português." | tee -a $RACHELLOG
        wget -c $DOWNLOADCONTENTSCRIPT/pt_all_kaos.lst
        command_status
        while read p; do
            echo; print_status "Downloading $p" | tee -a $RACHELLOG
            rsync -avz $RSYNCDIR/rachelmods/$p $RACHELWWW/modules/
            command_status
            print_good "Done." | tee -a $RACHELLOG
        done <pt_all_kaos.lst
        break
        ;;

        Hindi)
        print_status "Installing content for Hindi." | tee -a $RACHELLOG
        wget -c $DOWNLOADCONTENTSCRIPT/hi_all.lst
        command_status
        while read p; do
            echo; print_status "Downloading $p" | tee -a $RACHELLOG
            rsync -avz $RSYNCDIR/rachelmods/$p $RACHELWWW/modules/
            command_status
            print_good "Done." | tee -a $RACHELLOG
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
        echo; print_error "One or more of the updates did not download correctly; for more information, check the log file ($RACHELLOG)." | tee -a $RACHELLOG
    fi

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
    echo "1)New Install  2)Install KA Lite  3)Install Kiwix  4)Install Sphider  5)Install Content  6)Utilities  7)Exit"
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
echo "  - [Install-KA-Lite]" | tee -a $RACHELLOG
echo "  - [Install-Kiwix]" | tee -a $RACHELLOG
echo "  - [Install-Sphider]" | tee -a $RACHELLOG
echo "  - Install/Update RACHEL [Content]" | tee -a $RACHELLOG
echo "  - Other [Utilities]" | tee -a $RACHELLOG
echo "    - Repair an install of a CAP after a firmware upgrade" | tee -a $RACHELLOG
echo "    - Sanitize CAP for imaging" | tee -a $RACHELLOG
echo "    - Symlink all .mp4 videos in the module kaos-en to /media/RACHEL/kacontent" | tee -a $RACHELLOG
echo "    - Test script" | tee -a $RACHELLOG
echo "  - [Exit] the installation script" | tee -a $RACHELLOG
echo
select menu in "Install" "Install-KA-Lite" "Install-Kiwix" "Install-Sphider" "Content" "Utilities" "Exit"; do
        case $menu in
        Install)
        new_install
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

        Content)
        content_install
        whattodo
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
