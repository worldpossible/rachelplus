check_mode(){
    not_shift="`i2cset -y 7 0x0b 0x0 0x0054 w && sleep 1 && /usr/bin/i2cget -y 7 0x0b 0x23 i | awk '{print $3}' | awk -F '' '{print $4}'`"
    echo "$(($((16#${not_shift}))&3))"
}
    

unseal_chip(){  
    while [ "0x`check_mode`" == "0x3" ]; do
        echo "Chip Sealed.." >> /root/battery_log
        #HMAC2 generator
        i2cset -y 7 0x0b 0x0 0x0032 w && sleep 1
        sleep 1
        random_number="`/usr/bin/i2cget -y 7 0x0b 0x2f i | awk -F ':' '{print $2}'`"
        echo "random_number=[$random_number]" >> /root/battery_log
        HMAC2="`python /etc/key_gen.py \"$random_number\"`"
        sleep 1
        echo "HMAC2=[$HMAC2]" >> /root/battery_log
        i2cset -y 7 0x0b 0x2f $HMAC2 sp
        sleep 1
        echo `check_mode` >> /root/battery_log
        sleep 2
    done
}

get_row_and_confirm(){
    row=$1
    echo "get_row_and_confirm" >> /root/battery_log
    echo "row=$1" >> /root/battery_log

    raw_data_1="a"
    raw_data_2="b"

    while [ "$raw_data_1" != "$raw_data_2" ]; do
        i2cset -y 7 0x0b 0x0 0x01`printf "%02x" $row` w
        raw_data_1="`/usr/bin/i2cget -y 7 0x0b 0x2f i | awk -F ':' '{print $2}'`"
        sleep 1
        i2cset -y 7 0x0b 0x0 0x01`printf "%02x" $row` w
        raw_data_2="`/usr/bin/i2cget -y 7 0x0b 0x2f i | awk -F ':' '{print $2}'`"
    done
    echo "$raw_data_1"
}

write_row_and_confirm(){
    row=$1
    raw_data=$2

    echo "write_row_and_confirm" >> /root/battery_log
    echo "row=$1">>/root/battery_log
    echo "raw_data=$2">>/root/battery_log

    try_again="YES"
    
    while [ "$try_again" == "YES" ]; do
        i2cset -y 7 0x0b 0x0 0x01`printf "%02x" $row` w
        i2cset -y 7 0x0b 0x2f $raw_data sp
        raw_after_set="`get_row_and_confirm $row`"
        if [ "$raw_after_set" == "$raw_data" ]; then
            try_again="NO"
        else
           echo "Write Failed" >> /root/battery_log
           echo "raw_data     =[$raw_data]" >>/root/battery_log
           echo "raw_after_set=[$raw_after_set]">>/root/battery_log
        fi
    done
}

modify_row_data(){
    raw_data=$1
    row_offset=$2
    value=$3
    length=$4
    zero_number=$(($length*2))
    new_raw_data=""
    index=1
    value_hex="`eval printf "%0${zero_number}x" $value`" #0x0010  or 0x10
    for i in $raw_data; do
        # index > row_offset && index<= row_offset+length
        if [ $index -le $(($row_offset+$length)) ] && [ $index -gt $row_offset ]; then
            target_data="`echo "$value_hex" | awk -F '' '{print $1$2}'`"
            new_raw_data="$new_raw_data 0x${target_data}"
            value_hex="`echo "$value_hex" |  cut -c 3- `"
            echo "Find target index on [$index] " >> /root/battery_log
            echo "target data : [$target_data] " >>/root/battery_log
            echo "left   data : [$value_hex] " >> /root/battery_log
        else
            new_raw_data="$new_raw_data $i"
        fi
        index=$(($index+1))
    done
    echo "$new_raw_data"
}

modify_data_flash(){
    echo "Modify Data flash" >> /root/battery_log
    processing_row=""
    processing_row_data=""
    cat /etc/DF_CONFIG | while read LINE; do
        value="`echo $LINE | awk -F ' ' '{printf $1}'`"
        raw="`echo $LINE | awk -F ' ' '{printf $2}'`"
        raw_offset="`echo $LINE | awk -F ' ' '{printf $3}'`"
        length="`echo $LINE | awk -F ' ' '{printf $4}'`"
        if [ "$raw" != "$processing_row" ]; then
           echo "new raw!" >> /root/battery_log
           if [ "$processing_row" != "" ]; then
                write_row_and_confirm $processing_row "$processing_row_data"
           fi
           processing_row="$raw"
           processing_row_data="`get_row_and_confirm $raw`"
        fi
        echo "Modify this DF config to processing_row" >> /root/battery_log
        echo "Before  : [$processing_row_data]" >> /root/battery_log
        processing_row_data=`modify_row_data "$processing_row_data" $raw_offset $value $length` 
        echo "After   : [$processing_row_data]" >> /root/battery_log
    done
}

battery_issue(){
    insmod /lib/modules/i2c-gpio.ko
    insmod /lib/modules/i2c-gpio-custom.ko bus0=7,89,88,15
    unseal_chip #unseal the chip

    if [ "0x`check_mode`" != "0x1" ] ; then
        echo "..... Unseal failed ..." >> /root/battery_log
        retry_num=`cat /etc/RETRY_NUM`
        if [ "$?" != "0" ]; then
            echo "0" > /etc/RETRY_NUM
            retry_num=0
        fi

        if [ $retry_num -le 2 ]; then
            rm -f /etc/BATTERY_EDIT_DONE
            retry_num=$(($retry_num +1))
            echo "$retry_num" > /etc/RETRY_NUM
            reboot
        else
            echo "UNSEAL_FAILED" > /etc/BATTERY_EDIT_DONE
            echo "Battery Firmware Fix Complete" >> /etc/BATTERY_EDIT_DONE
        fi
    else
        echo "!!!! Unseal Success !!!!" >> /root/battery_log
        echo "UNSEAL_SUCCESS" > /etc/BATTERY_EDIT_DONE
	    modify_data_flash

        i2cset -y  7 0x0b 0x0 0x0012 w # reset ic 
        while [ "$?" != "0" ]; do
            i2cset -y  7 0x0b 0x0 0x0012 w # reset ic 
        done

	    echo "All Done , Ready to reboot" >> /root/battery_log
        echo "Battery Firmware Fix Complete" >> /etc/BATTERY_EDIT_DONE
        reboot
    fi
}

if [[ ! $(grep "Battery Firmware Fix Complete" /etc/BATTERY_EDIT_DONE) ]]; then
    echo "Do battery solve" >> /root/battery_log
    touch /etc/BATTERY_EDIT_DONE
    battery_issue
fi