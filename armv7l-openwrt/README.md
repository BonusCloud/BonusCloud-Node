# 安装
```
wget https://github.com/hikaruchang/BonusCloud-Node/raw/openwrt/armv7l-openwrt/bxc/bxc-start --no-check-certificate
chmod +x bxc-start
rm -rf bxc-start
```
# 注
```
# wget: SSL support not available
opkg install wget
# wget --no-check-certificate
# 找不到TUN设备
opkg install kmod-tun
```
# 开启和关闭
```
./bxc-start # Start bxc client
./bxc-stop # Stop bxc client
./bxc-status # Status of bxc
```
# 设备
```
Phicomm K3
```
