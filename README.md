# RACHELplus
RACHEL Configuration on Intel CAP

[Manufacturers Website](http://www.intel.com/content/www/us/en/education/solutions/content-access-point.html)

## 1. Update your Intel CAP with the latest firmware
Run the USB recovery to Firmware 1.2.15_rooted

## 2. RACHEL initial setup script for Intel CAP
Running the following script will configure the Intel CAP hardware up to the point where you can start loading content onto that harddrive (into the folder /media/RACHEL/rachel).  You are given the option to initialize the script in ONLINE or OFFLINE mode (large content locally stored; still requires internet access for initial install of mysql server).  

NOTE:  COPY/PASTE BOTH LINES into your CAP shell/console
```bash
wget https://raw.githubusercontent.com/rachelproject/rachelplus/master/cap-rachel-configure.sh \
-O /root/cap-rachel-configure.sh; bash /root/cap-rachel-configure.sh
```

The RACHEL install workflow consists of the following steps:
  1. Option 1 - Install RACHEL
  2. Option 2 - Install KA Lite
  3. Option 3 - Install Kiwix
  4. Option 4 - Install Sphider database
  5. Option 5 - Install Content (including Wikipedia)

## 3. Add RACHEL content
Use script (above) option to download all content for a specific language.

- - - - -

The "shell" (mostly CSS, HTML, rsphider, and _h5ai) for RACHEL content is available at https://github.com/rachelproject/contentshell

