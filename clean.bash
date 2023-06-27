#!/bin/bash -x
qemu-nbd --disconnect /dev/nbd0
qemu-nbd --disconnect /dev/nbd0
qemu-nbd --disconnect /dev/nbd0

killall -9 qemu-nbd
killall -9 qemu-nbd
killall -9 qemu-nbd

umount -f /dev/nbd0
umount -f /dev/nbd0p1
umount -f /dev/nbd0p2
umount -f /dev/nbd0p3
umount -f /dev/nbd0p4

echo "Check manually in htop anyway..."
