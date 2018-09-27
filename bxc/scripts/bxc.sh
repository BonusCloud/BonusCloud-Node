#!/bin/sh
# BxC-Node operation script for AM380 merlin firmware
# by sean.ley (ley@bonuscloud.io)

# load path environment in dbus databse
eval `dbus export bxc`
alias echo_date="echo [$(TZ=UTC-8 date -R '+%Y-%m-%d %H:%M:%S')] "

source /koolshare/scripts/base.sh
source /koolshare/bxc/bxc.config
BXC_CONF="/koolshare/bxc/bxc.config"

logdebug(){
  if [ "$LOG_LEVEL"x == "debug"x ];then
  	if [ "$LOG_MODE"x == "syslog"x ];then
    	logger -c "INFO: $1" -t bonuscloud-node > /dev/null 2>&1
    elif [ "$LOG_MODE"x == "file"x ];then
    	echo "[`TZ=UTC-8 date -R '+%Y-%m-%d %H:%M:%S')`] INFO: $1" >> $LOG_FILE
  	fi
  fi
}

logerr(){
  if [ "$LOG_LEVEL"x == "error"x ] || [ "$LOG_LEVEL"x == "debug"x ];then
    if [ "$LOG_MODE"x == "syslog"x ];then
    	logger -c "ERROR: $1" -t bonuscloud-node > /dev/null 2>&1
    elif [ "$LOG_MODE"x == "file"x ];then
    	echo "[`TZ=UTC-8 date -R '+%Y-%m-%d %H:%M:%S')`] EROOR $1" >> $LOG_FILE
  	fi
  fi
}

init(){
	rm -f /tmp/log-bxc > /dev/null 2>&1
	opkg_install
	pkg_install 
	ipv6_enable
	vpn_env
}

vpn_env(){
	# vpn config file
	if [ ! -s $BXC_SSL_CA ];then
		if [ -s /koolshare/bxc/ca.crt ];then
			logdebug "/koolshare/bxc/ca.crt exist, copy to $BXC_SSL_CA"
			mkdir -p /tmp/etc/bxc-network
			cp -f /koolshare/bxc/ca.crt $BXC_SSL_CA > /dev/null 2>&1
		else
			logerr "ca.crt file not exist, please uninstall app and unbound device, reinstall and bound again."
			exit 1
		fi
	fi

	if [ ! -s $BXC_SSL_CRT ];then
		if [ -s /koolshare/bxc/client.crt ];then
			logdebug "/koolshare/bxc/client.crt exist, copy to $BXC_SSL_CRT"
			mkdir -p /tmp/etc/bxc-network
			cp -f /koolshare/bxc/client.crt $BXC_SSL_CRT > /dev/null 2>&1
		else
			logerr "client.crt file not exist, please uninstall app and unbound device, reinstall and bound again."
			exit 1
		fi
	fi

	if [ ! -s $BXC_SSL_KEY ];then
		if [ -s /koolshare/bxc/client.key ];then
			logdebug "/koolshare/bxc/client.key exist, copy to $BXC_SSL_KEY"
			mkdir -p /tmp/etc/bxc-network
			cp -f /koolshare/bxc/client.key $BXC_SSL_KEY > /dev/null 2>&1
		else
			logerr "client.key file not exist, please uninstall app and unbound device, reinstall and bound again."
			exit 1
		fi
	fi

	# module
	modprobe tun > /dev/null 2>&1
	mod_exist=`lsmod | grep "tun" > /dev/null 2>&1;echo $?`
	if [ $mod_exist -eq 0 ];then
		logdebug "modprobe tun success"
	else
		logerr "modprobe tun failed, exit."
		exit 1
	fi

	# device
	if [ ! -e /dev/net/tun ];then
		logdebug "/dev/net/tun not exist, mkdir -p /dev/net/ && mknod /dev/net/tun c 10 200"
		mkdir -p /dev/net/ && mknod /dev/net/tun c 10 200
		if [ ! -e /dev/net/tun ];then
			logerr "/dev/net/tun create failed, exit."
			exit 1
		fi
	fi

	# /dev/shm permition
	if [ -d /dev/shm ];then
		logdebug "/dev/shm exist, chmod -R 777 /dev/shm/"
		chmod -R 777 /dev/shm/
	else
		logerr "device /dev/shm not exist, exit."
		exit 1
	fi

	# user nobody
	user_exist=`grep -e "^nobody:" /etc/passwd > /dev/null 2>&1;echo $?`
	if [ $user_exist -ne 0 ];then
		logdebug "append /etc/passwd 'nobody:x:65534:65534:nobody:/dev/null:/dev/null'"
		echo "nobody:x:65534:65534:nobody:/dev/null:/dev/null" >> /etc/passwd
	else
		logdebug "nobody exist /etc/passwd: `grep -e '^nobody:' /etc/passwd`"
	fi
	group_exist=`grep -e "^nobody:" /etc/group > /dev/null 2>&1;echo $?`
	if [ $group_exist -ne 0 ];then
		logdebug "append /etc/group 'nobody:x:65534:'"
		echo "nobody:x:65534:" >> /etc/group
	else
		logdebug "nobody exist /etc/group: `grep -e '^nobody:' /etc/group`"
	fi

	# ipv6 route check
	exist=`ip -6 route show table local | grep "local ::1 via :: dev lo" > /dev/null 2>&1;echo $?`
	if [ $exist -ne 0 ];then
		logerr "route \"local ::1 via :: dev lo\" note exist, restoring..."
		ip -6 addr del ::1/128 dev lo > /dev/null 2>&1
		ip -6 addr add ::1/128 dev lo > /dev/null 2>&1
	else
		logdebug "route \"local ::1 via :: dev lo\" already exist"
	fi

	tun0_ipaddr=`ip -6  addr show dev tun0 | grep "inet6" | awk '{print $2}'`
	if [ -n "$tun0_ipaddr" ];then
		iprefix=`echo $tun0_ipaddr | awk -F/ '{print $1}'`
		exist=`ip -6 route show table local | grep "local $iprefix via :: dev lo" > /dev/null 2>&1;echo $?`
		if [ $exist -ne 0 ];then
			logerr "route \"local $iprefix via :: dev lo\" note exist, restoring..."
			ip -6 addr del $tun0_ipaddr dev lo > /dev/null 2>&1
			ip -6 addr add $tun0_ipaddr dev lo > /dev/null 2>&1
		else
			logdebug "route \"local $iprefix via :: dev lo\" already exist"
		fi
	else
		logerr "get tun0_ipaddr failed: ip -6 addr show dev tun0 | grep \"inet6\" | awk '{print $2}'"
	fi
}

ipv6_enable() {
	# enable ifconfig ipv6
	IPV6=`cat /proc/sys/net/ipv6/conf/all/disable_ipv6`
	logdebug "/proc/sys/net/ipv6/conf/all/disable_ipv6 value is $IPV6"
	if [ $IPV6 -ne 0 ];then
		logdebug "echo 0 > /proc/sys/net/ipv6/conf/all/disable_ipv6"
		echo 0 > /proc/sys/net/ipv6/conf/all/disable_ipv6
	fi

	# check ip6tables
	ip6tables_exist=`which ip6tables > /dev/null 2>&1;echo $?`
	if [ $ip6tables_exist -ne 0 ];then
		logerr "ip6tables not exist, exit"
		exit 1
	fi

	# acl tcp 8901
	acl_exist=`ip6tables -C INPUT -p tcp --dport 8901 -j ACCEPT -i tun0 > /dev/null 2>&1;echo $?`
	if [ $acl_exist -ne 0 ];then
		logdebug "add: ip6tables -I INPUT -p tcp --dport 8901 -j ACCEPT -i tun0"
		ip6tables -I INPUT -p tcp --dport 8901 -j ACCEPT -i tun0 > /dev/null 2>&1
		check_exist=`ip6tables -C INPUT -p tcp --dport 8901 -j ACCEPT -i tun0 > /dev/null 2>&1;echo $?`
		if [ $check_exist -ne 0 ];then
			logerr "failed add: ip6tables -I INPUT -p tcp --dport 8901 -j ACCEPT -i tun0"
		else
			logdebug "success add: ip6tables -I INPUT -p tcp --dport 8901 -j ACCEPT -i tun0"
		fi
	else
		logdebug "acl exist: ip6tables -I INPUT -p tcp --dport 8901 -j ACCEPT -i tun0 "
	fi

	acl_exist=`ip6tables -C OUTPUT -p tcp --sport 8901 -j ACCEPT > /dev/null 2>&1;echo $?`
	if [ $acl_exist -ne 0 ];then
		logdebug "add: ip6tables -I OUTPUT -p tcp --sport 8901 -j ACCEPT"
		ip6tables -I OUTPUT -p tcp --sport 8901 -j ACCEPT > /dev/null 2>&1
		check_exist=`ip6tables -C OUTPUT -p tcp --sport 8901 -j ACCEPT > /dev/null 2>&1;echo $?`
		if [ $check_exist -ne 0 ];then
			logerr "failed add: ip6tables -I OUTPUT -p tcp --sport 8901 -j ACCEPT"
		else
			logdebug "success add: ip6tables -I OUTPUT -p tcp --sport 8901 -j ACCEPT"
		fi
	else
		logdebug "acl exist: ip6tables -I OUTPUT -p tcp --sport 8901 -j ACCEPT"
	fi

	# acl icmpv6
	acl_exist=`ip6tables -C INPUT -p icmpv6 -j ACCEPT -i tun0 > /dev/null 2>&1;echo $?`
	if [ $acl_exist -ne 0 ];then
		logdebug "add: ip6tables -I INPUT -p icmpv6 -j ACCEPT -i tun0"
		ip6tables -I INPUT -p icmpv6 -j ACCEPT -i tun0 > /dev/null 2>&1
		check_exist=`ip6tables -C INPUT -p icmpv6 -j ACCEPT -i tun0 > /dev/null 2>&1;echo $?`
		if [ $check_exist -ne 0 ];then
			logerr "failed add: ip6tables -I INPUT -p icmpv6 -j ACCEPT -i tun0"
		else
			logdebug "success add: ip6tables -I INPUT -p icmpv6 -j ACCEPT -i tun0"
		fi
	else
		logdebug "acl exist: ip6tables -I INPUT -p icmpv6 -j ACCEPT -i tun0"
	fi

	acl_exist=`ip6tables -C OUTPUT -p icmpv6 -j ACCEPT > /dev/null 2>&1;echo $?`
	if [ $acl_exist -ne 0 ];then
		logdebug "add: ip6tables -I OUTPUT -p icmpv6 -j ACCEPT"
		ip6tables -I OUTPUT -p icmpv6 -j ACCEPT > /dev/null 2>&1
		check_exist=`ip6tables -C OUTPUT -p icmpv6 -j ACCEPT > /dev/null 2>&1;echo $?`
		if [ $check_exist -ne 0 ];then
			logerr "failed add: ip6tables -I OUTPUT -p icmpv6 -j ACCEPT"
		else
			logdebug "success add: ip6tables -I OUTPUT -p icmpv6 -j ACCEPT"
		fi
	else
		logdebug "acl exist: ip6tables -I OUTPUT -p icmpv6 -j ACCEPT"
	fi
	
	# acl udp
	acl_exist=`ip6tables -C INPUT -p udp -j ACCEPT -i tun0 > /dev/null 2>&1;echo $?`
	if [ $acl_exist -ne 0 ];then
		logdebug "add: ip6tables -I INPUT -p udp -j ACCEPT -i tun0"
		ip6tables -I INPUT -p udp -j ACCEPT -i tun0 > /dev/null 2>&1
		check_exist=`ip6tables -C INPUT -p udp -j ACCEPT -i tun0 > /dev/null 2>&1;echo $?`
		if [ $check_exist -ne 0 ];then
			logerr "failed add: ip6tables -I INPUT -p udp -j ACCEPT -i tun0"
		else
			logdebug "success add: ip6tables -I INPUT -p udp -j ACCEPT -i tun0"
		fi
	else
		logdebug "acl exist: ip6tables -I INPUT -p udp -j ACCEPT -i tun0"
	fi

	acl_exist=`ip6tables -C INPUT -p udp -j ACCEPT -i lo > /dev/null 2>&1;echo $?`
	if [ $acl_exist -ne 0 ];then
		logdebug "add: ip6tables -I INPUT -p udp -j ACCEPT -i lo"
		ip6tables -I INPUT -p udp -j ACCEPT -i lo > /dev/null 2>&1
		check_exist=`ip6tables -C INPUT -p udp -j ACCEPT -i lo > /dev/null 2>&1;echo $?`
		if [ $check_exist -ne 0 ];then
			logerr "failed add: ip6tables -I INPUT -p udp -j ACCEPT -i lo"
		else
			logdebug "success add: ip6tables -I INPUT -p udp -j ACCEPT -i lo"
		fi
	else
		logdebug "acl exist: ip6tables -I INPUT -p udp -j ACCEPT -i lo"
	fi

	acl_exist=`ip6tables -C OUTPUT -p udp -j ACCEPT > /dev/null 2>&1;echo $?`
	if [ $acl_exist -ne 0 ];then
		logdebug "add: ip6tables -I OUTPUT -p udp -j ACCEPT"
		ip6tables -I OUTPUT -p udp -j ACCEPT > /dev/null 2>&1
		check_exist=`ip6tables -C OUTPUT -p udp -j ACCEPT > /dev/null 2>&1;echo $?`
		if [ $check_exist -ne 0 ];then
			logerr "failed add: ip6tables -I OUTPUT -p udp -j ACCEPT"
		else
			logdebug "success add: ip6tables -I OUTPUT -p udp -j ACCEPT"
		fi
	else
		logdebug "acl exist: ip6tables -I OUTPUT -p udp -j ACCEPT"
	fi

	# ipv4 acl tcp 80,443
	acl_exist=`iptables -C INPUT -p tcp --match multiport --sports 80,443,8080 -j ACCEPT > /dev/null 2>&1;echo $?`
	if [ $acl_exist -ne 0 ];then
		logdebug "add: iptables -I INPUT -p tcp --match multiport --sports 80,443,8080 -j ACCEPT"
		iptables -I INPUT -p tcp --match multiport --sports 80,443,8080 -j ACCEPT > /dev/null 2>&1
		check_exist=`iptables -C INPUT -p tcp --match multiport --sports 80,443,8080 -j ACCEPT > /dev/null 2>&1;echo $?`
		if [ $check_exist -ne 0 ];then
			logerr "failed add: iptables -I INPUT -p tcp --match multiport --sports 80,443,8080 -j ACCEPT"
		else
			logdebug "success add: iptables -I INPUT -p tcp --match multiport --sports 80,443,8080 -j ACCEPT"
		fi
	else
		logdebug "acl exist: iptables -I INPUT -p tcp --match multiport --sports 80,443,8080 -j ACCEPT"
	fi

	acl_exist=`iptables -C OUTPUT -p tcp --match multiport --dports 80,443,8080 -j ACCEPT > /dev/null 2>&1;echo $?`
	if [ $acl_exist -ne 0 ];then
		logdebug "add: iptables -I OUTPUT -p tcp --match multiport --dports 80,443,8080 -j ACCEPT"
		iptables -I OUTPUT -p tcp --match multiport --dports 80,443,8080 -j ACCEPT > /dev/null 2>&1
		check_exist=`iptables -C OUTPUT -p tcp --match multiport --dports 80,443,8080 -j ACCEPT > /dev/null 2>&1;echo $?`
		if [ $check_exist -ne 0 ];then
			logerr "failed add: iptables -I OUTPUT -p tcp --match multiport --dports 80,443,8080 -j ACCEPT"
		else
			logdebug "success add: iptables -I OUTPUT -p tcp --match multiport --dports 80,443,8080 -j ACCEPT"
		fi
	else
		logdebug "acl exist: iptables -I OUTPUT -p tcp --match multiport --dports 80,443,8080 -j ACCEPT"
	fi
}

opkg_install() {
	opkg_exist=`which opkg > /dev/null 2>&1;echo $?`
	if [ $opkg_exist -ne 0 ];then
		logdebug "opkg not found, install opkg: /koolshare/scripts/bxc-tool.sh"
		mkdir -p /tmp/opt && ln -s /tmp/opt /opt > /dev/null 2>&1
		wget -t 3 -T 3 -O /koolshare/scripts/bxc-opkg-install.sh $ENTWARE_INSTALL_URL > /dev/null 2>&1
		if [ -s /koolshare/scripts/bxc-opkg-install.sh ];then
			logdebug "install script download finished, install opkg..."
			chmod +x /koolshare/scripts/bxc-opkg-install.sh > /dev/null 2>&1
			/koolshare/scripts/bxc-opkg-install.sh > /dev/null 2>&1
			opkg_exist=`which opkg > /dev/null 2>&1;echo $?`
			if [ $opkg_exist -ne 0 ];then
				logerr "opkg install failed."
			else
				opkg_update=`opkg update > /dev/null 2>&1;echo $?`
				if [ $opkg_update -ne 0 ];then
					logerr "opkg update failed."
				else
					logdebug "opkg install success!"
				fi
			fi
		else
			logerr "opkg install script download failed from $ENTWARE_INSTALL_URL"
		fi
		
	else
		opkg_update=`opkg update > /dev/null 2>&1;echo $?`
		if [ $opkg_update -ne 0 ];then
			logerr "opkg update failed."
		else
			logdebug "opkg already installed."
		fi	
	fi
}

pkg_install() {
	for pkg in `echo $OPKG_PKGS`
	do
		pkg_full=`opkg list-installed | grep "$pkg"`
		if [ -n "$pkg_full" ];then
			logdebug "$pkg_full exist"
			continue
		else
			logdebug "$pkg not exist, opkg install $pkg..."
			opkg update > /dev/null 2>&1
			opkg install "$pkg" > /dev/null 2>&1
			pkg_full=`opkg list-installed | grep "$pkg"`
			if [ -n "$pkg_full" ];then
				logdebug "$pkg_full install success"
			else
				logerr "$pkg install failed, please try command: opkg install $pkg "
			fi
		fi
	done
}

status_bxc(){
	network_status=`ps | grep "bxc-network" | grep -v grep > /dev/null 2>&1; echo $?`
	worker_status=`ps | grep "bxc-worker" | grep -v grep > /dev/null 2>&1; echo $?`
	
	if [ $network_status == 0 ] && [ $worker_status == 0 ];then
		dbus set bxc_status="running"
		logdebug "BxC-Node status is running: bxc-network status $network_status, bxc-worker status $worker_status"
	else
		dbus set bxc_status="stoped"
		logdebug "BxC-Node status is stoped: bxc-network status $network_status, bxc-worker status $worker_status"
	fi
}

start_bxc(){
	status_bxc
	if [ $network_status -ne 0 ];then
		logdebug "bxc-network start..."
		chmod +x $BXC_NETWORK && $BXC_NETWORK > /dev/null 2>&1 &
		sleep 3
	fi
	if [ $worker_status -ne 0 ];then
		logdebug "bxc-worker start..."
		port_used=`netstat -lanp | grep "LISTEN" | grep ":$BXC_WORKER_PORT" > /dev/null 2>&1; echo $?`
		if [ $port_used -eq 0 ];then
			logerr "bxc-worker listen port $BXC_WORKER_PORT already in use, please release and retry."
		else
			chmod +x $BXC_WORKER && $BXC_WORKER > /dev/null 2>&1 &
			sleep 3
		fi
	fi
	sleep 2
	status_bxc
	if [ $network_status -ne 0 ] || [ $worker_status -ne 0 ];then
		logdebug "BxC-Node start failed."
		stop_bxc
	fi
}
stop_bxc(){
	logdebug "BxC-Node stop with command: ps | grep -v grep | egrep 'bxc-network|bxc-worker' | awk '{print $1}' | xargs kill -9 > /dev/null 2>&1 "
	ps | grep -v grep | egrep 'bxc-network|bxc-worker' | awk '{print $1}' | xargs kill -9 > /dev/null 2>&1 
	sleep 3
    status_bxc
}
bound_bxc(){
	bcode=`dbus get bxc_input_bcode`
	mac=`dbus get bxc_wan_mac`
	mkdir -p $BXC_SSL_DIR > /dev/null 2>&1
	if [ ! -d $BXC_SSL_DIR ];then
		dbus set bxc_bound_status="无法创建目录$BXC_SSL_DIR"
		logerr "mkdir $BXC_SSLDIR failed, exit"
		exit 1
	fi

	curl -k -m 5 -H "Content-Type: application/json" -d "{\"fcode\":\"$bcode\", \"mac_address\":\"$mac\"}" -w "\nstatus_code:"%{http_code}"\n" $BXC_BOUND_URL > /koolshare/bxc/curl.res
	logdebug "curl -k -H \"Content-Type: application/json\" -d \"{\"fcode\":\"$bcode\", \"mac_address\":\"$mac\"}\" -w \"\nstatus_code:\"%{http_code}\"\n\" $BXC_BOUND_URL"
	curl_code=`grep 'status_code' /koolshare/bxc/curl.res | awk -F: '{print $2}'`
	if [ -z $curl_code ];then
		dbus set bxc_bound_status="服务端没有响应绑定请求，请稍候再试"
		logerr 'bonud server has no response code, exit'
		exit 1
	elif [ "$curl_code"x == "200"x ];then
		echo -e `cat /koolshare/bxc/curl.res | /koolshare/scripts/bxc-json.sh | egrep "\"Cert\",\"key\"" | awk -F\" '{print $6}' | sed 's/"//g'` > $BXC_SSL_KEY
		echo -e `cat /koolshare/bxc/curl.res | /koolshare/scripts/bxc-json.sh | egrep "\"Cert\",\"cert\"" | awk -F\" '{print $6}' | sed 's/"//g'` > $BXC_SSL_CRT
		echo -e `cat /koolshare/bxc/curl.res | /koolshare/scripts/bxc-json.sh | egrep "\"Cert\",\"ca\"" | awk -F\" '{print $6}' | sed 's/"//g'` > $BXC_SSL_CA
		if [ ! -s $BXC_SSL_KEY ];then
			dbus set bxc_bound_status="获取key文件失败"
			logerr 'no client key file'
			exit 1
		elif [ ! -s $BXC_SSL_CRT ];then
			dbus set bxc_bound_status="获取crt文件失败"
			logerr 'no client crt file'
			exit 1
		elif [ ! -s $BXC_SSL_CA ];then
			dbus set bxc_bound_status="获取ca文件失败"
			logerr 'no client ca file'
			exit 1
		else
			dbus set bxc_bound_status="success"
			dbus set bxc_bcode="$bcode"
			logdebug "bound success!"
		fi
	else
		cat /koolshare/bxc/curl.res | /koolshare/scripts/bxc-json.sh | egrep '\["details"\]' > /dev/null
		if [ $? -eq 0 ];then
			fail_detail=`cat /koolshare/bxc/curl.res | /koolshare/scripts/bxc-json.sh | egrep '\["details"\]' | awk -F\" '{print $(NF-1)}'`
			if [ "$fail_detail"x == "fcode used"x ];then
				dbus set bxc_bound_status="邀请码已被使用"
			elif [ "$fail_detail"x == "dev used"x ];then
				dbus set bxc_bound_status="设备已被绑定"
			elif [ "$fail_detail"x == "fcode invalid"x ];then
				dbus set bxc_bound_status="无效的邀请码"
			else
				dbus set bxc_bound_status="$fail_detail"
			fi
			logerr "bound failed with server response: $fail_detail"
			exit 1
		else
			dbus set bxc_bound_status="服务端没有响应绑定请求，请稍候再试"
			logerr "Server response code: $curl_code, please check /koolshare/bxc/curl.res"
			exit 1
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
    [ ! -L "/koolshare/init.d/S97bxc.sh" ] && logerr "BxC-Node start onboot enable failed"
    dbus set bxc_onboot="yes"
}
bootoff_bxc(){
	# 关闭开机自启动
    rm -f /koolshare/init.d/S97bxc.sh
    [ -L "/koolshare/init.d/S97bxc.sh" ] && logerr "BxC-Node start onboot disable failed"
    dbus set bxc_onboot="no"
}
log_err(){
	if [ -f $BXC_CONF ];then
		sed -i '/^LOG_LEVEL=/d' $BXC_CONF > /dev/null 2>&1
		echo "LOG_LEVEL=\"error\"" >> $BXC_CONF
		dbus set bxc_log_level="error"
	else
		logerr "$BXC_CONF not found, exit."
		exit 1
	fi
}
log_debug(){
	if [ -f $BXC_CONF ];then
		sed -i '/^LOG_LEVEL=/d' $BXC_CONF > /dev/null 2>&1
		echo "LOG_LEVEL=\"debug\"" >> $BXC_CONF
		dbus set bxc_log_level="debug"
	else
		logerr "$BXC_CONF not found, exit."
		exit 1
	fi
}
cron_add(){
	cron_exist=`cru l | grep "/koolshare/scripts/bxc-mon.sh" > /dev/null 2>&1;echo $?`
	if [ $cron_exist -ne 0 ];then
		cru a BxcMon "*/10 * * * * /koolshare/scripts/bxc-mon.sh > /dev/null 2>&1"
	fi
}
cron_del(){
	cron_exist=`cru l | grep "/koolshare/scripts/bxc-mon.sh" > /dev/null 2>&1;echo $?`
	if [ $cron_exist -eq 0 ];then
		cru d BxcMon "*/10 * * * * /koolshare/scripts/bxc-mon.sh > /dev/null 2>&1"
	fi
}
update_bxc(){
	stop_bxc

	logdebug "Download update package..."
	cd /tmp/ && rm -fr /tmp/bxc*
	wget -q -t 3 -O $BXC_PKG $BXC_UPDATE_URL > /dev/null 2>&1
	if [ -s $BXC_PKG ];then
		tar -zxf $BXC_PKG
		logdebug "Copy update files..."
		cp -rf /tmp/bxc/scripts/* /koolshare/scripts/
		cp -rf /tmp/bxc/bin/* /koolshare/bin/
		cp -rf /tmp/bxc/webs/* /koolshare/webs/
		cp -rf /tmp/bxc/res/* /koolshare/res/
		cp -rf /tmp/bxc/bxc/* /koolshare/bxc/
		cp -rf /tmp/bxc/install.sh /koolshare/scripts/bxc_install.sh
		cp -rf /tmp/bxc/uninstall.sh /koolshare/scripts/uninstall_bxc.sh
		chmod a+x /koolshare/scripts/bxc*
		chmod a+x /koolshare/bin/bxc*

		CUR_VERSION=`cat $BXC_DIR/version`
		dbus set bxc_local_version="$CUR_VERSION"
		dbus set softcenter_module_bxc_version="$CUR_VERSION"
		logdebug "Version infomation update:$CUR_VERSION"
		source $BXC_CONF
		dbus set bxc_log_level="$LOG_LEVEL"

		rm -rf /tmp/bxc* >/dev/null 2>&1
	else
		logerr "Dowanlod update package failed: wget -q -t 3 -O $BXC_PKG $BXC_UPDATE_URL"
		exit 1
	fi
}

for ACTION in $*;
do
	case $ACTION in
	start)
		logdebug "bxc.sh $ACTION"
		init
		cron_add
		start_bxc
		;;
	stop)
		logdebug "bxc.sh $ACTION"
		stop_bxc
		cron_del
		;;
	status)
		logdebug "bxc.sh $ACTION"
		status_bxc
		;;
	bound)
		logdebug "bxc.sh $ACTION"
		bound_bxc
		;;
	booton)
		logdebug "bxc.sh $ACTION"
		booton_bxc
		;;
	bootoff)
		logdebug "bxc.sh $ACTION"
		bootoff_bxc
		;;
	debuglog)
		logdebug "bxc.sh $ACTION"
		log_debug
		;;
	errorlog)
		logdebug "bxc.sh $ACTION"
		log_err
		;;
	cronon)
		logdebug "bxc.sh $ACTION"
		cron_add
		;;
	cronoff)
		logdebug "bxc.sh $ACTION"
		cron_del
		;;
	update)
		logdebug "bxc.sh $ACTION"
		update_bxc
		;;
	*)
		continue
	    ;;
	esac
done
exit 0
#dbus set bxc_option=""