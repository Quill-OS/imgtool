FROM debian:11

RUN apt-get update && apt-get upgrade && apt-get install -y openssl sudo kmod

WORKDIR /home/build/inkbox/imgtool/

# Specify the command to run when the container starts
CMD ["/bin/bash"]
