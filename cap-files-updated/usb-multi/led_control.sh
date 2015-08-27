#!/bin/sh

##
# Control sys and 3G LED 
#
# @author: Lu, Ken (ken.lu@intel.com)
#
##

SYS_GPIO_ROOT="/sys/class/gpio"

usage() {
    echo "
Usage: `basename $1` [normal|breath|issue|3g] [on|off]
"
}

check_parameter() {
    if [ -z "$1" ]; then
        usage $0
        echo "Please specify LED for normal, breath, issue or 3g."
        exit 1
    fi

    if [ -z "$2" ]; then
        usage $0
        echo "Please specify on or off"
        exit 1
    fi
}

export_gpio() {
    echo "Export GPIO $1........."
    # export specific GPIO
    echo $1 > $SYS_GPIO_ROOT/export
    if [ ! -d "$SYS_GPIO_ROOT/gpio$1/" ]; then
        echo "GPIO folder $SYS_GPIO_ROOT/gpio$1 does not exist".
        exit 1
    fi

    # change the GPIO direction
    echo "out" > $SYS_GPIO_ROOT/gpio$1/direction
    case $2 in
        on)
            echo 1 > $SYS_GPIO_ROOT/gpio$1/value
            ;;
        off)
            echo 0 > $SYS_GPIO_ROOT/gpio$1/value
        ;;
     esac
}

unexport_gpio() {
    echo "Unexport GPIO $1.........."
    # export specific GPIO
    echo $1 > $SYS_GPIO_ROOT/unexport
}

check_parameter $1 $2
case $1 in
    normal)
        export_gpio 84 $2
        ;;
    breath)
        export_gpio 85 $2
        ;;
    issue)
        export_gpio 86 $2
        ;;
    3g)
        export_gpio 87 $2
        ;;
    *)
        usage
        ;;
esac
