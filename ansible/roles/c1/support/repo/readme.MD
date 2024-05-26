Rows needed in `source.list` to use the repo that has been setup.
```
deb http://203.0.113.2/repo/deb.debian.org/debian bookworm main non-free-firmware
deb http://203.0.113.2/repo/security.debian.org/debian-security bookworm-security main non-free-firmware
```

Registry can be used on port 5000
```
~$ sudo docker pull 203.0.113.2:5000/bind9
```

Random files that need to the root of the website be added can be added to `<ansible-home-dir>/apt-mirror/generic-data/`