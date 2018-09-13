#! /bin/sh
# bxc install script for AM380 merlin firmware
# by sean.ley (ley@bonuscloud.io)

eval `dbus export bxc`
alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'


opkg_install() {
	opkg_exist=`which opkg > /dev/null 2>&1;echo $?`
	if [ $opkg_exist -ne 0 ];then
		echo_date 系统中未检测到opkg，安装opkg...
		mkdir -p /tmp/opt && ln -s /tmp/opt /opt > /dev/null 2>&1
		chmod +x /koolshare/scripts/bxc-tool.sh > /dev/null 2>&1
		/koolshare/scripts/bxc-tool.sh > /dev/null 2>&1
	fi

	opkg_exist=`which opkg > /dev/null 2>&1;echo $?`
	if [ $opkg_exist -ne 0 ];then
		echo_date 安装opkg失败，退出安装!
		exit 1
	else
		echo_date opkg安装成功！
	fi
}

pkg_install() {
	for pkg in `cat /koolshare/bxc/lib/install_order`
	do
		pkg_prefix=`echo "$pkg" | awk -F_ '{print $1}'`
		
		# 网络安装
		pkg_exist=`opkg list-installed | grep "$pkg_prefix" > /dev/null 2>&1;echo $?`
		if [ $pkg_exist -ne 0 ];then
			echo_date 通过opkg安装"$pkg"...
			opkg update > /dev/null 2>&1
			opkg install "$pkg_prefix" > /dev/null 2>&1
		else
			echo_date 系统已安装"$pkg"
			continue
		fi

		# 本地安装
		pkg_exist=`opkg list-installed | grep "$pkg_prefix" > /dev/null 2>&1;echo $?`
		if [ $pkg_exist -ne 0 ];then
			echo_date opkg网络安装"$pkg"失败，尝试本地安装...
			/opt/bin/opkg install "/koolshare/bxc/lib/$pkg" > /dev/null 2>&1
		fi

		# 检测
		pkg_exist=`opkg list-installed | grep "$pkg_prefix" > /dev/null 2>&1;echo $?`
		if [ $pkg_exist -ne 0 ];then
			echo_date 安装"$pkg"失败，退出安装！
			exit 1
		else
			echo_date "$pkg"安装成功！
		fi
	done
}

# 判断架构和平台
case $(uname -m) in
	armv7l)
		echo_date 固件平台【koolshare merlin armv7l】符合安装要求，开始安装插件！
	;;
	*)
		echo_date 本插件适用于koolshare merlin armv7l固件平台，你的平台"$(uname -m)"不能安装！！！
		echo_date 退出安装！
		exit 1
	;;
esac

# 校验下载文件
md5_exist=`which md5sum > /dev/null 2>&1;echo $?`
if [ $md5_exist -eq 0 ];then
	echo_date 校验安装包...
	if [ -f /tmp/bxc.tar.gz ];then
		local_md5=`md5sum /tmp/bxc.tar.gz | awk '{print $1}'`
		remote_md5=`curl -s -m 3 "http://bc-git.linkedsee.com/api/v4/projects/14/repository/files/md5.txt/raw?ref=master" | awk '{print $1}'`
		check_remote=`echo $remote_md5 | wc -c`
		if [ $check_remote -eq 33 ];then
			if [ "$local_md5"x != "$remote_md5"x ];then
				echo_date 安装包MD5校验失败: 本地-"$local_md5"，发布-"$remote_md5"，请重新下载安装包，退出安装！
				exit 1
			else
				echo_date 安装包校验成功！
			fi
		else
			echo_date 远程信息获取失败，跳过校验，您也可以手动比对本地安装包md5值与github中的md5。
		fi
	else
		echo_date 未检测到包文件/tmp/bxc.tar.gz，跳过校验
 	fi
fi

# 获取上联口MAC地址
wan_mac=`nvram get wan0_hwaddr`
if [ "$wan_mac"x != ""x ]; then
	echo_date 设备MAC地址为：$wan_mac
else
	echo_date 从NVRAM获取MAC地址失败，建议设备恢复出厂设置后重新安装，退出安装！
	exit 1
fi

# 复制文件
mkdir -p /koolshare/bxc > /dev/null 2>&1
if [ -d /koolshare/bxc ];then
	echo_date 设备koolshare目录检测通过，开始复制文件...
	cd /tmp
	cp -rf /tmp/bxc/scripts/* /koolshare/scripts/
	chmod a+x /koolshare/scripts/bxc*
	cp -rf /tmp/bxc/bin/* /koolshare/bin/
	chmod a+x /koolshare/bin/bxc*
	cp -rf /tmp/bxc/webs/* /koolshare/webs/
	cp -rf /tmp/bxc/res/* /koolshare/res/
	cp -rf /tmp/bxc/bxc/* /koolshare/bxc/
	cp -rf /tmp/bxc/install.sh /koolshare/scripts/bxc_install.sh
	cp -rf /tmp/bxc/uninstall.sh /koolshare/scripts/uninstall_bxc.sh
	mkdir -p /tmp/etc/bxc-network/
else
	echo_date 设备koolshare目录无法写入，退出安装！
	exit 1
fi



# 如果本地存有邀请码，可以加载使用
if [ -s /koolshare/bxc/bcode ];then
	bcode=`cat /koolshare/bxc/bcode` 
	dbus set bxc_bcode="$bcode"
	echo_date 设备中已有绑定信息，绑定邀请码为:"$bcode"
else
	dbus set bxc_bcode=""
	echo_date 设备中未检测到邀请码，运行时需要先绑定设备。
fi


# 离线安装时设置软件中心内储存的版本号和连接
echo_date 设置环境变量...
CUR_VERSION=`cat /koolshare/bxc/version`
dbus set bxc_local_version="$CUR_VERSION"
echo_date 安装版本信息："$CUR_VERSION"
source /koolshare/bxc/bxc.config 
dbus set bxc_log_level="$LOG_LEVEL"
dbus set bxc_wan_mac="$wan_mac"
dbus set softcenter_module_bxc_install="4"
dbus set softcenter_module_bxc_version="$CUR_VERSION"
dbus set softcenter_module_bxc_title="BonusCloud-Node"
dbus set softcenter_module_bxc_description="BonusCloud-Node"
dbus set softcenter_module_bxc_home_url=Module_BxC.asp
dbus set softcenter_module_bxc_name="BonusCloud-Node"

# 运行状态初始化
echo_date 安装依赖环境...
opkg_install
pkg_install 

echo_date 运行数据初始化...
/koolshare/scripts/bxc.sh status
/koolshare/scripts/bxc.sh booton
/koolshare/scripts/bxc.sh cronon


# delete install tar
rm -rf /tmp/bxc* >/dev/null 2>&1

echo_date 安装完毕，您可以在软件中心打开BxC-Node，绑定设备后运行程序！
