#!/usr/bin/env bash

# Must be root
mntdir=

usage () {
    echo "sudo $0 <ext4 image file> <fitimage>"
    exit 1
}

panic () {
    echo "$1"
    if mountpoint "$mntdir"; then umount "$mntdir"; fi
    exit 1
}

[ "$#" -lt 2 ] && usage

file="$1"
mntdir=$(mktemp -d)
echo "Mount $file on $mntdir"
mount "$IMAGE" "$mntdir" || panic "Mount of $file failed"
rm -f "$mntdir"/boot/fitImage*
install -m 0644 -o root -g root "$2" "$mntdir"/boot || panic "Install failed"
umount "$mntdir"
rmdir "$mntdir"
e2fsck -p -f "$file"
