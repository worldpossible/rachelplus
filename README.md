# rachelplus
RACHEL Configuration on Intel CAP

```BETA``` Warning:  Still working on this but very close

## Setting up RACHEL on a Intel CAP that is otherwise unconfigured 

#### Update your Intel CAP with the latest firmware
1. Run the USB recovery to Firmware 1.2.4_root
2. MPT upgrade to Firmware 1.2.6_root
3. MPT upgrade to Firmware 1.2.10_root

#### ```BETA``` Warning:  Still working on this but very close (worth saying again)
If you choose to test this in it's current form, run the following script to setup the CAP to support RACHEL
```bash
wget https://github.com/rachelproject/rachelplus/raw/master/cap-rachel-first-install.sh -O - | bash 
```

#### Add RACHEL content
The "shell" (mostly CSS, HTML, rsphider, and _h5ai) for RACHEL content is available at https://github.com/rachelproject/contentshell
