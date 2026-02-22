#!/usr/bin/env bash


# Notes #######################################################################


# Inspiration:
# https://github.com/NicholasBHubbard/Void-Linux-Installer
# https://github.com/kkrruumm/void-install-script
#
# TODO accept a configuration file
# TODO make a verbose/debug mode to handle non-error printf statements
# TODO replace fzf with a simple bash menu system
# TODO pass arguments for user-configurable variables


# Global Variable Declarations ################################################


# user-configurable
TARGET_DISK=""  # the block device to which void will be installed
TARGET_DEVICE=""  # /dev/${TARGER_DISK}
TARGET_PARTITION_LABEL="dos"
HOSTNAME="localhost"  # this is the name that will appear on the network
EXTRA_PACKAGES="fzf git vim "  # this will be installed on your live system

# non-user-configurable
BLOCK_DEVICES=""
HOST_DISK=""  # the disk hosting the current operating system
HOST_DEVICE=""  # /dev/${HOST_DISK}
HOST_PARTITION=""  # the partition of the currently operating system

# sfdisk stuff
SFDISK_SUPPORTED_LABELS=(linux swap)


# Error handling and Debugging ################################################


# TODO make this a function, so it can be run after argument processing

DEBUG="1"  # leave empty or set to zero (0) to disable debugging

if [[ -z ${DEBUG} || "${DEBUG}" == "0" ]]; then
	exec 3>/dev/null
else
	exec 3>&2  # open file descriptor 3 and redirect it to stderr
	printf "PASS: DEBUG is set\n"
fi


# Function Definitions ########################################################


function cleanup {
	exec 3>&-  # close file descriptor 3; used for debugging
	return 0
}

function is_valid_hostname {
	# FIXME the validity check is not correct. Just a basic sanity check.
	local hostname=$1
	# Max length is 253 characters, each label max 63 chars
	# only a-z, 0-9, and hyphens, but cannot start or end with a hyphen
	local regex="^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$"
	if [[ "$hostname" =~ $regex ]]; then
		return 0 # valid
	else
		return 1 # invalid
	fi
}


# System Verification #########################################################


# TODO verify we are in a live environment
# TODO check for dependencies: fzf, fdisk
# TODO verify we are on a void linus system

# Setup Some Stuff

# verify we are running as root?
if [[ $EUID -ne 0 ]]; then
	printf "ERROR: script must be run as root.\n" >&3
	printf "This script must be run as root (use sudo).\n"
	exit 1
else
	printf "PASS: user is root.\n" >&3
fi


# Main Logic ##################################################################


# get the directory in which this script is stored, regardless of execution dir
# TODO find a use case for this for remove
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# HERE SCRIPT_DIR in known

# Define TARGET_DISK
# TODO do some error checking on these variable assignments
HOST_PARTITION="$(df -P . | awk 'END{print $1}')"
HOST_DISK="$(lsblk -no PKNAME "$HOST_PARTITION")"
HOST_DEVICE="/dev/${HOST_DISK}"
# HERE HOST_PARTITION is known
# HERE HOST_DISK is known
# HERE HOST_DEVICE is know

# get a list of block devices
# TODO error check this variable assignment
BLOCK_DEVICES="$(lsblk --noheadings --nodeps --list --output NAME)"
if [[ -z $BLOCK_DEVICES ]]; then
	printf "ERROR: no target disks are available\n" >&3
	exit 1
fi
# if TARGET_DISK is undefined, the user selects from a list of BLOCK_DEVICES
if [[ -z $TARGET_DISK ]]; then
	TARGET_DISK=$(printf "${BLOCK_DEVICES}" | fzf)
fi
# verify the user made a selection
if [[ -z $TARGET_DISK ]]; then
	printf "ERROR: no disk selected\n" >&3
	exit 1
fi
# verify user selection is in the BLOCK_DEVICES list
if [[ -n $(grep "^${TARGET_DISK}$" <<< "${BLOCK_DEVICES}") ]]; then
	printf "PASS: target disk ${TARGET_DISK} is valid.\n" >&3
else
	printf "ERROR: target disk ${TARGET_DISK} does not exist\n" >&3
	exit 1
fi
# verify the target disk is not the one we are currently using
if [[ "${TARGET_DISK}" == "${HOST_DISK}" ]]; then
	printf "ERROR: target disk cannot be the host disk.\n" >&3
	exit 1
else
	printf "PASS: target disk is a valid target.\n" >&3
fi
TARGET_DEVICE="/dev/${TARGET_DISK}"
# HERE TARGET_DISK is a valid block device we are not using
# HERE TARGER_DEVICE is /dev/${TARGET_DEVICE}

# Define HOSTNAME

# if HOSTNAME is undefined, prompt the user
if [[ -z ${HOSTNAME} ]]; then
	printf "hostname: "
	read HOSTNAME
fi
# verify HOSTNAME is valid
if is_valid_hostname "${HOSTNAME}"; then
	printf "PASS: hostname ${HOSTNAME} is valid.\n" >&3
elif [[ "${HOSTNAME}" == "" ]]; then
	printf "ERROR: hostname cannot be empty.\n"
	exit 1
else
	printf "ERROR: hostname %s is not valid.\n" "${HOSTNAME}" >&3
	exit 1
fi
# HERE HOSTNAME is a valid hostname

# Partition and format the disk
# TODO make this banner conditional via rgument -q,--quiet
# https://patorjk.com/software/taag/#p=display&f=ANSI+Shadow&t=WARNING!
printf "                                                                    \n"
printf "       ██╗    ██╗ █████╗ ██████╗ ███╗   ██╗██╗███╗   ██╗ ██████╗ ██╗\n"
printf "       ██║    ██║██╔══██╗██╔══██╗████╗  ██║██║████╗  ██║██╔════╝ ██║\n"
printf "       ██║ █╗ ██║███████║██████╔╝██╔██╗ ██║██║██╔██╗ ██║██║  ███╗██║\n"
printf "       ██║███╗██║██╔══██║██╔══██╗██║╚██╗██║██║██║╚██╗██║██║   ██║╚═╝\n"
printf "       ╚███╔███╔╝██║  ██║██║  ██║██║ ╚████║██║██║ ╚████║╚██████╔╝██╗\n"
printf "        ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝\n"
printf "                                                                    \n"

# TODO display the disk partition and formatting information
# confirm the user would like to proceed with a destructive act
# TODO verify all required values exist and are valid (e.g. HOSTNAME)
printf "hostname: ${HOSTNAME}\n"
printf "host device: ${HOST_DEVICE}\n"
printf "target device: ${TARGET_DEVICE}\n"
printf "partition label: ${TARGET_PARTITION_LABEL}\n"
printf "\n"
printf "WARNING: This will create a partition table based on my usb drive.\n"
printf "WARNING: This will erase device ${TARGET_DEVICE}. Proceed? (yes/NO)\n"
read -r response
if [[ "$response" != "yes" ]]; then
	printf "Nothing will be done. Exiting...\n"
	exit 1
fi
exit 0  # XXX do NOT use this script!!! It is a work in progress.

# partition TARGET_DEVICE
sudo sfdisk "${TARGET_DEVICE}" << EOF
label: gpt
size=1GiB, type=U, name="EFI System"
size=+, type=L, name="Main Linux Filesystem"
EOF

# make first partition vfat for /boot/efi
if [[ "$?" == "0" ]]; then
	sudo mkfs.vfat -F 32 "${TARGET_DEVICE}1"
	sudo mkfs.vfat "${TARGET_DEVICE}1"  # /dev/sda1
	sudo mkfs.ext4 "${TARGET_DEVICE}2"  # /dev/sda2
else
	printf "ERROR: sfdisk experienced an error\n" >&3
fi

#mount /dev/sda2 /mnt/
mount "${TARGET_DEVICE}2" /mnt/
mkdir -p /mnt/boot/efi/
#mount /dev/sda1 /mnt/boot/efi/
mount "${TARGET_DEVICE}1" /mnt/boot/efi/

xgenfstab -U /mnt > /mnt/etc/fstab
printf "Entering chroot...\n"
xchroot /mnt /bin/bash

# WE ARE AT THE END NOW
printf "\nConfiguration\n"
printf "    target disk:  %s\n" "/dev/${TARGET_DISK}"
printf "    hostname:  %s\n" "${HOSTNAME}"


cleanup





exit 0
