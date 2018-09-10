#!/bin/sh
# BxC-Node operation script for AM380 merlin firmware
# by sean.ley (ley@bonuscloud.io)

# load path environment in dbus databse
eval `dbus export bxc`

BXC_DIR="/koolshare/bxc"
BXC_CONF="$BXC_DIR/bxc.config"
BXC_NETWORK="/koolshare/bin/bxc-network"
BXC_WORKER="/koolshare/bin/bxc-worker"
BXC_SERVER="http://101.236.37.92"
BXC_TOOL="/koolshare/scripts/bxc-tool.sh"
BXC_PKG="bxc.tar.gz"

BXC_SSL_CA="/tmp/etc/bxc-network/ca.crt"
BXC_SSL_CRT="/tmp/etc/bxc-network/client.crt"
BXC_SSL_KEY="/tmp/etc/bxc-network/client.key"

source /koolshare/scripts/base.sh
source $BXC_CONF

log(){
	if [ "$LOG_DEBUG" == "true" ];then
		echo "【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】: $1 " >> /tmp/log-bxc
	fi
}

init(){
	pkg_install liblzo
	pkg_install libopenssl
	pkg_install libltdl
	pkg_install libcurl
	pkg_install libjson-c

	# Enable IPV6
	ipv6_enable

	# vpn env check
	vpn_env
}

vpn_env(){
	# vpn config file
	if [ ! -s $BXC_SSL_CA ];then
		if [ -s /koolshare/bxc/ca.crt ];then
			mkdir -p /tmp/etc/bxc-network
			cp -f /koolshare/bxc/ca.crt $BXC_SSL_CA > /dev/null 2>&1
		else
			log "ca.crt文件缺失，请卸载后解绑设备，并重新绑定设备。"
			exit 1
		fi
	fi

	if [ ! -s $BXC_SSL_CRT ];then
		if [ -s /koolshare/bxc/client.crt ];then
			mkdir -p /tmp/etc/bxc-network
			cp -f /koolshare/bxc/client.crt $BXC_SSL_CRT > /dev/null 2>&1
		else
			log "client.crt文件缺失，请卸载后解绑设备，并重新绑定设备。"
			exit 1
		fi
	fi

	if [ ! -s $BXC_SSL_KEY ];then
		if [ -s /koolshare/bxc/client.key ];then
			mkdir -p /tmp/etc/bxc-network
			cp -f /koolshare/bxc/client.key $BXC_SSL_KEY > /dev/null 2>&1
		else
			log "client.key文件缺失，请卸载后解绑设备，并重新绑定设备。"
			exit 1
		fi
	fi

	# vpn device
	modprobe tun
	[ ! -e /dev/net/tun ] && (mkdir -p /dev/net/ && mknod /dev/net/tun c 10 200)

	# /dev/shm permition
	chmod -R 777 /dev/shm/
}

ipv6_enable() {
	IPV6=`cat /proc/sys/net/ipv6/conf/all/disable_ipv6`
	[ $IPV6 -ne 0 ] && echo 0 > /proc/sys/net/ipv6/conf/all/disable_ipv6

	ip6tables -A INPUT -p tcp --dport 22 -j ACCEPT -i tun0
	ip6tables -A INPUT -p tcp --dport 8901 -j ACCEPT -i tun0
	ip6tables -A INPUT -p icmpv6 -j ACCEPT -i tun0
	ip6tables -A OUTPUT -p tcp --sport 22 -j ACCEPT
	ip6tables -A OUTPUT -p tcp --sport 8901 -j ACCEPT
	ip6tables -A OUTPUT -p icmpv6 -j ACCEPT
	ip6tables -A INPUT -p udp -j ACCEPT -i tun0
	ip6tables -A INPUT -p udp -j ACCEPT -i lo
	ip6tables -A OUTPUT -p udp -j ACCEPT
}

pkg_install() {
	# opkg 安装
	opkg_exist=`which opkg > /dev/null 2>&1;echo $?`
	if [ $opkg_exist -ne 0 ];then
		log "opkg not exist, run install with $BXC_TOOL"
		mkdir -p /tmp/opt && ln -s /tmp/opt /opt > /dev/null 2>&1
		chmod +x $BXC_TOOL && $BXC_TOOL && opkg update > /dev/null 2>&1
	fi

	# pkg 安装
	pkg_exist=`opkg list-installed | grep "$1" > /dev/null 2>&1;echo $?`
	if [ $pkg_exist -ne 0 ];then
		log "package $1 not exist, intall by opkg"
		opkg install $1 > /dev/null 2>&1
	fi
	
	# 安装检查
	pkg_exist=`opkg list-installed | grep "$1" > /dev/null 2>&1;echo $?`
	[ $pkg_exist -ne 0 ] && log "package $1 install failed by opkg"
}

status_bxc(){
	network_status=`ps | grep "bxc-network" | grep -v grep > /dev/null 2>&1; echo $?`
	worker_status=`ps | grep "bxc-worker" | grep -v grep > /dev/null 2>&1; echo $?`
	
	if [ $network_status == 0 ] && [ $worker_status == 0 ];then
		dbus set bxc_status="running"
		log "BxC-Node status is running: bxc-network status $network_status, bxc-worker status $worker_status"
	else
		dbus set bxc_status="stoped"
		log "BxC-Node status is stoped: bxc-network status $network_status, bxc-worker status $worker_status"
	fi
}

start_bxc(){
	status_bxc
	if [ $network_status -ne 0 ];then
		log "bxc-network start..."
		chmod +x $BXC_NETWORK && $BXC_NETWORK > /dev/null 2>&1 &
	fi
	if [ $worker_status -ne 0 ];then
		log "bxc-worker start..."
		chmod +x $BXC_WORKER && $BXC_WORKER > /dev/null 2>&1 &
	fi
	sleep 5
	status_bxc
	if [ $network_status -ne 0 ] || [ $worker_status -ne 0 ];then
		log "BxC-Node start failed."
		stop_bxc
	fi
}
stop_bxc(){
	log "BxC-Node stop with command: ps | grep -v grep | egrep 'bxc-network|bxc-worker' | awk '{print $1}' | xargs kill -9 > /dev/null 2>&1 "
	ps | grep -v grep | egrep 'bxc-network|bxc-worker' | awk '{print $1}' | xargs kill -9 > /dev/null 2>&1 
	sleep 3
    status_bxc
}
bound_bxc(){
	bcode=`dbus get bxc_input_bcode`
	mac=`dbus get bxc_wan_mac`

	curl -k -H "Content-Type: application/json" -d "{\"fcode\":\"$bcode\", \"mac_address\":\"$mac\"}" -w "$line\nstatus_code:"%{http_code}"\n" https://117.48.224.43/idb/dev > /koolshare/bxc/curl.res
	curl_code=`grep 'status_code' /koolshare/bxc/curl.res | awk -F: '{print $2}'`
	if [ -z $curl_code ];then
		dbus set bxc_bound_status="服务端没有响应绑定请求，请稍候再试"
		log 'curl -k -H "Content-Type: application/json" -d "{\"fcode\":\"$bcode\", \"mac_address\":\"$mac\"}" -w "$line\nstatus_code:"%{http_code}"\n" https://117.48.224.43/idb/dev > /koolshare/bxc/curl.res'
	elif [ "$curl_code"x == "200"x ];then
		echo -e `cat /koolshare/bxc/curl.res | /koolshare/scripts/bxc-json.sh | egrep "\"Cert\",\"key\"" | awk -F\" '{print $6}' | sed 's/"//g'` > $BXC_SSL_KEY
		echo -e `cat /koolshare/bxc/curl.res | /koolshare/scripts/bxc-json.sh | egrep "\"Cert\",\"cert\"" | awk -F\" '{print $6}' | sed 's/"//g'` > $BXC_SSL_CRT
		echo -e `cat /koolshare/bxc/curl.res | /koolshare/scripts/bxc-json.sh | egrep "\"Cert\",\"ca\"" | awk -F\" '{print $6}' | sed 's/"//g'` > $BXC_SSL_CA
		if [ ! -s $BXC_SSL_KEY ];then
			dbus set bxc_bound_status="获取key文件失败"
			log 'no client key file'
		elif [ ! -s $BXC_SSL_CRT ];then
			dbus set bxc_bound_status="获取crt文件失败"
			log 'no client crt file'
		elif [ ! -s $BXC_SSL_CA ];then
			dbus set bxc_bound_status="获取ca文件失败"
			log 'no client ca file'
		else
			dbus set bxc_bound_status="success"
			dbus set bxc_bcode="$bcode"
		fi
	else
		cat /koolshare/bxc/curl.res | /koolshare/scripts/bxc-json.sh | egrep '\["details"\]' > /dev/null
		if [ $? -eq 0 ];then
			fail_detail=`cat /koolshare/bxc/curl.res | /koolshare/scripts/bxc-json.sh | egrep '\["details"\]' | awk -F\" '{print $4}' | sed 's/"//g'`
			dbus set bxc_bound_status="$fail_detail"
			log "bound failed with server response: $fail_detail"
		else
			dbus set bxc_bound_status="服务端没有响应绑定请求，请稍候再试"
			log 'curl -k -H "Content-Type: application/json" -d "{\"fcode\":\"$bcode\", \"mac_address\":\"$mac\"}" -w "$line\nstatus_code:"%{http_code}"\n" https://117.48.224.43/idb/dev > /koolshare/bxc/curl.res'
		fi
	fi

	# 备份绑定信息（邀请码 + 证书文件）
	cp -f /tmp/etc/bxc-network/* /koolshare/bxc/
	echo $bcode > /koolshare/bxc/bcode

	# 清理临时文件
	# rm -f /koolshare/bxc/curl.res
}
booton_bxc(){
	# 开启开机自启动
	if [ ! -L "/koolshare/init.d/S97bxc.sh" ]; then 
        ln -sf /koolshare/scripts/bxc.sh /koolshare/init.d/S97bxc.sh
    fi
    [ ! -L "/koolshare/init.d/S97bxc.sh" ] && log "BxC-Node start onboot enable failed"
    dbus set bxc_onboot="yes"
}
bootoff_bxc(){
	# 关闭开机自启动
    rm -f /koolshare/init.d/S97bxc.sh
    [ -L "/koolshare/init.d/S97bxc.sh" ] && log "BxC-Node start onboot disable failed"
    dbus set bxc_onboot="no"
}

update_bxc(){
	stop_bxc

	log "Dowanlod update package..."
	cd /tmp/ && rm -fr /tmp/bxc*
	wget -q -t 3 -O $BXC_PKG "https://raw.githubusercontent.com/BonusCloud/BxC-Node/master/bxc.tar.gz" > /dev/null 2>&1
	if [ -s $BXC_PKG ];then
		tar -zxf $BXC_PKG
		log "Copy update files..."
		cp -rf /tmp/bxc/scripts/* /koolshare/scripts/
		cp -rf /tmp/bxc/bin/* /koolshare/bin/
		cp -rf /tmp/bxc/webs/* /koolshare/webs/
		cp -rf /tmp/bxc/res/* /koolshare/res/
		cp -rf /tmp/bxc/bxc/* /koolshare/bxc/
		cp -rf /tmp/bxc/install.sh /koolshare/scripts/bxc_install.sh
		cp -rf /tmp/bxc/uninstall.sh /koolshare/scripts/uninstall_bxc.sh
		chmod a+x /koolshare/scripts/bxc*

		log "Version infomation update..."
		CUR_VERSION=`cat $BXC_DIR/version`
		dbus set bxc_local_version="$CUR_VERSION"
		dbus set softcenter_module_bxc_version="$CUR_VERSION"

		rm -rf /tmp/bxc* >/dev/null 2>&1
	else
		log "Dowanlod update package failed: wget -q -t 3 -O $BXC_PKG 'https://raw.githubusercontent.com/BonusCloud/BxC-Node/master/bxc.tar.gz'"
	fi
}

if [ -z $1 ];then
	ACTION=`dbus get bxc_option`
else
	ACTION=$1
fi

log "bxc.sh $ACTION"

case $ACTION in
start)
	init
	start_bxc
	;;
stop)
	stop_bxc
	;;
restart)
	stop_bxc
	start_bxc
	;;
status)
	status_bxc
	;;
bound)
	bound_bxc
	;;
booton)
	booton_bxc
	;;
bootoff)
	bootoff_bxc
	;;
update)
	update_bxc
	;;
*)
	exit 1
    ;;
esac
dbus set bxc_option=""