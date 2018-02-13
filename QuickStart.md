Quick start with CERN Centos 7
===============================

Tested with CC7 image on OpenStack VM (CC7 - x86_64 [2018-01-12]).

Running as root.

Preparation:

```
yum install -y git wget
wget https://get.docker.com -O /tmp/getdocker.sh
mkdir -p /var/lib/docker
bash /tmp/getdocker.sh

docker info | grep "Storage Driver"
#Storage Driver: devicemapper

# EOS citrine MGM needs a fully qualified hostname in the container, including network
docker network create demonet

# upstream is: https://github.com/AARNet/eos-afl.git
git clone https://github.com/cernbox/eos-afl.git
cd eos-afl
```

Building instrumented EOS and running the image:

```
./build.sh -b -i
docker run --privileged --cap-add SYS_PTRACE -it -h eos-afl.demonet --name eos-afl --net demonet eos-fuzz:afl /bin/bash 

# [in container]
yum install -y gdb
./eos-setup.sh
```

Fuzzing:

```
# [in container]
mkdir -p /results
afl-fuzz -m none -i /fuzz/mini -o /results/run1 eos
```
