#!/bin/bash
#
# 1)  Install missing tools:
if [ "${EUID}" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi

apt install -y zfsutils-linux zfs-initramfs gdisk
modprobe zfs
#
# #  Partition the hard drive ...  Adjust for your hardware / setup...
#
#  Define variables.  Change these to suit BEFORE running script...
#
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
#
wipefs -af $DISK
sgdisk --zap-all $DISK
partprobe $DISK
sgdisk -n "${EFI_PART}:1m:${EFI_SIZE}" -t "${EFI_PART}:ef00" -c 0:esp $DISK
sgdisk -n "${SWAP_PART}:0:${SWAP_SIZE}" -t "${SWAP_PART}:8200" -c 0:swap $DISK
sgdisk -n "${POOL_PART}:0:${POOL_SIZE}" -t "${POOL_PART}:bf00" -c 0:pool $DISK
export POOL_ID=/dev/disk/by-partuuid/$( blkid | grep "${POOL_DISK}" | awk -F "=" '{print $NF}' | cut -d '"' -f 2 )

#
# Create EFI partition
mkfs.vfat -F32 $EFI_DISK
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
zfs create -o mountpoint=/ -o canmount=noauto ${POOL_NAME}/ROOT/lubuntu
zfs create -o mountpoint=/home ${POOL_NAME}/home
zfs create -o mountpoint=/var ${POOL_NAME}/var
#
# # Set boot filesystem...
zpool set bootfs=${POOL_NAME}/ROOT/lubuntu ${POOL_NAME}
# Export and re-import the zpool...
zpool export ${POOL_NAME}
zpool import -N -R "${NEW_ROOT}" ${POOL_NAME}
#
# mount the zfs filesystems...
zfs mount ${POOL_NAME}/ROOT/lubuntu
zfs mount ${POOL_NAME}/home
zfs mount ${POOL_NAME}/var
#
# # ?!?!?
udevadm trigger
#
# # Install lubuntu...(taken from session.log from virtual box install)...
mkdir -p "${NEW_ROOT}"/boot/efi
mount -t vfat -o defaults /dev/sda1 "${NEW_ROOT}"/boot/efi

udevadm settle
sync
mkdir -p "${NEW_ROOT}"/dev
mount -o bind /dev "${NEW_ROOT}"/dev
udevadm settle
sync
mkdir -p "${NEW_ROOT}"/proc
mount -t proc -o defaults proc "${NEW_ROOT}"/proc
udevadm settle
sync
mkdir -p "${NEW_ROOT}"/run
mount -t tmpfs -o defaults tmpfs "${NEW_ROOT}"/run
udevadm settle
sync
mkdir -p "${NEW_ROOT}"/run/systemd/resolve
mount -o bind /run/systemd/resolve "${NEW_ROOT}"/run/systemd/resolve
udevadm settle
sync
mkdir -p "${NEW_ROOT}"/run/udev
mount -o bind /run/udev "${NEW_ROOT}"/run/udev
udevadm settle
sync
mkdir -p "${NEW_ROOT}"/sys
mount -t sysfs -o defaults sys "${NEW_ROOT}"/sys
udevadm settle
sync
mkdir -p "${NEW_ROOT}"/sys/firmware/efi/efivars
mount -t efivarfs -o defaults efivarfs "${NEW_ROOT}"/sys/firmware/efi/efivars
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

#
cp post_chroot.bash "${NEW_ROOT}"
chroot "${NEW_ROOT}" /bin/bash /post_chroot.bash
umount -n -R "${NEW_ROOT}"
zpool export ${POOL_NAME}
echo "End of $0"