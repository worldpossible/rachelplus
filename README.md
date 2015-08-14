# RACHELplus
RACHEL Configuration on Intel CAP

[Manufacturers Website](http://www.intel.com/content/www/us/en/education/solutions/content-access-point.html)

## Update your Intel CAP with the latest firmware
Run the USB recovery to Firmware 1.2.13_rooted

## RACHEL initial setup script for Intel CAP
Running the following script will configure the Intel CAP hardware up to the point where you can start loading content onto that harddrive (into the folder /media/RACHEL/rachel).  You are given the option to initialize the script in ONLINE or OFFLINE mode (large content locally stored; still requires internet access for initial install of mysql server).  

At the moment, this script provides the ability to:
  1. Install RACHEL to a new CAP
  2. Repair RACHEL after firmware upgrade
  3. Install all available content for a paticular language
  4. Install KA Lite
  5. Install Kiwix
  6. Sanitize CAP for distribution/imaging
  7. Download all the large RACHEL content for use in OFFLINE installs

NOTE:  COPY/PASTE BOTH LINES into your CAP shell/console
```bash
wget https://raw.githubusercontent.com/rachelproject/rachelplus/master/cap-rachel-configure.sh \
-O /root/cap-rachel-configure.sh; bash /root/cap-rachel-configure.sh
```

## Add RACHEL content
Use script (above) option to download all content for a specific language.

- - - - -

The "shell" (mostly CSS, HTML, rsphider, and _h5ai) for RACHEL content is available at https://github.com/rachelproject/contentshell

