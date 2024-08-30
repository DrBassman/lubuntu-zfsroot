1)  Install missing tools:

$ sudo -i
# apt install -y zfsutils-linux zfs-initramfs gdisk
# modprobe zfs
# zfs version
#
# #  Partition the hard drive ...  Adjust for your hardware / setup...
#
# DISK=/dev/sda
# EFI_PART=1
# SWAP_PART=2
# POOL_PART=3
# EFI_DISK=${DISK}${EFI_PART}
# SWAP_DISK=${DISK}${SWAP_PART}
# POOL_DISK=${DISK}${POOL_PART}
# POOL_ID=
# EFI_SIZE="+1g"
# SWAP_SIZE="+16g"
# POOL_SIZE="-10m"
# POOL_NAME="zlubuntu"
# NEW_ROOT="/mnt-$(cat /etc/machine-id)"
#
# wipefs -af $DISK
# sgdisk --zap-all $DISK
# partprobe $DISK
# sgdisk -n "${EFI_PART}:1m:${EFI_SIZE}" -t "${EFI_PART}:ef00" -c 0:esp $DISK
# sgdisk -n "${SWAP_PART}:0:${SWAP_SIZE}" -t "${SWAP_PART}:8200" -c 0:swap $DISK
# sgdisk -n "${POOL_PART}:0:${POOL_SIZE}" -t "${POOL_PART}:bf00" -c 0:pool $DISK
#
#
# # Create EFI partition
#
# mkfs.vfat -F32 $EFI_DISK
#
# # Create the zpool
# 
# zpool create -f -o ashift=12 -O compression=lz4 -O acltype=posixacl -O xattr=sa -O relatime=on -o autotrim=on -o compatibility=openzfs-2.1-linux -m none "${POOL_NAME}" "${POOL_ID}"
#
# # Create the zfs filesystems...
#
# zfs create -o mountpoint=none ${POOL_NAME}/ROOT
# zfs create -o mountpoint=/ -o canmount=noauto ${POOL_NAME}/ROOT/lubuntu
# zfs create -o mountpoint=/home ${POOL_NAME}/home
# zfs create -o mountpoint=/var ${POOL_NAME}/var
#
# # Set boot filesystem...
# zpool set bootfs=${POOL_NAME}/ROOT/lubuntu ${POOL_NAME}
#
# # Export and re-import the zpool...
# zpool export ${POOL_NAME}
# zpool import -N -R "${NEW_ROOT}" ${POOL_NAME}
#
# # mount the zfs filesystems...
# zfs mount ${POOL_NAME}/ROOT/lubuntu
# zfs mount ${POOL_NAME}/home
# zfs mount ${POOL_NAME}/var
#
# # ?!?!?
# udevadm trigger
#
# # Install lubuntu...(taken from session.log from virtual box install)...
# mkdir -p "${NEW_ROOT}"/boot/efi
# mkfs.vfat -F32 $EFI_DISK
# mount -t vfat -o defaults /dev/sda1 "${NEW_ROOT}"/boot/efi

START HERE......
# udevadm settle
# sync
# mount -o bind /dev mnt/dev
# udevadm settle
# sync
# mount -t proc -o defaults proc mnt/proc
# udevadm settle
# sync
# mkdir -p "${NEW_ROOT}"/run
# mount -t tmpfs -o defaults tmpfs "${NEW_ROOT}"/run
# udevadm settle
# sync
# mkdir -p "${NEW_ROOT}"/run/systemd/resolve
# mount -o bind /run/systemd/resolve "${NEW_ROOT}"/run/systemd/resolve
# udevadm settle
# sync
# mount -o bind /run/udev "${NEW_ROOT}"/run/udev
# udevadm settle
# sync
# mkdir -p "${NEW_ROOT}"/sys
# mount -t sysfs -o defaults sys "${NEW_ROOT}"/sys
# udevadm settle
# sync
# mount -t efivarfs -o defaults efivarfs "${NEW_ROOT}"/sys/firmware/efi/efivars
# udevadm settle
# sync
    
# mkdir /filesystem
# mount -t squashfs -o loop /cdrom/casper/filesystem.squashfs /filesystem
# udevadm settle
# sync
# unsquashfs -l /cdrom/casper/filesystem.squashfs
# rsync -aHAXSr --filter=-x trusted.overlay.\* --exclude /proc/ --exclude /sys/ --exclude /dev/ --exclude /run/ --exclude /run/udev/ --exclude /sys/firmware/efi/efivars/ --exclude /run/systemd/resolve/ --progress /filesystem/ "${NEW_ROOT}"


# # Generate machine-id." ( 12 / 42 ) 
# systemd-machine-id-setup --root="${NEW_ROOT}"
#--------------------------------------------------------
# chroot ${NEW_ROOT}
# ln -sf /etc/machine-id /var/lib/dbus/machine-id

    
# "Setting timezone to America/Chicago…" ( 14 / 42 ) 
# rm -f /etc/localtime
# ln -s /usr/share/zoneinfo/America/Chicago /etc/localtime

2024-08-28 - 11:20:12 [6]:     Starting job "localecfg" ( 16 / 42 ) 
2024-08-28 - 11:20:12 [6]: [PYTHON JOB]: Found gettext "en_US" in "/usr/share/locale/en_US" 
# locale-gen

2024-08-28 - 11:20:41 [6]:     Starting job "Preparing groups…" ( 19 / 42 ) 
# groupadd --system sambashare

2024-08-28 - 11:20:41 [6]:     Starting job "Create user ryan" ( 20 / 42 ) 
# useradd -m -U -s /bin/bash -c Beavis ryan
# usermod -aG adm,cdrom,dip,lpadmin,plugdev,sambashare,sudo ryan
# chown -R  ryan:ryan /home/ryan

2024-08-28 - 11:20:41 [6]:     Starting job "Set password for user ryan" ( 21 / 42 ) 
# passwd ryan

2024-08-28 - 11:20:42 [6]:     Starting job "Set password for user root" ( 22 / 42 ) 
# usermod -p ! root

2024-08-28 - 11:20:42 [6]:     Starting job "hwclock" ( 26 / 42 ) 
# hwclock --systohc --utc

2024-08-28 - 11:20:42 [6]:     Starting job "Performing contextual processes' job…" ( 27 / 42 ) 
# /bin/sh -c "cp /cdrom/casper/vmlinuz "${NEW_ROOT}"/boot/vmlinuz-$(uname -r)"
# /bin/sh -c "mkdir -pv "${NEW_ROOT}"/media/cdrom"
# /bin/sh -c "mount --bind /cdrom "${NEW_ROOT}"/media/cdrom"

2024-08-28 - 11:20:42 [6]:     Starting job "Running shell processes…" ( 28 / 42 ) 
# /bin/sh -c "touch //boot/initrd.img-$(uname -r)"

2024-08-28 - 11:20:42 [6]:     Starting job "initramfscfg" ( 29 / 42 ) 
# update-initramfs -k all -c -t

# sh -c "which plymouth"
# sh -c "grep -q \"^HOOKS.*systemd\" /etc/mkinitcpio.conf"
2024-08-28 - 11:21:00 [6]:     .. Target cmd: ("sh", "-c", "grep -q \"^HOOKS.*systemd\" /etc/mkinitcpio.conf") Exit code: 2 output:
 grep: /etc/mkinitcpio.conf: No such file or directory


2024-08-28 - 11:21:00 [6]:     Starting job "Performing contextual processes' job…" ( 32 / 42 ) 
# /bin/sh -c "apt-cdrom add -m -d=/media/cdrom/"
# /bin/sh -c "sed -i '/deb http/d' /etc/apt/sources.list"
# /bin/sh -c "apt-get update"
# /bin/sh -c "apt install -y --no-upgrade -o Acquire::gpgv::Options::=--ignore-time-conflict grub-efi-$(if grep -q 64 /sys/firmware/efi/fw_platform_size; then echo amd64-signed; else echo ia32; fi)"
# /bin/sh -c "apt install -y --no-upgrade -o Acquire::gpgv::Options::=--ignore-time-conflict shim-signed"

# /usr/bin/debconf-set-selections /tmp/tmp0bre0tcl

2024-08-28 - 11:21:12 [6]:     Starting job "Running shell processes…" ( 35 / 42 ) 
# /bin/sh -c "/usr/bin/dpkg --add-architecture i386"

2024-08-28 - 11:21:12 [6]:     Starting job "Running shell processes…" ( 37 / 42 ) 
# /bin/sh -c "/usr/libexec/fixconkeys-part2"

2024-08-28 - 11:21:25 [6]:     Starting job "packages" ( 38 / 42 ) 
# apt-get update
# apt-get --purge -q -y remove ^live-\* calamares-settings-lubuntu calamares zram-config cifs-utils lubuntu-installer-prompt
# apt-get --purge -q -y autoremove

2024-08-28 - 11:21:55 [6]:     Starting job "Performing contextual processes' job…" ( 39 / 42 ) 
# /bin/sh -c "DEBIAN_FRONTEND=noninteractive apt-get update"
# /bin/sh -c DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confnew' full-upgrade

2024-08-28 - 11:31:53 [6]:     Starting job "Running shell processes…" ( 41 / 42 ) 
# /bin/sh -c "calamares-logs-helper /tmp/calamares-root-5w93ywqp"

