#!/bin/bash
#
# Run under chroot install path...
if [ "${EUID}" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi

ln -sf /etc/machine-id /var/lib/dbus/machine-id

    
# "Setting timezone to America/Chicago…" ( 14 / 42 ) 
rm -f /etc/localtime
ln -s /usr/share/zoneinfo/America/Chicago /etc/localtime

locale-gen

groupadd --system sambashare

useradd -m -U -s /bin/bash -c Beavis ryan
usermod -aG adm,cdrom,dip,lpadmin,plugdev,sambashare,sudo ryan
chown -R  ryan:ryan /home/ryan

usermod -p '!' root

hwclock --systohc --utc

/bin/sh -c "touch /boot/initrd.img-$(uname -r)"

update-initramfs -k all -c -t

/bin/sh -c "apt-cdrom add -m -d=/media/cdrom/"
/bin/sh -c "sed -i '/deb http/d' /etc/apt/sources.list"
/bin/sh -c "apt-get update"
/bin/sh -c "apt install -y --no-upgrade -o Acquire::gpgv::Options::=--ignore-time-conflict grub-efi-$(if grep -q 64 /sys/firmware/efi/fw_platform_size; then echo amd64-signed; else echo ia32; fi)"
/bin/sh -c "apt install -y --no-upgrade -o Acquire::gpgv::Options::=--ignore-time-conflict shim-signed"

/usr/bin/debconf-set-selections /tmp/tmp0bre0tcl

/bin/sh -c "/usr/bin/dpkg --add-architecture i386"

/bin/sh -c "/usr/libexec/fixconkeys-part2"

apt-get update
apt-get --purge -q -y remove ^live-\* calamares-settings-lubuntu calamares zram-config cifs-utils lubuntu-installer-prompt
apt-get --purge -q -y autoremove

/bin/sh -c "DEBIAN_FRONTEND=noninteractive apt-get update"
/bin/sh -c DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confnew' full-upgrade
