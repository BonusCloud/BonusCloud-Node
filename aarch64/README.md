### install
Run as shell
```
wget https://raw.githubusercontent.com/BonusCloud/BonusCloud-Node/master/aarch64/install.sh -O install.sh&&sudo bash install.sh
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

