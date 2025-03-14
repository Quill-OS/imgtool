## Docker way
On Arch Linux, install Docker and start it:
```
sudo pacman -S docker-buildx docker nbd
sudo systemctl enable --now docker
```

Create the Docker image:
```
docker build -t inkbox_imgtool .
```

Before launching imgtool, run this:
```
sudo rmmod nbd
sudo modprobe nbd max_part=16
```

Run it (yes, imgtool should be at `/home/build/inkbox/imgtool/`):
```
docker run -it --rm --privileged --cap-add=ALL -v /home/build/inkbox/:/home/build/inkbox/ -v /dev:/dev inkbox_imgtool
```

You propably want your own keys; run this:
```
openssl genrsa -out private.pem 2048
openssl rsa -in private.pem -out public.pem -outform PEM -pubout
```

Then, run, for example:
```
./before_run.bash && ./clean.bash && KERNELDIR=/home/build/inkbox/kernel/ ./release.bash n306 /home/build/inkbox/imgtool/private.pem /home/build/inkbox/imgtool/public.pem root
```

Notes:
- If `/dev/nbd0p1` doesn't appear, it's bad

Links (that could help):
- https://www.tumblr.com/dummdida/117157045170/modprobe-in-a-docker-container
- https://superuser.com/questions/1329362/qemu-nbd-not-creating-partions
- https://forums.gentoo.org/viewtopic-t-822672.html
- https://serverfault.com/questions/828877/partx-dev-sdd-error-adding-partition-1
- https://unix.stackexchange.com/questions/319922/error-cant-have-a-partition-outside-the-disk-even-though-number-of-sectors
