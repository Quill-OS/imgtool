On Arch, install docker and start it:
```
sudo pacman -S docker-buildx docker
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
docker run -it --rm --privileged --cap-add=ALL -v /home/build/inkbox/:/home/build/inkbox/ inkbox_imgtool
```

You propably want your own keys, run this:
```
openssl genrsa -out private.pem 2048
openssl rsa -in private.pem -out public.pem -outform PEM -pubout
```

and run, for example:
```
./before_run.bash && ./clean.bash && KERNELDIR=/home/build/inkbox/ ./release.bash n306 public.pem root
```

notes:
- if `/dev/nbd0p1` doesn't appear, try a fev times more...

links:
- https://www.tumblr.com/dummdida/117157045170/modprobe-in-a-docker-container
