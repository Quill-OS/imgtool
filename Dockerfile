FROM debian:12

RUN apt-get -y update
RUN apt-get -y upgrade
RUN apt-get -y install fish openssl sudo kmod qemu-utils htop psmisc git parted udev fdisk make gcc bc u-boot-tools squashfs-tools wget

# https://stackoverflow.com/questions/30236342/debian-stretch-and-jessie-32-bit-libraries
RUN dpkg --add-architecture i386
RUN apt-get -y update
RUN apt-get -y install build-essential gcc-multilib libstdc++6:i386 libgcc1:i386 zlib1g:i386 libncurses5:i386

WORKDIR /home/build/inkbox/imgtool/

# Specify the command to run when the container starts
CMD ["/usr/bin/fish"]
