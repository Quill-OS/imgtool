## Docker way
On Arch, install docker and start it:
```
sudo pacman -S docker-buildx docker nbd
sudo systemctl enable --now docker
```

Create the docker image:
```
docker build -t inkbox_imgtool .
```

Before running, run this:
```
sudo rmmod nbd && sudo modprobe nbd max_part=16
```

Run it ( yes, imgtool should be at `/home/build/inkbox/imgtool/` ):
```
docker run -it --rm --privileged --cap-add=ALL -v /home/build/inkbox/:/home/build/inkbox/ -v /dev:/dev inkbox_imgtool
```

You propably want your own keys, run this ( if yes, you need to replace the private key in kernel manually, in key.sqsh ):
```
openssl genrsa -out private.pem 2048
openssl rsa -in private.pem -out public.pem -outform PEM -pubout
```

and run, for example:
```
./before_run.bash && ./clean.bash && KERNELDIR=/home/build/inkbox/kernel/ ./release.bash n306 /home/build/inkbox/imgtool/private.pem root
```

notes:
- if `/dev/nbd0p1` doesn't appear, it's bad

links ( that could help ):
- https://www.tumblr.com/dummdida/117157045170/modprobe-in-a-docker-container
- https://superuser.com/questions/1329362/qemu-nbd-not-creating-partions
- https://forums.gentoo.org/viewtopic-t-822672.html
- https://serverfault.com/questions/828877/partx-dev-sdd-error-adding-partition-1
- https://unix.stackexchange.com/questions/319922/error-cant-have-a-partition-outside-the-disk-even-though-number-of-sectors
