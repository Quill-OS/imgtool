FROM debian:11

RUN apt-get -y update
RUN apt-get -y upgrade
RUN apt-get install -y fish openssl sudo kmod qemu-utils htop psmisc git

WORKDIR /home/build/inkbox/imgtool/

# Specify the command to run when the container starts
CMD ["/usr/bin/fish"]
