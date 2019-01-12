### install

Download install.tar.gz 
```
wget https://github.com/qinghon/BonusCloud-Node/raw/master/aarch32/install.sh -O install.sh&&bash install.sh
```
The system passed the test:
- raspbian_3b+:raspbian_lite_latest: [Raspberrypi download link](https://downloads.raspberrypi.org/raspbian_lite_latest)
- NanoPi-M1-Plus

### bound

```
curl -H "Content-Type: application/json" -d '{"bcode":"xxxx-xxxxxxxx","email":"xxxx@xxxx"}' http://localhost:9017/bound
```
or use APP
