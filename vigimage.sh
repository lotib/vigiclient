#!/bin/bash
#
# Configures a raspbian image to operate a vigibot
# Vigibot image is created from the official raspbian image.
#

set -e
set -u


# http://downloads.raspberrypi.org/raspbian/images/

RASPBIAN_LATEST="https://downloads.raspberrypi.org/raspbian_lite_latest"
RASPBIAN_STRETCH=http://downloads.raspberrypi.org/raspbian/images/raspbian-2019-04-09/2019-04-08-raspbian-stretch.zip


DOWNLOAD_DIR="/tmp/raspbian"
RASPBIAN_ZIP=${DOWNLOAD_DIR}/raspbian_lite_latest.zip
RASPBIAN_IMG=
BOOT_PARTITION=
ROOT_PARTITION=
ROOT_DIR=$(mktemp -d)
BOOT_DIR=${ROOT_DIR}/boot
NO_DELETE=
NO_CLEAN=
ARM_ARCH=
USE_IMG=

#
#
function cleanup()
{
    [ "${NO_CLEAN}" != "" ] && exit 0
    echo "cleanup"
    umount_image
    if [ "${NO_DELETE}" == "" ] ; then
        if [ "${DOWNLOAD_DIR}" != "" -a -d ${DOWNLOAD_DIR} ] ; then
            rm -rf ${DOWNLOAD_DIR}
        fi
    fi
}


function check_arch()
{
    local local_arch=$(uname -a |grep arm)

    if [ "${local_arch}" != "" ] ; then
        ARM_ARCH=1
        echo "arm arch detected"
    fi
}

trap "cleanup" EXIT TERM INT

function install_tools()
{
    apt update
    apt install -y wget zip unzip kpartx

    if [ "${ARM_ARCH}" == "" ] ; then
        apt install -y qemu-user-static binfmt-support
    fi
}

function get_image()
{
    mkdir -p ${DOWNLOAD_DIR}
    wget  -O ${RASPBIAN_ZIP} ${RASPBIAN_LATEST} -N
    unzip ${RASPBIAN_ZIP} -d ${DOWNLOAD_DIR}
}


function mount_image()
{
    RASPBIAN_IMG=$(ls ${DOWNLOAD_DIR}/*.img)

    if [ "${RASPBIAN_IMG}" != "" ] ; then
        BOOT_PARTITION=$(kpartx -asv ${RASPBIAN_IMG} | grep "loop[0-9]p1" | sed -e 's/.*\(loop[0-9]p1\).*/\1/')
        ROOT_PARTITION=$(kpartx -asv ${RASPBIAN_IMG} | grep "loop[0-9]p2" | sed -e 's/.*\(loop[0-9]p2\).*/\1/')

        if [ "${BOOT_PARTITION}" != "" -a "${ROOT_PARTITION}" != "" ] ; then
            mount "/dev/mapper/${ROOT_PARTITION}" "${ROOT_DIR}"
            mount "/dev/mapper/${BOOT_PARTITION}" "${BOOT_DIR}"
            if [ "${ARM_ARCH}" != "" ] ; then
                # permits to use raspi-config in chroot, but not sure it is a good idea :)
                mount --bind /sys "${ROOT_DIR}/sys"
                mount --bind /proc "${ROOT_DIR}/proc"
            fi
        fi
    fi
}

# TODO check mounted partitions and device mapping
function umount_image()
{
    if [ "${ARM_ARCH}" != "" -a "${ROOT_DIR}" != "" ] ; then
        if [ "$(mount |grep ${ROOT_DIR}/sys)" != "" ] ;then
            umount "${ROOT_DIR}/sys"
        fi
        if [ "$(mount |grep ${ROOT_DIR}/proc)" != "" ] ;then
            umount "${ROOT_DIR}/proc"
        fi
    fi

    if [ "${BOOT_PARTITION}" != "" ] ; then
        umount "/dev/mapper/${BOOT_PARTITION}" || echo "failed to umount ${BOOT_PARTITION}"
    fi

    if [ "${ROOT_PARTITION}" != "" ] ; then
        umount "/dev/mapper/${ROOT_PARTITION}" || echo "failed to umount ${ROOT_PARTITION}"
    fi

    if [ "${RASPBIAN_IMG}" != "" ] ; then
        kpartx -d "${RASPBIAN_IMG}" || echo "failed to delete device map"
    fi
}

function update_image()
{
    if [ -d "${ROOT_DIR}/usr/bin" ] ; then

        if [ "${ARM_ARCH}" == "" ]; then
            cp /usr/bin/qemu-arm-static "${ROOT_DIR}/usr/bin"
        fi
        cp install.sh ${ROOT_DIR}/tmp
        chroot "${ROOT_DIR}" /tmp/install.sh
        rm -rf ${ROOT_DIR}/var/cache/apt
    fi
}

function export_image()
{
    if [ -f ${RASPBIAN_IMG} ] ; then
        zip vigimage.zip ${RASPBIAN_IMG}
    fi
}

check_arch

function help()
{
    echo "$0 --create [from_img]"
    exit 0
}

for i in $@ ; do
    case "${1}" in
    "--no-clean")
        NO_CLEAN=1
        shift
    ;;
    "--no-delete")
        NO_DELETE=1
        shift
    ;;
    "--umount")
        ROOT_DIR="$2"
        umount_image
        exit 0
    ;;
    "--create")
        if [ "$2" != "" ] ; then
            RASPBIAN_IMG="$2"
        else
            get_image
        fi
        mount_image
        update_image
        umount_image
        export_image
        shift
    ;;
    "--debug")
        ls /dev/mapper/*
        mount |grep loop
        exit 0
    ;;
    "--exec")
        ${2}
        exit 0
    ;;
    "--help")
        help
    ;;
    *)
    help
    ;;
    esac
done


