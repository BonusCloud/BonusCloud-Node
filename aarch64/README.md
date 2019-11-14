
[简体中文](README_zh.md)

### install
Run as shell
```
wget https://raw.githubusercontent.com/BonusCloud/BonusCloud-Node/master/aarch64/install.sh -O install.sh&&sudo bash install.sh
```
coding.net
```
wget https://bonuscloud.coding.net/p/BonusCloud-Node/d/BonusCloud-Node/git/raw/master/x86_64/install.sh -O install.sh&&sudo bash install.sh
```

JDCloud backup
```
wget https://bonuscloud-node.s3.cn-north-1.jdcloud-oss.com/aarch64/install.sh -O install.sh&&sudo bash install.sh
```
### remove
```
wget https://raw.githubusercontent.com/BonusCloud/BonusCloud-Node/master/aarch64/install.sh -O install.sh&&sudo bash install.sh remove
```

The system passed the test
- Armbian_5.62_Aml-s9xxx_Ubuntu_bionic_default_4.19.0-rc7_20181018
- NanoPi-Neo-Plus2
- PHICOMM N1

### bound

```
curl -H "Content-Type: application/json" -d '{"bcode":"xxxx-xxxxxxxx","email":"xxxx@xxxx"}' http://localhost:9017/bound
```
or use APP

### help

    -h       Print this and exit
    -i       Installation environment check and initialization
    -k       Install the k8s environment and the k8s components that"
             BonusCloud depends on
    -n       Install node management components
    -r       Fully remove bonuscloud plug-ins and components
    -s       Install teleport for remote debugging by developers
    -I       set interface name to you want
    -c       change kernel to compiled dedicated kernels,only "Phicomm N1
             and is danger!


