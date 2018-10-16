#!/bin/sh

SCRIPT=$(readlink -f $0)
BASEDIR=$(dirname "$SCRIPT")

MACADDR=$(cat /sys/class/net/eth0/address)
BXC_SSL_DIR="$BASEDIR/bcloud"
BXC_SSL_DIR2="/opt/bcloud"
BXC_NETWORK="$BASEDIR/bxc-network"
BXC_WORKER="$BASEDIR/bxc-worker"
BXC_JSON="$BASEDIR/bxc-json.sh"

BXC_BIN="https://github.com/BonusCloud/BonusCloud-Node/raw/master/aarch32-merlin/bxc.tar.gz"
BXC_BOUND_URL="https://console.bonuscloud.io/api/web/devices/bind/"
BXC_REPORT_URL="https://bxcvenus.com/idb/dev"

BXC_SSL_RES="$BXC_SSL_DIR/curl.res"
BXC_SSL_KEY="$BXC_SSL_DIR/client.key"
BXC_SSL_CRT="$BXC_SSL_DIR/client.crt"
BXC_SSL_CA="$BXC_SSL_DIR/ca.crt"

BXC_INFO_LOC="$BXC_SSL_DIR/info"
BXC_EMAIL_LOC="$BXC_SSL_DIR/email"
BXC_BCODE_LOC="$BXC_SSL_DIR/bcode"

BXC_VER="0.2.2-1n"
BXC_INFO=$(cat $BXC_INFO_LOC) >/dev/null 2>&1
BXC_EMAIL=$(cat $BXC_EMAIL_LOC) >/dev/null 2>&1
BXC_BCODE=$(cat $BXC_BCODE_LOC) >/dev/null 2>&1

func_initial_setup()
{
	# Remove Old Files
	rm -rf $BXC_NETWORK $BXC_WORKER $BXC_JSON

	# Download BXC Binary
	wget $BXC_BIN -O - | tar -xzf - -C $BASEDIR
	mv $BASEDIR/bxc/bin/bxc-network $BASEDIR
	mv $BASEDIR/bxc/bin/bxc-worker $BASEDIR
	mv $BASEDIR/bxc/scripts/bxc-json.sh $BASEDIR
	rm -rf $BASEDIR/bxc

	# Install Dependency
	apt update && apt install -y net-tools libjson-c3 libltdl7 curl

	mkdir -p /opt/lib
	ln -s /lib/ld-linux-aarch64.so.1 /opt/lib/ld-linux-aarch64.so.1 >/dev/null 2>&1

	cd /lib/aarch64-linux-gnu
	ln -s libjson-c.so.3.0.1 libjson-c.so.2 >/dev/null 2>&1

	mkdir -p /opt/sbin
	mkdir -p /opt/bin
	ln -s /sbin/ifconfig /opt/sbin/ifconfig >/dev/null 2>&1
	ln -s /sbin/route /opt/sbin/route >/dev/null 2>&1
	ln -s /sbin/ip /opt/sbin/ip >/dev/null 2>&1
	ln -s /bin/netstat /opt/bin/netstat >/dev/null 2>&1

	mkdir -p $BXC_SSL_DIR
}

func_bound_bcode()
{
	mkdir -p $BXC_SSL_DIR
	rm -rf $BXC_SSL_RES $BXC_SSL_CA $BXC_SSL_CRT $BXC_SSL_KEY $BXC_INFO_LOC $BXC_EMAIL_LOC $BXC_BCODE_LOC

	curl -s -k -m 10 -H "Content-Type: application/json" -d "{\"email\":\"$BXC_EMAIL\", \"bcode\":\"$BXC_BCODE\", \"mac_address\":\"$MACADDR\"}" -w "\nstatus_code:"%{http_code}"\n" $BXC_BOUND_URL > $BXC_SSL_RES
	bcode_res=$(grep status_code $BXC_SSL_RES | cut -d : -f 2)
	if [ "$bcode_res" = "200" ]; then
		echo `cat $BXC_SSL_RES | $BXC_JSON | egrep "\"Cert\",\"key\"" | awk -F\" '{print $6}' | sed 's/"//g'` | base64 -d > $BXC_SSL_KEY
		echo `cat $BXC_SSL_RES | $BXC_JSON | egrep "\"Cert\",\"cert\"" | awk -F\" '{print $6}' | sed 's/"//g'` | base64 -d > $BXC_SSL_CRT
		echo `cat $BXC_SSL_RES | $BXC_JSON | egrep "\"Cert\",\"ca\"" | awk -F\" '{print $6}' | sed 's/"//g'` | base64 -d > $BXC_SSL_CA
		chmod 600 $BXC_SSL_KEY
		chmod 600 $BXC_SSL_CRT
		chmod 600 $BXC_SSL_CA
		echo $BXC_EMAIL > $BXC_EMAIL_LOC
		echo $BXC_BCODE > $BXC_BCODE_LOC
		echo "bxc-network: Bound device OK"
	else
		bcode_failed_res=$(head -n 1  $BXC_SSL_RES | $BXC_JSON | egrep '\["details"\]' | cut -d \" -f 4)
		rm -rf $BXC_EMAIL_LOC $BXC_BCODE_LOC
		echo "bxc-network: Bcode: $BXC_BCODE"
		echo "bxc-network: MAC Address: $MACADDR"
		echo "bxc-network: Failed to bound device - $bcode_failed_res"
	fi
}

func_info_report()
{
	version=$BXC_VER
	cpu_info=$(cat /proc/cpuinfo | grep -e "^processor" | wc -l)
	mem_info=$(cat /proc/meminfo | grep "MemTotal" | awk -F: '{print $2}'| sed 's/ //g')
	hw_arch=$(uname -m)

	info_cur="${version}#${hw_arch}#${cpu_info}#${mem_info}"
	info_old=$BXC_INFO

	if [ "$info_cur" != "$info_old" ];then
		echo "bxc-node: node info changed: \"$info_old\" --> \"$info_cur\", report info..."
		echo $info_cur > $BXC_INFO_LOC
		status_code=`curl -s -m 10 -k --cacert $BXC_SSL_CA --cert $BXC_SSL_CRT --key $BXC_SSL_KEY -H "Content-Type: application/json" -d "{\"mac\":\"$MACADDR\", \"info\":\"$info_cur\"}" -X PUT -w "\nstatus_code:"%{http_code}"\n" "$BXC_REPORT_URL/$BXC_BCODE" | grep "status_code" | awk -F: '{print $2}'`
		if [ $status_code -eq 200 ];then
			echo "bxc-node: node info reported success"
		else
			echo "bxc-node: node info reported failed($status_code)"
		fi
	else
		echo "bxc-node: node info has not changed: $info_cur"
	fi
}

func_init()
{
	func_initial_setup
	if [ ! -f $BXC_BCODE_LOC ];  then
		read -p 'Email: ' email
		BXC_EMAIL="$email"
		read -p 'Bcode: ' bcode
		BXC_BCODE="$bcode"

		func_bound_bcode
	fi
}

func_start()
{
	if [  ! -f $BXC_BCODE_LOC  ]; then
		echo "bxc-network: Device has not bounded, run \"bxc.sh init\" first."
		exit 1
	fi

	# Copy Config File
	mkdir -p $BXC_SSL_DIR2
	cp $BXC_SSL_KEY $BXC_SSL_DIR2
	cp $BXC_SSL_CRT $BXC_SSL_DIR2
	cp $BXC_SSL_CA $BXC_SSL_DIR2

	export PATH=$PATH:$BASEDIR
	echo "bxc-network: Start bxc-network"
	bxc-network
	echo "bxc-worker: Start bxc-worker"
	bxc-worker

	func_info_report
}

func_stop()
{
	rm -rf $BXC_SSL_DIR2
	echo "bxc-worker: Stop bxc-worker"
	killall -q bxc-worker
	killall -q bxc-worker

	echo "bxc-network: Stop bxc-network"
	killall -q bxc-network
}

case "$1" in
init)
	func_init
	;;
start)
	func_start
	;;
stop)
	func_stop
	;;

report)
	func_info_report
	;;
*)
	echo "Usage: $0 {init|start|stop}"
	exit 1
	;;
esac

exit 0
