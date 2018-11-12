#!/bin/sh

MIPSEL="https://github.com/hikaruchang/BonusCloud-Node/raw/master/openwrt-ipk/bonuscloud_0.2.2-6o-1_mipsel_24kec_dsp.ipk"

opkg_init(){
	opkg update
	opkg install curl wget ca-bundle ca-certificates liblzo ip6tables-extra kmod-ip6tables-extra
}


mipsel_ins(){
	opkg_init
	rm /tmp/bonuscloud*
	cd /tmp&&curl -L -k $MIPSEL -o bonuscloudmipsel.ipk
	opkg install /tmp/bonuscloudmipsel.ipk
}



echo "开始安装pandorabox版本插件----------------------------"
mipsel_ins
echo "安装结束，如果有报错，贴上报错信息"

