# RACHEL-Plus
RACHEL Configuration on RACHEL-Plus
 * [Demo Website](http://rachel.golearn.us)
 * [Developer Wiki](http://rachel.golearn.us/wiki)
 * [Manufacturers Data Sheet](http://www.intel.com/content/www/us/en/education/solutions/content-access-point.html)

## 1. Update your RACHEL-Plus with the latest firmware
Running the latest RACHEL Recovery USB will update the CAPs firmware to the latest version while also updating RACHEL functionality

## 2. PRIMARY and RECOMMENDED Install Method
[Use the RACHEL Recovery USB, Method 1](http://rachel.golearn.us/wiki/mdwiki.html#!cap-usb-recovery.md)

## 3. Add RACHEL content
Use the following script to download all content for a specific language.
NOTE:  COPY/PASTE BOTH LINES into your RACHEL-Plus shell/console
```bash
wget https://raw.githubusercontent.com/rachelproject/rachelplus/master/cap-rachel-configure.sh \
-O /root/cap-rachel-configure.sh; chmod +x /root/cap-rachel-configure.sh; /root/cap-rachel-configure.sh
```
- - - - -

The HTML folder "shell" (HTML, _h5ai, and a few tools) for RACHEL content is available at https://github.com/rachelproject/contentshell

- - - - -

## OPTIONAL - LEGACY Install Method - RACHEL initial setup script for Intel CAP
Running the following script will configure the Intel CAP hardware up to the point where you can start loading content onto that harddrive (into the folder /media/RACHEL/rachel).  You are given the option to initialize the script in ONLINE or OFFLINE mode (large content locally stored; still requires internet access for initial install of mysql server).  

The RACHEL install workflow consists of the following steps:
  - Step 1 - Install RACHEL (the RACHEL contentshell - web interface with no content)
  - Step 2 - Install KA Lite (Khan Academy Offline)
  - Step 3 - Install Kiwix (Clean HTML5 directory listings for content)
  - Step 4 - Install Weaved (remote access support)
  - Step 5 - Install Content (including Wikipedia, KA Lite, GCF Offline, etc)
