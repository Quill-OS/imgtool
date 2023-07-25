#!/bin/bash -x
cp other/mkfs.conf /etc/mkfs.conf
cd /home/build/inkbox/
git clone https://github.com/Kobo-InkBox/kernel.git
cd /home/build/inkbox/imgtool
