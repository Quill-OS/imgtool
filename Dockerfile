FROM debian:12

RUN apt-get -y update
RUN apt-get -y upgrade
RUN apt-get install -y fish openssl sudo kmod qemu-utils htop psmisc git parted udev fdisk make gcc bc u-boot-tools squashfs-tools wget

WORKDIR /home/build/inkbox/imgtool/

# Specify the command to run when the container starts
CMD ["/usr/bin/fish"]
