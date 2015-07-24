# RACHELplus
RACHEL Configuration on Intel CAP

[Manufacturers Website](http://www.intel.com/content/www/us/en/education/solutions/content-access-point.html)

## Update your Intel CAP with the latest firmware
1. Run the USB recovery to Firmware 1.2.4_root
2. MPT upgrade to Firmware 1.2.6_root
3. MPT upgrade to Firmware 1.2.10_root

## RACHEL initial setup script for Intel CAP
Running the following script will configure the Intel CAP hardware up to the point where you can start loading content onto that harddrive (into the folder /media/RACHEL/rachel).  
NOTE:  COPY/PASTE BOTH LINES into your CAP shell/console
```bash
wget https://raw.githubusercontent.com/rachelproject/rachelplus/master/cap-rachel-configure.sh \
-O /root/cap-rachel-configure.sh; bash /root/cap-rachel-configure.sh
```

## Add RACHEL content
The "shell" (mostly CSS, HTML, rsphider, and _h5ai) for RACHEL content is available at https://github.com/rachelproject/contentshell
