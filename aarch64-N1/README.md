# BonusCloud-Node-N1

Tested on N1 with Armbian_5.44_S9xxx_Ubuntu_bionic_3.14.29_server_20180729.img.xz
```
# Installation procedure
mkdir bxc && cd bxc
wget -O bxc.sh https://github.com/BonusCloud/BonusCloud-Node/raw/master/aarch64-N1/bxc.sh
chmod +x bxc.sh

# Run "bxc.sh init" for initial setup (ONLY need run ONE time)
./bxc.sh init

# Run "bxc.sh start" to start BonusCloud-Node
./bxc.sh start

# Run "bxc.sh stop" to stop BonusCloud-Node
./bxc.sh stop

# Run "bxc.sh enable" to enable BonusCloud-Node auto start
./bxc.sh enable

# Run "bxc.sh disable" to disable BonusCloud-Node auto start
./bxc.sh disable

```
