#!/bin/bash

TMP_FILE=/tmp/dummy_image
DISKSIZE=512

# Make sure only root can run the script
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

cat /dev/zero | dd of=${TMP_FILE} count=${DISKSIZE} 2> /dev/null

loopback_device=$(sudo losetup --show -f $TMP_FILE)
sudo losetup -d $loopback_device

echo $loopback_device
