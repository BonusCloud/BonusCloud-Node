### install
Run as shell
```
wget https://raw.githubusercontent.com/BonusCloud/BonusCloud-Node/master/x86_64/install.sh -O install.sh&&sudo bash install.sh
```
### remove
```
wget https://raw.githubusercontent.com/BonusCloud/BonusCloud-Node/master/x86_64/install.sh -O install.sh&&sudo bash install.sh remove
```

The system passed the test
- ubuntu-18.04.02 4.15.0-45-generic [Download](https://www.ubuntu.com/download/server)
- debian-9.9 4.9.168-1 (2019-04-12) [Download](https://www.debian.org/distrib/)

### bound
```
curl -H "Content-Type: application/json" -d '{"bcode":"xxxx-xxxxxxxx","email":"xxxx@xxxx"}' http://localhost:9017/bound
```
or use APP

### help

    -h             Print this and exit
    -i             Installation environment check and initialization
    -k             Install the k8s environment and the k8s components that
                   BonusCloud depends on
    -n             Install node management components
    -r             Fully remove bonuscloud plug-ins and components
    -s             Install salt-minion for remote debugging by developers
    -I Interface   set interface name to you want
    -c             change kernel to compiled dedicated kernels,only "Phicomm N1"
                   and is danger!
    -e             set interfaces name to ethx
