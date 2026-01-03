#!/bin/bash
#
# Run this script as root (or with sudo)
#
# Updated for Debian Trixie...
#
# patterned after instructions at:
#
# https://docs.zfsbootmenu.org/en/v3.1.x/guides/debian/uefi.html
#
if [ "${EUID}" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi
LOGFILE=/var/log/install_to_zfs.log
export LOGFILE

main() {
    #
    #  Define variables.  Change these to suit BEFORE running script...
    #
    HOST_NAME="zfsdebtrixie"
    DEB_VERSION="trixie"
    DISK=/dev/sda	    		# Set to desired device to install.
    USER_NAME="user_name"	    	# Set to desired login name of user added
    FULL_NAME="User Name"		    # Set to desired full name of user added
    USER_PASSWORD="A1!bcdef"		# Set to desired password for the created user
    ROOT_PASSWORD="B2@cdefg"
    WIPE_DISK=1	    		    # Set to 0 to preserve existing partitions
    FORMAT_EFI=1		    	# Set to 0 to preserve existing EFI
    TIME_ZONE="America/Chicago"	# Set to desired time zone...
    BE_NAME=debian-trixie		# Set to desired boot environment name.
    EFI_PART=1	         		# EFI partition #
    SWAP_PART=2		        	# Swap partition #
    POOL_PART=3			        # zpool partition #
    EFI_SIZE="+1g"  			# set to desired size of EFI
    SWAP_SIZE="+8g"    		# set to desired size of swap
    POOL_SIZE="-10m"	    	# set to desired size of zpool;
    #                             (negative # leaves that much space at end)
    POOL_NAME="zroot"		# set to desired name of zpool
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
    export EFI_DISK EFI_PART TIME_ZONE USER_NAME FULL_NAME USER_PASSWORD POOL_NAME HOST_NAME ROOT_PASSWORD
    #
    # Generate /etc/hostid
    zgenhostid -f 0x00bab10c
    #
    # Wipe partitions, if indicated
    if [ ${WIPE_DISK} -eq 1 ]; then
        zpool labelclear -f $DISK
        wipefs -af $DISK
        sgdisk --zap-all $DISK
    fi
    #
    # Create EFI boot partition
    if [ ${FORMAT_EFI} -eq 1 ]; then
        sgdisk -n "${EFI_PART}:1m:${EFI_SIZE}" -t "${EFI_PART}:ef00" -c 0:esp $DISK
        mkfs.vfat -F32 $EFI_DISK
    fi
    #
    # Create pool and swap partitions
    sgdisk -n "${SWAP_PART}:0:${SWAP_SIZE}" -t "${SWAP_PART}:8200" -c 0:swap $DISK
    sgdisk -n "${POOL_PART}:0:${POOL_SIZE}" -t "${POOL_PART}:bf00" -c 0:pool $DISK
    export POOL_ID=/dev/disk/by-partuuid/$( blkid | grep "${POOL_DISK}" | awk -F "=" '{print $NF}' | cut -d '"' -f 2 )
    #
    # Create the zpool
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
    #
    # Set boot filesystem...
    zpool set bootfs=${POOL_NAME}/ROOT/${BE_NAME} ${POOL_NAME}
    #
    # Export and re-import the zpool...
    zpool export ${POOL_NAME}
    zpool import -N -R "${NEW_ROOT}" ${POOL_NAME}
    #
    # mount the zfs filesystems...
    zfs mount ${POOL_NAME}/ROOT/${BE_NAME}
    zfs mount ${POOL_NAME}/home
    #
    # Update device symlinks
    udevadm trigger
    #
    # Install Debian...
    debootstrap ${DEB_VERSION} ${NEW_ROOT}
    #
    # Copy files into the new install
    cp /etc/hostid ${NEW_ROOT}/etc
    cp /etc/resolv.conf ${NEW_ROOT}/etc
    mkdir -p "${NEW_ROOT}"/boot/efi
    mount -t vfat -o defaults ${EFI_DISK} "${NEW_ROOT}"/boot/efi
    #
    # Chroot into the new OS
    mount -t proc proc "${NEW_ROOT}"/proc
    mount -t sysfs sys "${NEW_ROOT}"/proc
    mount -B /dev "${NEW_ROOT}"/dev
    mount -t devpts pts "${NEW_ROOT}"/dev/pts
    ######################################################################
    # chroot commands                                                    #
    ######################################################################
    chroot "${NEW_ROOT}" /bin/bash -c '
    #
    # Basic Debian Configuration
    # set hostname
    echo "${HOST_NAME}" > /etc/HOST_NAME
    echo -e "127.0.1.1\t${HOST_NAME}" >> /etc/hosts
    # set root password
    echo "${ROOT_PASSWORD}" | passwd -s
    # add user & set password...
    useradd -m -U -u 1001 -s /bin/bash -c "${FULL_NAME}" ${USER_NAME}
    usermod -aG sudo ${USER_NAME}
    echo "${USER_PASSWORD}" | passwd -s ${USER_NAME}
    # configure apt sources
    cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian/ trixie main non-free-firmware contrib
deb-src http://deb.debian.org/debian/ trixie main non-free-firmware contrib

deb http://deb.debian.org/debian-security trixie-security main non-free-firmware contrib
deb-src http://deb.debian.org/debian-security/ trixie-security main non-free-firmware contrib

# trixie-updates, to get updates before a point release is made;
deb http://deb.debian.org/debian trixie-updates main non-free-firmware contrib
deb-src http://deb.debian.org/debian trixie-updates main non-free-firmware contrib
EOF
    # Update repository cache
    apt update
    # ZFS Configuration
    apt install linux-headers-amd64 linux-image-amd64 zfs-initramfs dosfstools curl efibootmgr
    echo "REMAKE_INITRD=yes" > /etc/dkms/zfs.conf
    systemctl enable zfs.target
    systemctl enable zfs-import-cache
    systemctl enable zfs-mount
    systemctl enable zfs-import.target
    # Configure initramfs-tools (No required steps)
    # Rebuild the initramfs
    update-initramfs -c -k all
    # Install and configure ZFSBootMenu
    zfs set org.zfsbootmenu:commandline="quiet" ${POOL_NAME}/ROOT
    # Create an fstab entry and mount
    cat << EOF > /etc/fstab
    $( blkid | grep "$EFI_DISK" | cut -d " " -f 2 ) /boot/efi vfat defaults 0 0
EOF
    mkdir -p /boot/efi
    mount /boot/efi
    # Install ZFSBootMenu
    mkdir -p /boot/efi/EFI/Debian
    curl -o /boot/efi/EFI/Debian/loader.efi -L https://get.zfsbootmenu.org/efi
    # Configure EFI boot entries
    mount -t efivarfs efivarfs /sys/firmware/efi/efivars
    efibootmgr -c -d "$EFI_DISK" -p "$EFI_PART" -L "Debian Trixie on zfs" -l \\EFI\\Debian\\loader.efi
'
    ######################################################################
    # end of chroot environment commands                                 #
    ######################################################################

    cp ${LOGFILE} ${NEW_ROOT}${LOGFILE}
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
}

if [ -t 0 ]; then
    main 2>&1 |tee -a $LOGFILE
else
    main >>$LOGFILE 2>&1
fi
