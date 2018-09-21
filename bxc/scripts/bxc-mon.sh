#!/bin/sh
source /koolshare/bxc/bxc.config

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

logclear(){
	if [ -s $LOG_FILE ];then
		eval first_time=$(date +%s -d "`head -1 $LOG_FILE | awk '{print $1" "$2}' | sed 's/\[//' | sed 's/\]//'`")
		if [ "$LOG_DAYS" -gt 0 ] && [ "$first_time" -gt 0 ] 2>/dev/null;then
			current_time=`date +%s`
			diff_time=$(($current_time - $first_time)) > /dev/null 2>&1
			valid_seconds=$(($LOG_DAYS * 3600 * 24))
			if [ "$diff_time" -ge "$valid_seconds" ] 2>/dev/null;then
				rm -f $LOG_FILE > /dev/null 2>&1
				logdebug "log file $LOG_FILE cleared."
			fi
		fi
	fi
}

check_pid(){
	network_pid=`ps | grep "bxc-network" | grep -v grep | awk '{print $1}'`
	if [ -z "$network_pid" ];then
		logerr "bxc-network stoped, try start up..."
		chmod +x $BXC_NETWORK && $BXC_NETWORK > /dev/null 2>&1 &
		network_pid=`ps | grep "bxc-network" | grep -v grep | awk '{print $1}'`
		if [ -z "$network_pid" ];then
			logerr "bxc-network start faild: $BXC_NETWORK"
		else
			logdebug "bxc-network pid $network_pid"
		fi
	else
		logdebug "bxc-network pid $network_pid"
	fi
	
	worker_pid=`ps | grep "bxc-worker" | grep -v grep | awk '{print $1}'`
	if [ -z "$worker_pid" ];then
		logerr "bxc-worker stoped, try start up..."
		chmod +x $BXC_WORKER && $BXC_WORKER > /dev/null 2>&1 &
		worker_pid=`ps | grep "bxc-worker" | grep -v grep | awk '{print $1}'`
		if [ -z "$worker_pid" ];then
			logerr "bxc-worker start faild: $BXC_WORKER"
		else
			logdebug "bxc-worker pid $worker_pid"
		fi
	else
		logdebug "bxc-worker pid $worker_pid"
	fi
}

check_ext_net(){
	icmp=`ping -q -W 1 -c 3 $BXC_EXT_TARGET > /dev/null 2>&1;echo $?`
	if [ $icmp -eq 0 ];then
		logdebug "ext-network icmp success: ping -q -W 1 -c 3 $BXC_EXT_TARGET"
	else
		logerr "ext-network icmp faild: ping -q -W 1 -c 3 $BXC_EXT_TARGET"
	fi
}

check_iptables() {
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
		logerr "ip6tables not exist"
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

logclear
check_iptables
check_pid
check_ext_net

exit 0
