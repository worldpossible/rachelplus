# rachelplus
RACHEL Configuration on Intel CAP

## Setting up RACHEL on a Intel CAP that is otherwise unconfigured 

#### Update your Intel CAP with the latest firmware
1. Run the USB recovery to Firmware 1.2.4_root
2. MPT upgrade to Firmware 1.2.6_root
3. MPT upgrade to Firmware 1.2.10_root

#### RACHEL Initial Setup Script for Intel CAP
Running the following script will configure the Intel CAP hardware up to the point where you can start loading content onto that harddrive (into the folder /media/RACHEL/rachel)
```bash
wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-first-install.sh -O - | bash 
```

## Add RACHEL content
The "shell" (mostly CSS, HTML, rsphider, and _h5ai) for RACHEL content is available at https://github.com/rachelproject/contentshell
