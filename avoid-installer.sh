#!/usr/bin/env bash

# Notes #######################################################################
#
# Inspiration:
# https://github.com/NicholasBHubbard/Void-Linux-Installer/blob/main/void-installer
#
# TODO accept a configuration file
# TODO make a verbose/debug mode to handle non-error printf statements
# TODO replace fzf with a simple bash menu system
# TODO pass arguments for user-configurable variables

# Global Variable Declarations ################################################

# user-configurable
TARGET_DISK=""  # the block device to which void will be installed
HOSTNAME=""  # this is the name that will appear on the network
EXTRA_PACKAGES="fzf git vim "  # this will be installed on your live system

# non-user-configurable #######################################################
BLOCK_DEVICES=""
HOST_DISK=""  # the disk hosting the current operating system
HOST_PARTITION=""  # the partition of the currently operating system

# Error handling and Debugging ################################################

exec 3>&2  # open file descriptor 3 and redirect it to stderr
#exec 3>/dev/null  # open file descriptor 3 and redirect it to /dev/null

# Function Definitions ########################################################

is_valid_hostname() {
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
#
# TODO verify we are in a live environment
# TODO check for dependencies: fzf, fdisk
# TODO verify we are running as root?
# TODO verify we are on a void linus system

# Main Logic ##################################################################

# Define TARGET_DISK
# TODO do some error checking on these variable assignments
HOST_PARTITION="$(df -P . | awk 'END{print $1}')"
HOST_DISK="$(lsblk -no PKNAME "$HOST_PARTITION")"

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
# TODO verify the target disk is not the one we are currently using
if [[ "${TARGET_DISK}" == "${HOST_DISK}" ]]; then
	printf "ERROR: target disk cannot be the host disk.\n" >&3
	exit 1
else
	printf "PASS: target disk is a valid target.\n" >&3
fi
# at this point TARGET_DISK is a valid block device on the system

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
# at this point HOSTNAME is a valid hostname

# Setup Some Stuff

# get the directory in which this script is stored, regardless of execution dir
# TODO find a use case for this for remove
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )


# WE ARE AT THE END NOW
printf "\nConfiguration\n"
printf "    target disk:  %s\n" "${TARGET_DISK}"
printf "    hostname:  %s\n" "${HOSTNAME}"

exec 3>&-  # close file descriptor 3

exit 0
