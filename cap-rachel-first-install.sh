#!/bin/sh
# FILE: cap-rachel-first-install.sh
# ONELINER Download/Install: sudo wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-first-install.sh -O /root/cap-rachel-first-install.sh; bash cap-rachel-first-install.sh

# Everything below will go to this log directory
TIMESTAMP=$(date +"%b-%d-%Y-%H%M%Z")
RACHELLOGDIR="/var/log/RACHEL"
mkdir -p $RACHELLOGDIR
RACHELLOGFILE="rachel-install.tmp"
RACHELLOG="$RACHELLOGDIR/$RACHELLOGFILE"

FILE1="/root/cap-rachel-first-install-1.sh"
FILE2="/root/cap-rachel-first-install-2.sh"
FILE3="/root/cap-rachel-first-install-3.sh"
SETWANIPFILE="/root/cap-rachel-setwanip-install.sh"
LIGHTTPDFILE="/root/lighttpd.conf"
SOURCESLIST="/root/sources.list"

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

# Check internet connecivity
WGET=`which wget`
$WGET -q --tries=10 --timeout=5 --spider http://google.com 1>> $RACHELLOG 2>&1
if [[ $? -eq 0 ]]; then
    echo; print_good "Internet connected...continuing install." | tee -a $RACHELLOG
else
    echo; print_error "No internet connectivity; connect to the internet and try again."
    exit 1
fi

# Add header/date/time to install log file
echo; print_good "RACHEL CAP Install/Repair Script - Version $(date +%m%d%y%H%M)" | tee $RACHELLOG
print_good "Install/repair started: $(date)" | tee -a $RACHELLOG

function new_install () {
    # Fix hostname issue in /etc/hosts
    echo; print_status "Fixing hostname in /etc/hosts" | tee -a $RACHELLOG
    sed -i 's/ec-server/WRTD-303N-Server/g' /etc/hosts 1>> $RACHELLOG 2>&1
    print_good "Done." | tee -a $RACHELLOG

    # Delete previous setup commands from the /etc/rc.local
    echo; print_status "Delete previous RACHEL setup commands from /etc/rc.local" | tee -a $RACHELLOG
    sudo sed -i '/cap-rachel/d' /etc/rc.local 1>> $RACHELLOG 2>&1
    print_good "Done." | tee -a $RACHELLOG

    ## sources.list - replace the package repos for more reliable ones (/etc/apt/sources.list)
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
                    sudo wget https://github.com/rachelproject/rachelplus/raw/master/sources.list/sources-us.list -O $SOURCESLIST 1>> $RACHELLOG 2>&1
                    print_good "Done." | tee -a $RACHELLOG
                    break
            ;;

            # UK
            UK)
                    echo; print_status "Downloading packages from the United Kingdom." | tee -a $RACHELLOG
                    sudo wget https://github.com/rachelproject/rachelplus/raw/master/sources.list/sources-uk.list -O $SOURCESLIST 1>> $RACHELLOG 2>&1
                    print_good "Done." | tee -a $RACHELLOG
                    break
            ;;

            # Singapore
            SG)
                    echo; print_status "Downloading packages from Singapore." | tee -a $RACHELLOG
                    sudo wget https://github.com/rachelproject/rachelplus/raw/master/sources.list/sources-sg.list -O $SOURCESLIST 1>> $RACHELLOG 2>&1
                    print_good "Done." | tee -a $RACHELLOG
                    break
            ;;

            # China (Original)
            CN)
                    echo; print_status "Downloading packages from the China - CAP manufacturer's website." | tee -a $RACHELLOG
                    sudo wget https://github.com/rachelproject/rachelplus/raw/master/sources.list/sources-sohu.list -O $SOURCESLIST 1>> $RACHELLOG 2>&1
                    print_good "Done." | tee -a $RACHELLOG
                    break
            ;;
            esac
    done

    # Download additional scripts to /root
    echo; print_status "Downloading RACHEL install scripts for CAP" | tee -a $RACHELLOG
    ## cap-rachel-first-install-1.sh
    sudo wget https://github.com/rachelproject/rachelplus/raw/master/install/cap-rachel-first-install-1.sh -O $FILE1 1>> $RACHELLOG 2>&1
    ## cap-rachel-first-install-2.sh
    sudo wget https://github.com/rachelproject/rachelplus/raw/master/install/cap-rachel-first-install-2.sh -O $FILE2 1>> $RACHELLOG 2>&1
    ## cap-rachel-first-install-3.sh
    sudo wget https://github.com/rachelproject/rachelplus/raw/master/install/cap-rachel-first-install-3.sh -O $FILE3 1>> $RACHELLOG 2>&1
    ## lighttpd.conf - RACHEL version (I don't overwrite at this time due to other dependencies)
    sudo wget https://github.com/rachelproject/rachelplus/raw/master/lighttpd.conf -O $LIGHTTPDFILE 1>> $RACHELLOG 2>&1
    if [[ -s $FILE1 && -s $FILE2 && -s $FILE3 && -s $LIGHTTPDFILE && -s $SOURCESLIST ]]  1>> $RACHELLOG 2>&1; then
        print_good "Done." | tee -a $RACHELLOG
    else
        print_error "One or more files did not download correctly; check log file (/var/log/RACHEL/rachel-install.tmp) and try again." | tee -a $RACHELLOG
        echo "The following files should have downloaded to /root:" | tee -a $RACHELLOG
        echo "cap-rachel-first-install-1.sh" | tee -a $RACHELLOG
        echo "cap-rachel-first-install-2.sh" | tee -a $RACHELLOG
        echo "cap-rachel-first-install-3.sh" | tee -a $RACHELLOG
        echo "lighttpd.conf" | tee -a $RACHELLOG
        echo "sources.list" | tee -a $RACHELLOG
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
        bash /root/cap-rachel-first-install-1.sh
    else
        echo; print_error "User requests not to continue...exiting at $(date)" | tee -a $RACHELLOG
        # Deleting the install script commands
        rm -f /root/cap-rachel-* $RACHELLOG 1>> $RACHELLOG 2>&1
        echo; exit 1
    fi
}

function repair () {
    # Download/update to latest RACHEL lighttpd.conf
    echo; print_status "Downloading latest lighttpd.conf" | tee -a $RACHELLOG
    ## lighttpd.conf - RACHEL version (I don't overwrite at this time due to other dependencies)
    sudo wget https://github.com/rachelproject/rachelplus/raw/master/lighttpd.conf -O /usr/local/etc/lighttpd.conf 1>> $RACHELLOG 2>&1
    print_good "Done." | tee -a $RACHELLOG

    # Reapply /etc/fstab entry for /media/RACHEL
    echo; print_status "Adding /dev/sda3 into /etc/fstab" | tee -a $RACHELLOG
    sed -i '/\/dev\/sda3/d' /etc/fstab
    echo -e "/dev/sda3\t/media/RACHEL\t\text4\tauto,nobootwait 0\t0" >> /etc/fstab
    print_good "Done." | tee -a $RACHELLOG
}

## sources.list - replace the package repos for more reliable ones (/etc/apt/sources.list)
echo; print_question "What you would like to do:" | tee -a $RACHELLOG
echo "  - [Install] a RACHEL on a CAP" | tee -a $RACHELLOG
echo "  - [Repair] an install of a CAP after a firmware upgrade" | tee -a $RACHELLOG
echo "  - [Exit] the installation script" | tee -a $RACHELLOG
echo
select class in "Install" "Repair" "Exit"; do
        case $class in
        Install)
            echo; print_status "Conducting a new install of RACHEL on a CAP."
            new_install
        ;;

        Repair)
            echo; print_status "Repairing your CAP after a firmware upgrade."
            repair
            sudo mv $RACHELLOG $RACHELLOGDIR/rachel-repair-$TIMESTAMP.log
            echo; print_good "Log file saved to: $RACHELLOGDIR/rachel-repair-$TIMESTAMP.log"
            print_good "RACHEL CAP Repair Complete."
            echo; print_status "I need to reboot; once rebooted, the next script will run automatically."
            print_status "Rebooting in 10 seconds..."
            sleep 10
            reboot
        ;;

        Exit)
            echo; print_status "Exiting, nothing to do."
            echo; exit 1
        ;;
        esac
done