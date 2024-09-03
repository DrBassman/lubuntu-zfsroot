This script will install lubuntu onto a zfs / zpool.
Unlike the ubuntu install program, it creates a SINGLE zpool.
Unlike the ubuntu install program, it can SHARE the disk with
other operating systems.  The author has successfully used it
to create a dual-boot system (install M$ Windoze first!)

This script has been tested SUCCESSFULLY with the following lubuntu images:
* lubuntu-24.04-desktop-amd64.iso
* lubuntu-24.04.1-desktop-amd64.iso

The author *BRIEFLY* attempted to use this script to install
xubuntu.  It *DID NOT WORK* with the following image:
* xubuntu-24.04.1-minimal-amd64.iso

HOW TO USE SCRIPT:
1)  Boot one of the lubuntu iso images.
2)  Click on the 'Try lubuntu' button (NOT the 'Install' one).
3)  get the 'install_to_zfs.bash' script copied to the system. (As author was testing, could use firefox or sftp, e.g.)
4)  *EDIT* the 'install_to_zfs.bash' script...In particular, lines 16-32.  The comments tell what each shell variable does...
5)  *SAVE* your edited install_to_zfs.bash file.
6)  Run the script as root:  Author had success with 'sudo bash install_to_zfs.bash'
7)  At the end of the script, you must press the <ENTER> button twice so the install continues.  This is necessary to install the current version of refind.
8)  The newly installed system is under /target if you'd like to make any adjustments, etc. before rebooting.
9)  It is probably a good idea to unmount /target and zpool export the pool BEFORE rebooting.

The script copies the output you see on the screen to /var/log/install_to_zfs.log file that *SHOULD* survive after rebooting, if you'd like to review / troubleshoot if you run into problems...

This script installs refind and Zfs Boot Menu, which are used in sequence to boot the system.  If you have other OS's installed, they should 'show up' when refind loads.  The author has successfully used this to dual-boot a laptop to either M$ Windoze or lubuntu.

Ryan 'drBassman' Losh

ryan@ryanlosh.com

This would not have been possible without:

https://www.dwarmstrong.org/debian-install-zfs/

Also, the stock lubuntu install leaves it's log file (session.log) in a directory under ~/.cache in the live enviroment installed.  Script is product of these two sources...
