USB CAP Multitool
Description: This is the first script to run when the CAP starts up
It will set the LED lights and setup the emmc and hard drive

LED Status:
  - During script:  Wireless breathe and 3G solid
  - After success:  Wireless solid and 3G solid
  - After fail:  Wireless fast blink and 3G solid

Install Options or METHOD:
  - "Recovery" for end user CAP recovery (METHOD 1)
      Copy boot, efi, and rootfs partitions to emmc
      Rewrite the hard drive partitions
      DO NOT format any hard drive partitions
  - "Imager" for large installs when cloning the hard drive (METHOD 2)
      Copy boot, efi, and rootfs partitions to emmc
      Don't touch the hard drive (since you will swap with a cloned one)
  - "Format" for small installs and/or custom hard drive (METHOD 3)
      *WARNING* This will erase all partitions on the hard drive */WARNING*
      Copy boot, efi, and rootfs partitions to emmc
      Rewrite the hard drive partitions
      Format hard drive partitions
      Copy content shell to /media/RACHEL/rachel

INSTRUCTIONS
1. On this USB, modify to METHOD variable in script “update.sh”
2. Turn off the CAP
3. Connect the recovery USB disk to the CAP
4. Start the CAP

If the CAP doesn’t start successfully (LED indicators), restart the CAP and try again.

