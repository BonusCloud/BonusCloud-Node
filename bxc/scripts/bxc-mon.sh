#!/bin/sh

BXC_NETWORK="/koolshare/bin/bxc-network"
BXC_WORKER="/koolshare/bin/bxc-worker"
BXC_CONF="/koolshare/bxc/bxc.config"
BXC_EXT_TARGET="www.baidu.com"
BXC_INTF="tun0"

source $BXC_CONF

logdebug(){
  if [ "$LOG_LEVEL"x == "debug"x ];then
    logger -c "INFO: $1" -t bonuscloud-node > /dev/null 2>&1
  fi
}

logerr(){
  if [ "$LOG_LEVEL"x == "error"x ] || [ "$LOG_LEVEL"x == "debug"x ];then
    logger -c "ERROR: $1" -t bonuscloud-node > /dev/null 2>&1
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

check_int_net(){
	intf_exist=`ifconfig $BXC_INTF > /dev/null 2>&1;echo $?`
	if [ $intf_exist -eq 0 ];then
		gw=`ip addr show $BXC_INTF | grep inet6 | awk '{print $2}' | awk -F: '{print $1":"$2":"$3":"$4":"$5":"$6":"$7":1"}'`
		check_gw=`echo $gw | grep -o ":" | grep -c ":"`
		if [ $check_gw -eq 7 ];then
			logdebug "int-network gw addr: $gw"
			icmp=`ping6 -q -W 1 -c 3 $gw > /dev/null 2>&1;echo $?`
			if [ $icmp -eq 0 ];then
				logdebug "int-network icmp6 success: ping6 -q -W 1 -c 3 $gw"
			else
				logerr "int-network icmp6 faild: ping6 -q -W 1 -c 3 $gw"
			fi
		else
			logerr "get int-network gw addr faild"
		fi
	else
		logerr "interface $BXC_INTF not exist"
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

check_iptables
check_pid
check_ext_net
check_int_net

exit 0
