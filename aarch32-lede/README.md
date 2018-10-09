# Installation procedure
```
mkdir bxc && cd bxc
wget https://github.com/haibochu/BonusCloud-Node/raw/mipsel-lede/aarch32-lede/bxc-start --no-check-certificate
chmod +x bxc-start
```
# Note
```
# wget: SSL support not available
opkg install wget
ln -sf /usr/bin/wget-ssl /bin/wget
# wget --no-check-certificate
```
# Run bxc-start for intial setup, bxc-stop & bxc-status will be created automaticly during setup.
```
./bxc-start # Start bxc client
./bxc-stop # Stop bxc client
./bxc-status # Status of bxc
```