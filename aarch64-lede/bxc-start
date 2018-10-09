#!/bin/sh

BASEDIR=$(dirname "$0")
MACADDR=$(cat /sys/class/net/eth0/address)
BXCBIN="https://github.com/haibochu/BonusCloud-Node/raw/mipsel-lede/aarch64-lede/bxc.tar.gz"

export PATH=$PATH:$BASEDIR

if [ ! -f $BASEDIR/bcode ];  then
	read -p 'bcode: ' bcode
	echo $bcode > $BASEDIR/bcode
fi
BCODE=$(cat $BASEDIR/bcode)

if [ ! -f $BASEDIR/bxc-network ];  then
	# Download BXC Binary
	wget $BXCBIN -O - | tar -xzf - -C $BASEDIR
	mv $BASEDIR/bxc/bin/bxc-network $BASEDIR
	mv $BASEDIR/bxc/bin/bxc-worker $BASEDIR
	mv $BASEDIR/bxc/scripts/bxc-json.sh $BASEDIR
	rm -rf $BASEDIR/bxc

	# Install Dependency
	opkg install --force-depends curl liblzo libcurl libopenssl libstdcpp libltdl kmod-tun procps-ng-pkill
	mkdir -p /opt/sbin
	mkdir -p /opt/bin
	ln -s /sbin/ifconfig /opt/sbin/ifconfig
	ln -s /sbin/route /opt/sbin/route
	ln -s /sbin/ip /opt/sbin/ip
	ln -s /bin/netstat /opt/bin/netstat
fi

if [ ! -f $BASEDIR/curl.res ];  then
	# Bound BCODE
	curl -s -k -m 5 -H "Content-Type: application/json" -d "{\"fcode\":\"$BCODE\", \"mac_address\":\"$MACADDR\"}" -w "\nstatus_code:"%{http_code}"\n" https://117.48.224.43/idb/dev > $BASEDIR/curl.res
	bcode_res=$(grep status_code $BASEDIR/curl.res | cut -d : -f 2)
	if [ "$bcode_res" != "200" ]; then
		echo "BCODE: $BCODE"
		echo "MAC: $MACADDR"
		echo "RESULT:"
		cat $BASEDIR/curl.res
		# head -n 1 $BASEDIR/curl.res | python -m json.tool
		rm -rf $BASEDIR/curl.res
		echo "[ERROR] Failed to bound device."
		exit 1 
	fi
	echo `cat $BASEDIR/curl.res | bxc-json.sh | egrep "\"Cert\",\"key\"" | awk -F\" '{print $6}' | sed 's/"//g'` > $BASEDIR/client.key
	echo `cat $BASEDIR/curl.res | bxc-json.sh | egrep "\"Cert\",\"cert\"" | awk -F\" '{print $6}' | sed 's/"//g'` > $BASEDIR/client.crt
	echo `cat $BASEDIR/curl.res | bxc-json.sh | egrep "\"Cert\",\"ca\"" | awk -F\" '{print $6}' | sed 's/"//g'` > $BASEDIR/ca.crt
fi

# Copy Config File
mkdir -p /tmp/etc/bxc-network
cp $BASEDIR/client.key /tmp/etc/bxc-network
cp $BASEDIR/client.crt /tmp/etc/bxc-network
cp $BASEDIR/ca.crt /tmp/etc/bxc-network
chmod 600 /tmp/etc/bxc-network/*

# Start BXC Binary
while [ ! -d /sys/class/net/tun0 ];  do
	pkill bxc-network
	sleep 3
	bxc-network
	echo
	sleep 10
done

bxc-worker

# Print Interface Status
ifconfig tun0

cat <<EOT > $BASEDIR/bxc-status
#!/bin/sh
BASEDIR=\$(dirname "\$0")
BCODE=\$(cat \$BASEDIR/bcode)
ifconfig tun0
curl -s http://183.2.168.127:8080/fcode/json/\$BCODE | python -m json.tool
EOT

chmod +x $BASEDIR/bxc-status

# Write BXC Stop
cat <<EOT > $BASEDIR/bxc-stop
#!/bin/sh
rm -rf /tmp/etc/bxc-network
pkill bxc-worker
pkill bxc-worker
pkill bxc-network
EOT

chmod +x $BASEDIR/bxc-stop