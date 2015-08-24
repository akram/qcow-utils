#!/bin/sh

set -e

echo "Loading nbd module to enable Network Block-Devices mount for qemu"
modprobe nbd max_part=63

echo "Initializing variables"
XFS_MOUNT=$(mktemp -d /tmp/xfs-XXXX)
EXT4_MOUNT=$(mktemp -d /tmp/ext4-XXXX)

XFS_IMAGE=rhel-guest-image-7.1-20150224.0-puppet.x86_64.qcow2
EXT4_IMAGE=$(echo $XFS_IMAGE | sed s/qcow2/ext4\.qcow2/ )

echo "Source image: " $XFS_IMAGE
echo "Destination image (ext4):" $EXT4_IMAGE

XFS_DEVICE=/dev/nbd0
EXT4_DEVICE=/dev/nbd1

qemu-nbd -d $XFS_DEVICE
qemu-nbd -d $EXT4_DEVICE

PARTITION_ID=p1
XFS_PARTITION=$XFS_DEVICE$PARTITION_ID
EXT4_PARTITION=$EXT4_DEVICE$PARTITION_ID

IMAGE_SIZE=$(qemu-img info $XFS_IMAGE |grep "virtual size"|cut -f 4 -d " "|cut -f 2 -d "(" )

qemu-nbd -c $XFS_DEVICE $XFS_IMAGE
echo "Source image will be accessible under parition $XFS_PARTITION"
mount $XFS_PARTITION $XFS_MOUNT
echo "Source image mounted under $XFS_MOUNT"


qemu-img create -f qcow2 $EXT4_IMAGE $IMAGE_SIZE
qemu-nbd -c $EXT4_DEVICE $EXT4_IMAGE
echo "Destination image $EXT4_IMAGE created with a size of $IMAGE_SIZE bytes"

echo "Creation of $EXT4_PARTITION. Please wait..."
parted -s -a optimal $EXT4_DEVICE mklabel gpt -- mkpart primary ext4 1 -1

echo "Making ext4 filesystem under $EXT4_PARTITION. Please wait..."
mkfs.ext4 $EXT4_PARTITION
echo "Ext4 filesystem created successfully. Partition is mounted under $EXT4_MOUNT"
mount $EXT4_PARTITION $EXT4_MOUNT


echo "Copying source files to destination images. Please wait..."
cp -a $XFS_MOUNT/* $EXT4_MOUNT

echo "Files copy completed"

XFS_UUID=$(blkid  -s UUID  $XFS_PARTITION |cut -f2 -d\")
EXT4_UUID=$(blkid  -s UUID  $EXT4_PARTITION |cut -f2 -d\")


echo "Replacing filesystem UUID in configuration files"
for file in /etc/fstab /boot/grub/grub.conf /boot/grub2/grub.cfg; do
	sed -i s/$XFS_UUID/$EXT4_UUID/g   $EXT4_MOUNT/$file 
done
echo "UUID replacements done"
echo "Disabling SELinux"
sed -i s/SELINUX=enforcing/SELINUX=disabled/g   $EXT4_MOUNT/etc/selinux/config






