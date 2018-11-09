#!/bin/sh

ARM="https://raw.githubusercontent.com/hikaruchang/BonusCloud-Node/master/openwrt-ipk/bonuscloud_0.2.2-6o-1_arm_cortex-a9.ipk"
MIPS="https://github.com/hikaruchang/BonusCloud-Node/raw/master/openwrt-ipk/bonuscloud_0.2.2-6o-1_mips_24kc.ipk"
MIPSEL="https://github.com/hikaruchang/BonusCloud-Node/raw/master/openwrt-ipk/bonuscloud_0.2.2-6o-1_mipsel_24kc.ipk"

opkg_init(){
	opkg update
	opkg install curl ca-bundle ca-certificates liblzo 
}

arm_ins(){
	opkg_init
	rm /tmp/bonuscloud*
	cd /tmp&&curl -L -k $ARM -o bonuscloudarm.ipk
	opkg install /tmp/bonuscloudarm.ipk
}
mips_ins(){
	opkg_init
	rm /tmp/bonuscloud*
	cd /tmp&&curl -L -k $MIPS -o bonuscloudmips.ipk
	opkg install /tmp/bonuscloudmips.ipk
}
mipsel_ins(){
	opkg_init
	rm /tmp/bonuscloud*
	cd /tmp&&curl -L -k $MIPSEL -o bonuscloudmipsel.ipk
	opkg install /tmp/bonuscloudmipsel.ipk
}


cpu=`uname -m`
if [[ -n ""$cpu"|grep arm" ]]; then
	#statements
	echo -e " the cpu is\033[31m $cpu\033[0m ,install arm"
	arm_ins
elif [[ -n ""$cpu"|grep mips" ]]; then
	
	judge_k2p=`uname -n |grep K2P`
	if [[ -n "$judge_k2p" ]]; then
		
		echo "device is K2P ,install mipsel"
		echo "K2P can not install for now,because have more problem ,but I try it"
        mipsel_ins

	else
		echo -e " the cpu is\033[31m $cpu\033[0m ,install mips"
		mips_ins
	fi
elif [[ -n ""$cpu"|grep mipsel" ]]; then
	mipsel_ins
else
	echo "you device can not install the package"
fi


