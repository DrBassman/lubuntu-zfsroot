#!/bin/bash
#
# Run this script as root (or with sudo)
#
if [ "${EUID}" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi

#
#  Define variables.  Change these to suit BEFORE running script...
#
DISK=/dev/sda	    		# Set to desired device to install.
USER_NAME="ryan"	    	# Set to desired login name of user added
FULL_NAME="Beavis"		    # Set to desired full name of user added
USER_PASSWORD="none"		# Set to desired password for the created user
WIPE_DISK=1	    		    # Set to 0 to preserve existing partitions
FORMAT_EFI=1		    	# Set to 0 to preserve existing EFI
TIME_ZONE="America/Chicago"	# Set to desired time zone...
BE_NAME=lubuntu-24.04		# Set to desired boot environment name.
EFI_PART=1	         		# EFI partition #
SWAP_PART=2		        	# Swap partition #
POOL_PART=3			        # zpool partition #
EFI_SIZE="+1g"  			# set to desired size of EFI
SWAP_SIZE="+16g"    		# set to desired size of swap
POOL_SIZE="-10m"	    	# set to desired size of zpool;
#                             (negative # leaves that much space at end)
POOL_NAME="zlubuntu"		# set to desired name of zpool
UMOUNT_TARGET=0             # set to 1 to unmount target when done...
# nvme partitions have different names:
if echo $DISK | grep -q nvme ; then
    EFI_DISK="${DISK}"p"${EFI_PART}"
    SWAP_DISK="${DISK}"p"${SWAP_PART}"
    POOL_DISK="${DISK}"p"${POOL_PART}"
else
    EFI_DISK="${DISK}""${EFI_PART}"
    SWAP_DISK="${DISK}""${SWAP_PART}"
    POOL_DISK="${DISK}""${POOL_PART}"
fi
NEW_ROOT="/target"
#
# Note:  MUST export variables so they are visible for chroot
#        commands below...
#
export EFI_DISK TIME_ZONE USER_NAME FULL_NAME USER_PASSWORD
#
# 1)  Install missing tools:
apt install -y zfsutils-linux zfs-initramfs gdisk
modprobe zfs
if [ ${WIPE_DISK} -eq 1 ]; then
    wipefs -af $DISK
    sgdisk --zap-all $DISK
fi
partprobe $DISK
if [ ${FORMAT_EFI} -eq 1 ]; then
    sgdisk -n "${EFI_PART}:1m:${EFI_SIZE}" -t "${EFI_PART}:ef00" -c 0:esp $DISK
fi
sgdisk -n "${SWAP_PART}:0:${SWAP_SIZE}" -t "${SWAP_PART}:8200" -c 0:swap $DISK
sgdisk -n "${POOL_PART}:0:${POOL_SIZE}" -t "${POOL_PART}:bf00" -c 0:pool $DISK
export POOL_ID=/dev/disk/by-partuuid/$( blkid | grep "${POOL_DISK}" | awk -F "=" '{print $NF}' | cut -d '"' -f 2 )

#
# Create EFI partition
if [ ${FORMAT_EFI} -eq 1 ]; then
    mkfs.vfat -F32 $EFI_DISK
fi
#
# Create the zpool
# 
zpool create -f -o ashift=12 \
  -O compression=lz4 \
  -O acltype=posixacl \
  -O xattr=sa \
  -O relatime=on \
  -o autotrim=on \
  -o compatibility=openzfs-2.1-linux \
  -m none \
  "${POOL_NAME}" "${POOL_ID}"
#
# Create the zfs filesystems...
zfs create -o mountpoint=none ${POOL_NAME}/ROOT
zfs create -o mountpoint=/ -o canmount=noauto ${POOL_NAME}/ROOT/${BE_NAME}
zfs create -o mountpoint=/home ${POOL_NAME}/home
zfs create -o mountpoint=/var ${POOL_NAME}/var
#
# # Set boot filesystem...
zpool set bootfs=${POOL_NAME}/ROOT/${BE_NAME} ${POOL_NAME}
# Export and re-import the zpool...
zpool export ${POOL_NAME}
zpool import -N -R "${NEW_ROOT}" ${POOL_NAME}
#
# mount the zfs filesystems...
zfs mount ${POOL_NAME}/ROOT/${BE_NAME}
zfs mount ${POOL_NAME}/home
zfs mount ${POOL_NAME}/var
#
# # ?!?!?
udevadm trigger
#
# # Install lubuntu...(taken from session.log from virtual box install)...
mkdir -p "${NEW_ROOT}"/boot/efi
mount -t vfat -o defaults ${EFI_DISK} "${NEW_ROOT}"/boot/efi
mkdir -p "${NEW_ROOT}"/dev
mount -o bind /dev "${NEW_ROOT}"/dev
mkdir -p "${NEW_ROOT}"/proc
mount -t proc -o defaults proc "${NEW_ROOT}"/proc
mkdir -p "${NEW_ROOT}"/run
mount -t tmpfs -o defaults tmpfs "${NEW_ROOT}"/run
mkdir -p "${NEW_ROOT}"/run/systemd/resolve
mount -o bind /run/systemd/resolve "${NEW_ROOT}"/run/systemd/resolve
mkdir -p "${NEW_ROOT}"/run/udev
mount -o bind /run/udev "${NEW_ROOT}"/run/udev
mkdir -p "${NEW_ROOT}"/sys
mount -t sysfs -o defaults sys "${NEW_ROOT}"/sys
mkdir -p "${NEW_ROOT}"/sys/firmware/efi/efivars
mount -t efivarfs -o defaults efivarfs "${NEW_ROOT}"/sys/firmware/efi/efivars
mkdir -p "${NEW_ROOT}"/dev/pts
mount -t devpts pts "${NEW_ROOT}"/dev/pts
udevadm settle
sync
    
mkdir /filesystem
mount -t squashfs -o loop /cdrom/casper/filesystem.squashfs /filesystem
udevadm settle
sync
unsquashfs -l /cdrom/casper/filesystem.squashfs
rsync -aHAXSr --filter=-x\ trusted.overlay.\* --exclude /proc/ --exclude /sys/ --exclude /dev/ --exclude /run/ --exclude /run/udev/ --exclude /sys/firmware/efi/efivars/ --exclude /run/systemd/resolve/ --progress /filesystem/ "${NEW_ROOT}"

# # Generate machine-id." ( 12 / 42 ) 
systemd-machine-id-setup --root="${NEW_ROOT}"

cp /cdrom/casper/vmlinuz "${NEW_ROOT}"/boot/vmlinuz-$(uname -r)
mkdir -pv "${NEW_ROOT}"/media/cdrom
mount --bind /cdrom "${NEW_ROOT}"/media/cdrom

######################################################################
# chroot commands                                                    #
######################################################################
chroot "${NEW_ROOT}" /bin/bash -c '

ln -sf /etc/machine-id /var/lib/dbus/machine-id
    
# "Setting timezone to ${TIME_ZONE}…" ( 14 / 42 ) 
rm -f /etc/localtime
ln -s /usr/share/zoneinfo/${TIME_ZONE} /etc/localtime

groupadd --system sambashare

useradd -m -U -s /bin/bash -c "${FULL_NAME}" ${USER_NAME}
usermod -aG adm,cdrom,dip,lpadmin,plugdev,sambashare,sudo ${USER_NAME}
chown -R  ${USER_NAME}:${USER_NAME} /home/${USER_NAME}

echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd
usermod -p \! root

hwclock --systohc --utc

/bin/sh -c "touch /boot/initrd.img-$(uname -r)"

update-initramfs -k all -c -t

/bin/sh -c "apt-cdrom add -m -d=/media/cdrom/"
/bin/sh -c "sed -i /deb http/d /etc/apt/sources.list"
/bin/sh -c "apt-get update"
/bin/sh -c "apt install -y --no-upgrade -o Acquire::gpgv::Options::=--ignore-time-conflict shim-signed"

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
DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::=--force-confnew full-upgrade

apt install -y zfsutils-linux zfs-initramfs gdisk
echo "swap /dev/disk/by-partlabel/swap /dev/urandom swap,offset=2048,cipher=aes-xts-plain64,size=512" >> /etc/crypttab
cat << EOF > /etc/fstab
$( blkid | grep "$EFI_DISK" | cut -d " " -f 2 ) /boot/efi vfat defaults 0 0
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
efibootmgr -c -d "$EFI_DISK" -p "$EFI_PART" -L "ZFSBootMenu (Backup)" -l \\EFI\\ZBM\\VMLINUZ-BACKUP.EFI
efibootmgr -c -d "$EFI_DISK" -p "$EFI_PART" -L "ZFSBootMenu" -l \\EFI\\ZBM\\VMLINUZ.EFI
apt install -y refind
' # end of commands executed in chroot environment...
######################################################################
# end of chroot environment commands                                             #
######################################################################
if [ ${UMOUNT_TARGET} -eq 1 ]; then
    umount -n -R "${NEW_ROOT}"
    zpool export ${POOL_NAME}
else
    echo "$NEW_ROOT left mounted..."
    echo "Unmount using..."
    echo "# umount -n -R ${NEW_ROOT}"
    echo "# zpool export ${POOL_NAME}"
    echo ""
fi
echo "End of $0"
