Howto & shell scripts to install Lubuntu 24.04 on your system using zfs....

This script will install lubuntu onto a zfs / zpool.
Unlike the ubuntu install program, it creates a SINGLE zpool.
Unlike the ubuntu install program, it can SHARE the disk with
other operating systems.  The author has successfully used it
to create a dual-boot system (install M$ Windoze first!)

This script has been tested with the following lubuntu images:
lubuntu-24.04-desktop-amd64.iso
lubuntu-24.04.1-desktop-amd64.iso

The author *BRIEFLY* attempted to use this script to install
xubuntu.  It *DID NOT WORK* with the following image:
xubuntu-24.04.1-minimal-amd64.iso