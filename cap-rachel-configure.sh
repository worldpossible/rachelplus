#!/bin/sh
# FILE: cap-rachel-configure.sh
# ONELINER Download/Install: sudo wget https://raw.githubusercontent.com/rachelproject/rachelplus/master/cap-rachel-configure.sh -O /root/cap-rachel-configure.sh; bash cap-rachel-configure.sh

# Everything below will go to this log directory
VERSION=0724150931 # To get current version - date +%m%d%y%H%M
TIMESTAMP=$(date +"%b-%d-%Y-%H%M%Z")
RACHELLOGDIR="/var/log/RACHEL"
mkdir -p $RACHELLOGDIR
RACHELLOGFILE="rachel-install.tmp"
RACHELLOG="$RACHELLOGDIR/$RACHELLOGFILE"
RACHELWWW="/media/RACHEL/rachel"
KALITEDIR="/var/ka-lite"
INSTALLTMPDIR="/root/cap-rachel-install.tmp"
mkdir -p $INSTALLTMPDIR

FILE2="/root/cap-rachel-first-install-2.sh"
FILE3="/root/cap-rachel-first-install-3.sh"
LIGHTTPDFILE="/root/lighttpd.conf"

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

# Check root
if [ "$(id -u)" != "0" ]; then
    print_error "This step must be run as root; sudo password is 123lkj"
    exit 1
fi

# Add header/date/time to install log file
echo; print_good "RACHEL CAP Configuration Script - Version $VERSION" | tee $RACHELLOG
print_good "Script started: $(date)" | tee -a $RACHELLOG

# Check internet connecivity
WGET=`which wget`
$WGET -q --tries=10 --timeout=5 --spider http://google.com 1>> $RACHELLOG 2>&1
if [[ $? -eq 0 ]]; then
    echo; print_good "Internet connected...continuing install." | tee -a $RACHELLOG
else
    echo; print_error "No internet connectivity; waiting 30 seconds and then I will try again." | tee -a $RACHELLOG
    # Progress bar to visualize wait period
    while true;do echo -n .;sleep 1;done & 
    sleep 30
    kill $!; trap 'kill $!' SIGTERM
    $WGET -q --tries=10 --timeout=5 --spider http://google.com
    if [[ $? -eq 0 ]]; then
        echo; print_good "Internet connected...continuing install." | tee -a $RACHELLOG
    else
        echo; print_error "No internet connectivity; connect to the internet and try again." | tee -a $RACHELLOG
        exit 1
    fi
fi

# Change directory into $INSTALLTMPDIR
cd $INSTALLTMPDIR

function reboot-CAP () {
    echo; print_status "I need to reboot; new installs will reboot twice more automatically." | tee -a $RACHELLOG
    echo; print_status "The file, $RACHELLOG, will be renamed to a dated log file when the script is complete." | tee -a $RACHELLOG
    print_status "Rebooting in 10 seconds..." | tee -a $RACHELLOG
    # Progress bar to visualize wait period
    while true;do echo -n .;sleep 1;done & 
    sleep 10
    kill $!; trap 'kill $!' SIGTERM
    reboot 1>> $RACHELLOG 2>&1
}

function cleanup () {
    # Deleting the install script commands
    echo; print_status "Deleting the install scripts." | tee -a $RACHELLOG
    rm -rf /root/cap-rachel-* 1>> $RACHELLOG 2>&1
    print_good "Done." | tee -a $RACHELLOG
}

function new_install () {
    echo; print_status "Conducting a new install of RACHEL on a CAP."

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
    select class in "US" "UK" "SG" "CN"; do
        case $class in
        # US
        US)
            echo; print_status "Downloading packages from the United States." | tee -a $RACHELLOG
            wget https://raw.githubusercontent.com/rachelproject/rachelplus/master/sources.list/sources-us.list -O /etc/apt/sources.list 1>> $RACHELLOG 2>&1
        ;;

        # UK
        UK)
            echo; print_status "Downloading packages from the United Kingdom." | tee -a $RACHELLOG
            wget https://raw.githubusercontent.com/rachelproject/rachelplus/master/sources.list/sources-uk.list -O /etc/apt/sources.list 1>> $RACHELLOG 2>&1
        ;;

        # Singapore
        SG)
            echo; print_status "Downloading packages from Singapore." | tee -a $RACHELLOG
            wget https://raw.githubusercontent.com/rachelproject/rachelplus/master/sources.list/sources-sg.list -O /etc/apt/sources.list 1>> $RACHELLOG 2>&1
        ;;

        # China (Original)
        CN)
            echo; print_status "Downloading packages from the China - CAP manufacturer's website." | tee -a $RACHELLOG
            wget https://raw.githubusercontent.com/rachelproject/rachelplus/master/sources.list/sources-sohu.list -O /etc/apt/sources.list 1>> $RACHELLOG 2>&1
        ;;
        esac
        print_good "Done." | tee -a $RACHELLOG
        break
    done

    # Download/stage GitHub files to $INSTALLTMPDIR
    echo; print_status "Downloading RACHEL install scripts for CAP to the temp folder $INSTALLTMPDIR." | tee -a $RACHELLOG
    ## cap-rachel-first-install-2.sh
    wget https://raw.githubusercontent.com/rachelproject/rachelplus/master/install/cap-rachel-first-install-2.sh -O /root/cap-rachel-first-install-2.sh 1>> $RACHELLOG 2>&1
    ## cap-rachel-first-install-3.sh
    wget https://raw.githubusercontent.com/rachelproject/rachelplus/master/install/cap-rachel-first-install-3.sh -O /root/cap-rachel-first-install-3.sh 1>> $RACHELLOG 2>&1
    ## lighttpd.conf - RACHEL version (I don't overwrite at this time due to other dependencies)
    wget https://raw.githubusercontent.com/rachelproject/rachelplus/master/lighttpd.conf -O /root/lighttpd.conf 1>> $RACHELLOG 2>&1
    if [[ -s $FILE2 && -s $FILE3 && -s $LIGHTTPDFILE ]]  1>> $RACHELLOG 2>&1; then
        print_good "Done." | tee -a $RACHELLOG
    else
        print_error "One or more files did not download correctly; check log file (/var/log/RACHEL/rachel-install.tmp) and try again." | tee -a $RACHELLOG
        echo "The following files should have downloaded to the /root folder:" | tee -a $RACHELLOG
        echo "cap-rachel-first-install-2.sh" | tee -a $RACHELLOG
        echo "cap-rachel-first-install-3.sh" | tee -a $RACHELLOG
        echo "lighttpd.conf" | tee -a $RACHELLOG
        echo; exit 1
    fi

    # RACHEL Captive Portal file download
    echo; print_status "Downloading Captive Portal content and moving a copy files." | tee -a $RACHELLOG
    wget https://raw.githubusercontent.com/rachelproject/rachelplus/master/captive-portal/captiveportal-redirect.php 1>> $RACHELLOG 2>&1
    print_good "Downloaded captiveportal-redirect.php." | tee -a $RACHELLOG
    if [[ ! -f $RACHELWWW/art/RACHELbrandLogo-captive.png ]]; then
        wget https://raw.githubusercontent.com/rachelproject/rachelplus/master/captive-portal/RACHELbrandLogo-captive.png 1>> $RACHELLOG 2>&1
        print_good "Downloaded RACHELbrandLogo-captive.png." | tee -a $RACHELLOG
    else
        print_good "$RACHELWWW/art/RACHELbrandLogo-captive.png exists, skipping." | tee -a $RACHELLOG
    fi
    if [[ ! -f $RACHELWWW/art/HFCbrandLogo-captive.jpg ]]; then
        wget https://raw.githubusercontent.com/rachelproject/rachelplus/master/captive-portal/HFCbrandLogo-captive.jpg 1>> $RACHELLOG 2>&1
        print_good "Downloaded HFCbrandLogo-captive.jpg." | tee -a $RACHELLOG
    else
        print_good "$RACHELWWW/art/HFCbrandLogo-captive.jpg exists, skipping." | tee -a $RACHELLOG
    fi
    if [[ ! -f $RACHELWWW/art/WorldPossiblebrandLogo-captive.png ]]; then
        wget https://raw.githubusercontent.com/rachelproject/rachelplus/master/captive-portal/WorldPossiblebrandLogo-captive.png 1>> $RACHELLOG 2>&1
        print_good "Downloaded WorldPossiblebrandLogo-captive.png." | tee -a $RACHELLOG
    else
        print_good "$RACHELWWW/art/WorldPossiblebrandLogo-captive.png exists, skipping." | tee -a $RACHELLOG
    fi

    # Clone or update the RACHEL content shell from GitHub
    echo; print_status "Checking for pre-existing RACHEL content." | tee -a $RACHELLOG
    if [[ ! -d $RACHELWWW ]]; then
        echo; print_status "RACHEL content does not exist at $RACHELWWW." | tee -a $RACHELLOG
        echo; print_status "Cloning the RACHEL content shell from GitHub." | tee -a $RACHELLOG
        git clone https://github.com/rachelproject/contentshell $INSTALLTMPDIR/contentshell 1>> $RACHELLOG 2>&1
    else
        if [[ ! -d $RACHELWWW/.git ]]; then
            echo; print_status "$RACHELWWW exists but it wasn't installed from git; installing RACHEL content shell from GitHub." | tee -a $RACHELLOG
            rm -rf /media/RACHEL/rachel.contentshell 1>> $RACHELLOG 2>&1 # in case of previous failed install
            git clone https://github.com/rachelproject/contentshell /media/RACHEL/rachel.contentshell 1>> $RACHELLOG 2>&1
            cp -rf /media/RACHEL/rachel.contentshell/* /media/RACHEL/rachel 1>> $RACHELLOG 2>&1 # overwrite current content with contentshell
            cp -rf /media/RACHEL/rachel.contentshell/.git /media/RACHEL/rachel/ 1>> $RACHELLOG 2>&1 # copy over GitHub files
            rm -rf /media/RACHEL/rachel.contentshell 1>> $RACHELLOG 2>&1 # remove contentshell temp folder
        else
            echo; print_status "$RACHELWWW exists; updating RACHEL content shell from GitHub." | tee -a $RACHELLOG
            cd $RACHELWWW; git pull 1>> $RACHELLOG 2>&1
        fi
    fi
    print_good "Done." | tee -a $RACHELLOG

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
        apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 16126D3A3E5C1192
        apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 40976EAF437D05B5
        apt-get clean; apt-get purge; apt-get update
        print_good "Done."

        # Install packages
        echo; print_status "Installing PHP" | tee -a $RACHELLOG
        apt-get -y install php5-cgi git-core python-m2crypto 1>> $RACHELLOG 2>&1
        # Add the following line at the end of file
        echo "cgi.fix_pathinfo = 1" >> /etc/php5/cgi/php.ini
        print_good "Done." | tee -a $RACHELLOG

        # Install MySQL client and server
        echo; print_status "Installing mysql client and server" | tee -a $RACHELLOG
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
        mv /root/lighttpd.conf /usr/local/etc/lighttpd.conf 1>> $RACHELLOG 2>&1
        print_good "Done." | tee -a $RACHELLOG
        
        # Check if /media/RACHEL/rachel is already mounted
        if grep -qs '/media/RACHEL' /proc/mounts; then
            echo; print_status "This hard drive is already partitioned for RACHEL, skipping hard drive repartitioning." | tee -a $RACHELLOG
            echo; print_good "RACHEL CAP Install - Script ended at $(date)" | tee -a $RACHELLOG
            echo; print_good "RACHEL CAP Install - Script 2 skipped (hard drive repartitioning) at $(date)" | tee -a $RACHELLOG
            bash /root/cap-rachel-first-install-3.sh
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
            sudo sed -i '$e echo "bash \/root\/cap-rachel-first-install-2.sh&"' /etc/rc.local 1>> $RACHELLOG 2>&1

            echo; print_good "RACHEL CAP Install - Script ended at $(date)" | tee -a $RACHELLOG
            reboot-CAP
        fi
    else
        echo; print_error "User requests not to continue...exiting at $(date)" | tee -a $RACHELLOG
        # Deleting the install script commands
        rm -f /root/cap-rachel-* $RACHELLOG 1>> $RACHELLOG 2>&1
        echo; exit 1
    fi
}

function repair () {
    echo; print_status "Repairing your CAP after a firmware upgrade."
    # Download/update to latest RACHEL lighttpd.conf
    echo; print_status "Downloading latest lighttpd.conf" | tee -a $RACHELLOG
    ## lighttpd.conf - RACHEL version (I don't overwrite at this time due to other dependencies)
    sudo wget https://raw.githubusercontent.com/rachelproject/rachelplus/master/lighttpd.conf -O /usr/local/etc/lighttpd.conf 1>> $RACHELLOG 2>&1
    print_good "Done." | tee -a $RACHELLOG

    # Reapply /etc/fstab entry for /media/RACHEL
    echo; print_status "Adding /dev/sda3 into /etc/fstab" | tee -a $RACHELLOG
    sed -i '/\/dev\/sda3/d' /etc/fstab
    echo -e "/dev/sda3\t/media/RACHEL\t\text4\tauto,nobootwait 0\t0" >> /etc/fstab
    print_good "Done." | tee -a $RACHELLOG

    sudo mv $RACHELLOG $RACHELLOGDIR/rachel-repair-$TIMESTAMP.log
    echo; print_good "Log file saved to: $RACHELLOGDIR/rachel-repair-$TIMESTAMP.log" | tee -a $RACHELLOG
    print_good "RACHEL CAP Repair Complete." | tee -a $RACHELLOG
    cleanup
    reboot-CAP
}

function ka-lite_install () {
    # Add header/date/time to install log file
    echo; print_good "KA Lite Install Script - Version $(date +%m%d%y%H%M)" | tee -a $RACHELLOG
    print_good "Install started: $(date)" | tee -a $RACHELLOG

    # Let's install KA Lite under /var 
    if [[ ! -d $KALITEDIR ]]; then
      echo; print_status "Cloning KA Lite from GitHub." | tee -a $RACHELLOG
      git clone --recursive https://github.com/learningequality/ka-lite.git /var/ka-lite 1>> $RACHELLOG 2>&1
    else
      echo; print_status "KA Lite already exists; updating files." | tee -a $RACHELLOG
      cd $KALITEDIR; git pull 1>> $RACHELLOG 2>&1
    fi
    print_good "Done." | tee -a $RACHELLOG

    # Download/install assessmentitems.json
    echo; print_status "Downloading latest assessmentitems.json from GitHub." | tee -a $RACHELLOG
    wget -c https://raw.githubusercontent.com/rachelproject/rachelplus/master/ka-lite/assessmentitems.json -O /var/ka-lite/data/khan/assessmentitems.json
    print_good "Done." | tee -a $RACHELLOG

    # Linux setup of KA Lite
    echo; print_status "Use the following inputs when answering the setup questions:" | tee -a $RACHELLOG
    echo "For previous installs:"
    echo "Keep database file - yes (if you want to keep your progress data)"
    echo "Keep database file - no (if you want to destroy your progress data and start over)"
    echo; echo "For new/previous installs:"
    echo "User - rachel"  | tee -a $RACHELLOG
    echo "Password (x2) - rachel" | tee -a $RACHELLOG
    echo "Name and describe server as desired" | tee -a $RACHELLOG
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
    echo; print_question "The KA Lite content needs to copied to its new home." | tee -a $RACHELLOG
    echo "Answer (n) to the next question if you have the content on disk or do not wish to download at this time." | tee -a $RACHELLOG
    echo; read -p "Would you like to download the KA Lite content from rachelfriends.org? (y/n) " -r <&1
    if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
        echo; print_status "Downloading ka-lite_content.zip into /media/RACHEL folder."
        wget -c http://rachelfriends.org/z-holding/ka-lite_content.zip -O /media/RACHEL/ka-lite_content.zip
        unzip -u /media/RACHEL/ka-lite_content.zip -d /media/RACHEL/ 1>> $RACHELLOG 2>&1
        mv /media/RACHEL/content /media/RACHEL/kacontent 1>> $RACHELLOG 2>&1
    else
        echo; read -p "Do you have the ka-lite_content.zip file already downloaded? (y/n) " -r <&1
        if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then
            echo; echo "[?] What is the full path of the ka-lite_content.zip file (eg /media/RACHEL/ka-lite_content.zip)? "; read KALITECONTENT
            echo "Copying content from $KALITECONTENT to $KALITEDIR." | tee -a $RACHELLOG
            unzip -c $KALITECONTENT -d /media/RACHEL/ 1>> $RACHELLOG 2>&1
        else
            echo; print_error "You can download the content folder to $KALITEDIR at a later time." | tee -a $RACHELLOG
            print_error "Not installing the KA Lite content; moving on." | tee -a $RACHELLOG
        fi
    fi

    # Delete previous setup commands from the /etc/rc.local
    sudo sed -i '/ka-lite/d' /etc/rc.local 1>> $RACHELLOG 2>&1
    sudo sed -i '/sleep 20/d' /etc/rc.local 1>> $RACHELLOG 2>&1

    # Start KA Lite at boot time
    sudo sed -i '$e echo "# Start ka-lite at boot time"' /etc/rc.local 1>> $RACHELLOG 2>&1
    sudo sed -i '$e echo "sleep 20"' /etc/rc.local 1>> $RACHELLOG 2>&1
    sudo sed -i '$e echo "/var/ka-lite/bin/kalite start"' /etc/rc.local 1>> $RACHELLOG 2>&1
    print_good "Done." | tee -a $RACHELLOG

    # Starting KA Lite
    /var/ka-lite/bin/kalite start 1>> $RACHELLOG 2>&1

    # Add RACHEL IP
    echo; print_good "Login using wifi at http://192.168.88.1:8008 and register device." | tee -a $RACHELLOG
    mv $RACHELLOG $RACHELLOGDIR/rachel-kalite-$TIMESTAMP.log
    echo; print_good "Log file saved to: $RACHELLOGDIR/rachel-kalite-$TIMESTAMP.log" | tee -a $RACHELLOG
    print_good "KA Lite Install Complete." | tee -a $RACHELLOG

    # Reboot CAP
    cleanup
    reboot-CAP
}

# Loop function to redisplay menu
function whattodo {
    echo; echo "[?] What would you like to do next?"
    echo "1)New Install  2)Repair Install  3)Install KA Lite  4)Exit"
}

## MAIN MENU
echo; print_question "What you would like to do:" | tee -a $RACHELLOG
echo "  - New [Install] RACHEL on a CAP" | tee -a $RACHELLOG
echo "  - [Repair] an install of a CAP after a firmware upgrade" | tee -a $RACHELLOG
echo "  - Install [KA-Lite]" | tee -a $RACHELLOG
echo "  - [Exit] the installation script" | tee -a $RACHELLOG
echo
select menu in "Install" "Repair" "KA-Lite" "Exit"; do
        case $menu in
        Install)
        new_install
        whattodo
        ;;

        Repair)
        repair
        whattodo
        ;;

        KA-Lite)
        ka-lite_install
        whattodo
        ;;

        Exit)
        cleanup
        echo; print_status "User requested to exit."
        echo; exit 1
        ;;
        esac
done
