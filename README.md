On Arch, install docker and start it:
```
sudo pacman -S docker-buildx docker
sudo systemctl enable --now docker
```

Create the docker image:
```
docker build -t inkbox_imgtool .
```

Run it ( yes, imgtool should be at `/home/build/inkbox/imgtool/` ):

```
docker run -it --rm --privileged --cap-add=ALL -v /dev:/dev -v /lib/modules:/lib/modules -v "$(pwd)":/home/build/inkbox/imgtool/ inkbox_imgtool
```

You propably want your own keys, run this:
```
openssl genrsa -out private.pem 2048
openssl rsa -in private.pem -out public.pem -outform PEM -pubout
```

Stupid debian:
```
export PATH="/sbin/:$PATH"
```

and run, for example:
```
./release.bash n306 public.pem root
```

links:
- https://www.tumblr.com/dummdida/117157045170/modprobe-in-a-docker-container
