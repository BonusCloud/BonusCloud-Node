
[简体中文](README_zh.md)

### install
Run as shell
```
wget https://raw.githubusercontent.com/BonusCloud/BonusCloud-Node/master/aarch32/install.sh -O install.sh&&sudo bash install.sh
```
coding.net
```
wget https://bonuscloud.coding.net/p/BonusCloud-Node/d/BonusCloud-Node/git/raw/master/x86_64/install.sh -O install.sh&&sudo bash install.sh
```
JDCloud backup
```
wget https://bonuscloud-node.s3.cn-north-1.jdcloud-oss.com/aarch32/install.sh -O install.sh&&sudo bash install.sh
```
### remove
```
wget https://raw.githubusercontent.com/BonusCloud/BonusCloud-Node/master/aarch32/install.sh -O install.sh&&sudo bash install.sh remove
```

The system passed the test:
- raspbian_3b+:raspbian_lite_latest: [Raspberrypi download link](https://downloads.raspberrypi.org/raspbian_lite_latest)


- NanoPi-M1-Plus

### bound

```
curl -H "Content-Type: application/json" -d '{"bcode":"xxxx-xxxxxxxx","email":"xxxx@xxxx"}' http://localhost:9017/bound
```
or use APP

### help

    -h       Print this and exit
     └── -L        Specify help language,like -h -L zh_cn
    -b       bound for command
    -d       Only install docker
    -c       change kernel to compiled dedicated kernels,only "Phicomm N1" and is danger!
    -i       Installation environment check and initialization
    -k       Install the k8s environment and the k8s components that BonusCloud depends on
    -n       Install node management components
    -r       Fully remove bonuscloud plug-ins and components
    -s       Install teleport for remote debugging by developers
    -t       Show all plugin running status
     └── -D        Show Disk status and info
    -e       Set interfaces name to ethx,only x86_64 and using grub
    -g       Install network job only"
     └── -H        Set ip for container"
     └── -M        skip bxc-net docker image download"
     └── -e        export only network job certificate"
     └── -i        import only network job certificate"
    -A       Install all task component"
    -D       Don't set disk for node program
    -I       set interface name to you want
