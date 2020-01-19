#!/bin/bash

PROGNAME=${0##*/}

usage() { echo "Usage: ${PROGNAME} {loopback device} [-t|--type <hd|fd>] [-s|--sector-size <size of a sector in bytes>] {disk image}" 1>&2; exit 1; }

if [[ !($# -gt 0) ]]; then
    usage
fi

SHORTOPTS="hvt:s:"
LONGOPTS="help,version,disk-type:,sector-size:"

ARGS=$(getopt -s bash --options $SHORTOPTS  \
      --longoptions $LONGOPTS --name $PROGNAME -- "$@" )

if [ $? != 0 ]; then
    usage
fi

eval set -- "$ARGS"

VERBOSE=false
DISKTYPE="hd"
SECTORSIZE=512

while true; do
    case "$1" in
        -v | --verbose )
            VERBOSE=true;
            shift
            ;;

        -h | --help )
            usage
            shift
            ;;

        -s | --sector-size )
            SECTORSIZE="$2";
            shift 2
            ;;

        -t | --disk-type )
            DISKTYPE="$2";
            shift 2
            ;;

        -- )
            shift;
            break
            ;;

        * )
            break
            ;;
    esac
done

# Make sure only root can run the script
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

disk_image=${*: -1:1}
if [[ !(-f ${disk_image}) ]]; then
    echo "${disk_image} does not exist or is not a regular file" 1>&2
    exit 1;
fi
disk_image_size=$(du -b ${disk_image} | awk '{print $1}')

loopback_device=$1
if [[ !(-e ${loopback_device}) ]]; then
    echo "${loopback_device} does not exist" 1>&2
    exit 1;
elif [[ !(-b $1) ]]; then
    echo "${loopback_device} is not a block device" 1>&2
    exit 1;
fi

if [[ ${DISKTYPE} == "hd" ]]; then
    H=16
    S=63
    C=`expr ${disk_image_size} / ${H} / ${S}`
elif [[ ${DISKTYPE} == "fd" ]]; then
    C=80
    H=2
    S=18
else
    echo "\`${DISKTYPE}\` is not a valid value for disk type, only possible values are \"hd\" and \"fd\"" 1>&2
    usage
fi

#echo "loopback device = ${loopback_device}"
#echo "disk type = $DISKTYPE"
#echo "disk image = ${disk_image}"

function format_FAT_partitions()
{
    FAT16_line=$(fdisk -c=nondos -u=sectors -C ${C} -H ${H} -S ${S} -b ${SECTORSIZE} -l ${loopback_device} | grep FAT16 | awk '{print $1,$3,$4}')

    device_partition=$(echo ${FAT16_line} | awk '{print $1}')
    device_partition_sector_start=$(echo ${FAT16_line} | awk '{print $2}')
    device_partition_sector_end=$(echo ${FAT16_line} | awk '{print $3}')
    device_partition_size=`expr \( ${device_partition_sector_end} - ${device_partition_sector_start} + 1 \) \* ${SECTORSIZE}`

    # Format FAT partition
    ######################
    echo "Format to FAT16 partition ${device_partition} (begin=${device_partition_sector_start}, end=${device_partition_sector_end}), size=${device_partition_size} bytes"
    mkdosfs -v -n DUMMYOS -F 16 ${device_partition}
}

function format_MinixV1_partitions()
{
    MINIXv1_line=$(fdisk -c=nondos -u=sectors -C ${C} -H ${H} -S ${S} -b ${SECTORSIZE} -l ${loopback_device} | grep "Old Minix" | awk '{print $1,$2,$3}')

    device_partition=$(echo ${MINIXv1_line} | awk '{print $1}')
    device_partition_sector_start=$(echo ${MINIXv1_line} | awk '{print $2}')
    device_partition_sector_end=$(echo ${MINIXv1_line} | awk '{print $3}')
    device_partition_size=`expr \( ${device_partition_sector_end} - ${device_partition_sector_start} + 1 \) \* ${SECTORSIZE}`

    # Format Minix v1 partition
    ######################
    echo "Format to Minix v1 partition ${device_partition} (begin=${device_partition_sector_start}, end=${device_partition_sector_end}), size=${device_partition_size} bytes"
    mkfs.minix -1 ${device_partition}
}

# get the FAT partition name and offset
#######################################
losetup ${loopback_device} ${disk_image}
if [ $? -ne 0 ]; then
    losetup -d ${loopback_device}
    losetup ${loopback_device} ${disk_image}
fi

sudo partx -v --add ${loopback_device}

format_FAT_partitions
format_MinixV1_partitions

sync

sudo partx -v --delete ${loopback_device}

losetup -d ${loopback_device}

exit 0
