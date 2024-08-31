#!/bin/bash
#
# Run under chroot install path...
if [ "${EUID}" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi
USER_NAME="ryan"
USER_PASSWORD="none"
FULL_NAME="Beavis"
# Set next 2 to 0 if other OS already on disk...
DISK=/dev/sda
EFI_PART=1
SWAP_PART=2
POOL_PART=3
EFI_DISK="${DISK}""${EFI_PART}"
SWAP_DISK="${DISK}""${SWAP_PART}"
POOL_DISK="${DISK}""${POOL_PART}"
EFI_SIZE="+1g"
SWAP_SIZE="+16g"
POOL_SIZE="-10m"
POOL_NAME="zlubuntu"
NEW_ROOT="/mnt-$(cat /etc/machine-id)"

ln -sf /etc/machine-id /var/lib/dbus/machine-id

    
# "Setting timezone to America/Chicago…" ( 14 / 42 ) 
rm -f /etc/localtime
ln -s /usr/share/zoneinfo/America/Chicago /etc/localtime

locale-gen

groupadd --system sambashare

useradd -m -U -s /bin/bash -c "${FULL_NAME}" ${USER_NAME}
usermod -aG adm,cdrom,dip,lpadmin,plugdev,sambashare,sudo ${USER_NAME}
chown -R  ${USER_NAME}:${USER_NAME} /home/${USER_NAME}
echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd

usermod -p '!' root

hwclock --systohc --utc

/bin/sh -c "touch /boot/initrd.img-$(uname -r)"

update-initramfs -k all -c -t

/bin/sh -c "apt-cdrom add -m -d=/media/cdrom/"
/bin/sh -c "sed -i '/deb http/d' /etc/apt/sources.list"
/bin/sh -c "apt-get update"
/bin/sh -c "apt install -y --no-upgrade -o Acquire::gpgv::Options::=--ignore-time-conflict grub-efi-$(if grep -q 64 /sys/firmware/efi/fw_platform_size; then echo amd64-signed; else echo ia32; fi)"
/bin/sh -c "apt install -y --no-upgrade -o Acquire::gpgv::Options::=--ignore-time-conflict shim-signed"

/bin/sh -c "/usr/bin/dpkg --add-architecture i386"

/bin/sh -c "/usr/libexec/fixconkeys-part2"

apt-get update
apt-get --purge -q -y remove ^live-\* calamares-settings-lubuntu calamares zram-config cifs-utils lubuntu-installer-prompt
apt-get --purge -q -y autoremove

cat << EOF > /etc/apt/sources.list
# deb cdrom:[Lubuntu 24.04 LTS _Noble Numbat_ - Release amd64 (20240425.1)]/ noble main multiverse restricted universe
deb http://archive.ubuntu.com/ubuntu/ noble main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ noble-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ noble-updates main restricted universe multiverse
EOF

DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confnew' full-upgrade

apt install -y zfsutils-linux zfs-initramfs gdisk
echo "swap /dev/disk/by-partlabel/swap /dev/urandom swap,offset=2048,cipher=aes-xts-plain64,size=512" >> /etc/crypttab
cat << EOF > /etc/fstab
$( blkid | grep "$EFI_DISK" | cut -d ' ' -f 2 ) /boot/efi vfat defaults 0 0
/dev/mapper/swap none swap defaults 0 0
proc /proc proc defaults 0 0
EOF

systemctl enable zfs.target
systemctl enable zfs-import-cache
systemctl enable zfs-mount
systemctl enable zfs-import.target

zfs set org.zfsbootmenu:commandline="quiet loglevel=4" ${POOL_NAME}/ROOT
zpool set cachefile=/etc/zfs/zpool.cache ${POOL_NAME}
mkdir -p /boot/efi/EFI/ZBM
curl -o /boot/efi/EFI/ZBM/VMLINUZ.EFI -L https://get.zfsbootmenu.org/efi
cp /boot/efi/EFI/ZBM/VMLINUZ.EFI /boot/efi/EFI/ZBM/VMLINUZ-BACKUP.EFI
efibootmgr -c -d "$EFI_DISK" -p "$EFI_PART" -L "ZFSBootMenu (Backup)" -l '\EFI\ZBM\VMLINUZ-BACKUP.EFI'
efibootmgr -c -d "$EFI_DISK" -p "$EFI_PART" -L "ZFSBootMenu" -l '\EFI\ZBM\VMLINUZ.EFI'
apt install -y refind
echo "End of $0"