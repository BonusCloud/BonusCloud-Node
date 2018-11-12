#!/bin/sh

ARM="https://raw.githubusercontent.com/hikaruchang/BonusCloud-Node/master/openwrt-ipk/bonuscloud_0.2.2-6o-1_arm_cortex-a9.ipk"
MIPS="https://github.com/hikaruchang/BonusCloud-Node/raw/master/openwrt-ipk/bonuscloud_0.2.2-6o-1_mips_24kc.ipk"
MIPSEL="https://github.com/hikaruchang/BonusCloud-Node/raw/master/openwrt-ipk/bonuscloud_0.2.2-6o-1_mipsel_24kc.ipk"

opkg_init(){
	opkg update
	opkg install curl wget ca-bundle ca-certificates liblzo ip6tables-extra kmod-ip6tables-extra
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

defult_ins(){
	echo -e " \033[31m 注意少部分路由器如K2P,新路由3会判断失败，请手动加上参数执行\033[0m "
	echo "比如\n bonuscloudinstall.sh mipsel \n"
	echo "装错了不要紧，卸载后重新来就好"
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
}

case $* in
	mips )
		mips_ins
		;;
	mipsel )
		mipsel_ins
		;;
	arm )
		arm_ins
		;;
	* )
		defult_ins
		;;

esac
