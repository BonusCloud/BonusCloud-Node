#!/bin/sh
TMPFILE="/tmp/node"
TMPINFO="/tmp/node.txt"
TMPSYSTEMD="/tmp/bxc-node.service"
NODEFILE="/opt/bcloud/nodeapi/node"
ARCH="`uname -m`"

curl -s --retry 5 "https://bxc-node.s3.cn-east-2.jdcloud-oss.com/info.txt" -o $TMPINFO
SRCMD5=`grep "bxc-node_$ARCH" $TMPINFO | awk -F: '{print $2}'`

install()
{
	mkdir -p /opt/bcloud/nodeapi/
	[ -f /opt/bcloud/node.db ] || touch /opt/bcloud/node.db
	curl -s --retry 5 "https://bxc-node.s3.cn-east-2.jdcloud-oss.com/bxc-node_$ARCH" -o $TMPFILE
	curl -s --retry 5 "https://bxc-node.s3.cn-east-2.jdcloud-oss.com/bxc-node.service" -o $TMPSYSTEMD

	TMPMD5=`md5sum $TMPFILE | awk '{print $1}'`
	if [ x"$TMPMD5" = x"$SRCMD5" ]
	then
		echo "download $TMPFILE success"
	    cp -f $TMPSYSTEMD /lib/systemd/system/bxc-node.service
	    rm -f /etc/systemd/system/bxc-node.service
		systemctl daemon-reload
		cp -f $TMPFILE $NODEFILE
		chmod +x $NODEFILE
		systemctl enable bxc-node
		systemctl restart bxc-node
		echo "update finished"
	else
		echo "download faild"
	fi

}

if [ -f $NODEFILE ];then
	CURMD5=`md5sum $NODEFILE | awk '{print $1}'`
	if [ x"$CURMD5" = x"$SRCMD5" ]
	then
		echo "bxc-node already latest"
	else
		echo "bxc-node exist, but need update..."
		install
	fi
else
	install
fi

rm -f $TMPFILE $TMPINFO $TMPSYSTEMD

rm -f $0
