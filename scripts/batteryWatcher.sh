#!/bin/bash
echo; echo "[*] System boot - battery monitor started at $(date)" >> /var/log/rachel/battery.log
badBattChk=0
# Wait 30 secs for OS to fully boot
sleep 30
while :; do
    # Check if system is finished booting
    if [[ -f /tmp/chargeStatus ]] && [[ -f /tmp/batteryLastChargeLevel ]]; then
        # If battery is not connected, do not run script
        if [[ $(cat /tmp/battery_connected_status 2>/dev/null) == 0 ]]; then
            echo "[!] Battery not connected, monitor stopped at $(date)" >> /var/log/rachel/battery.log
            echo "[+] Battery connected:  $(cat /tmp/battery_connected_status)" >> /var/log/rachel/battery.log 2>/dev/null
            exit 1
        else
            # If charge status is low (should be at/above 400 at 99% battery), battery connected, and last charge level is below 95%, then there is a possible bad battery and do not run script
            if [[ $(cat /tmp/chargeStatus 2>/dev/null) -lt 400 ]] && [[ $(cat /tmp/chargeStatus 2>/dev/null) -gt -275 ]] && [[ $(cat /tmp/batteryLastChargeLevel 2>/dev/null) -lt 95 ]]; then
                let "badBattChk++"
                if [[ $badBattChk -ge 6 ]]; then
                    echo "[!] Possible bad battery or charger, monitor stopped at $(date)" >> /var/log/rachel/battery.log
                    echo "[+] Battery connected:  $(cat /tmp/battery_connected_status)" >> /var/log/rachel/battery.log 2>/dev/null
                    echo "[+] Battery last charge level:  $(cat /tmp/batteryLastChargeLevel)" >> /var/log/rachel/battery.log 2>/dev/null
                    echo "[+] Battery charge status:  $(cat /tmp/chargeStatus)" >> /var/log/rachel/battery.log 2>/dev/null
                    echo "[+] Bad battery check #:  $(echo $badBattChk)" >> /var/log/rachel/battery.log 2>/dev/null
                    exit 1
                fi
            else
                badBattChk=0
                # If charging level is less then -200 (power not connected) and last charge level is below 3%, stop KA Lite and safely shutdown CAP 
                if [[ $(cat /tmp/chargeStatus 2>/dev/null) -lt -200 ]] && [[ $(cat /tmp/batteryLastChargeLevel 2>/dev/null) -lt 3 ]]; then
                    echo "[!] Low battery shutdown at $(date)" >> /var/log/rachel/battery.log
                    echo "[+] Battery connected:  $(cat /tmp/battery_connected_status)" >> /var/log/rachel/battery.log 2>/dev/null
                    echo "[+] Battery last charge level:  $(cat /tmp/batteryLastChargeLevel)" >> /var/log/rachel/battery.log 2>/dev/null
                    echo "[+] Battery charge status:  $(cat /tmp/chargeStatus)" >> /var/log/rachel/battery.log 2>/dev/null
                    echo "[+] Bad battery check #:  $(echo $badBattChk)" >> /var/log/rachel/battery.log 2>/dev/null
                    kalite stop
                    shutdown -h now
                    exit 0
                fi
            fi
        fi
        # Check battery every 10 seconds
        sleep 10
    fi
done