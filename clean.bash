#!/bin/bash -x
qemu-nbd --disconnect /dev/nbd0
qemu-nbd --disconnect /dev/nbd0
qemu-nbd --disconnect /dev/nbd0

killall -9 qemu-nbd
killall -9 qemu-nbd
killall -9 qemu-nbd

umount -l -f /tmp/inkbox-*/*
umount -l -f /dev/nbd0
umount -l -f /dev/nbd0p1
umount -l -f /dev/nbd0p2
umount -l -f /dev/nbd0p3
umount -l -f /dev/nbd0p4

# Sooo important...
rm -rf out/

echo "Check manually in htop anyway..."
