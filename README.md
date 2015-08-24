# qcow-utils


Utility script to manipulate qcow images on Linux.

- convert-qcow-image-from-xfs-to-ext4.sh : Converts an XFS qcow image into ext-4 preserving user permissions.
  This script generates a new UUID for the newly created partition and updates fstab and grub configuration.
