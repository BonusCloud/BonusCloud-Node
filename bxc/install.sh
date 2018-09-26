#! /bin/sh
# bxc install script for AM380 merlin firmware
# by sean.ley (ley@bonuscloud.io)

eval `dbus export bxc`
alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'

MD5_CHECK_URL="https://raw.githubusercontent.com/BonusCloud/BonusCloud-Node/master/md5.txt"


opkg_install() {
	opkg_exist=`which opkg > /dev/null 2>&1;echo $?`
	if [ $opkg_exist -ne 0 ];then
		echo_date 系统中未检测到opkg，检测opkg安装环境...
		mkdir -p /tmp/opt/ > /dev/null 2>&1
		if [ ! -d /tmp/opt ];then
			echo_date 创建目录/tmp/opt失败，软链/tmp/opt到/jffs/opt...
			mkdir -p /jffs/opt && ln -s /jffs/opt /tmp/opt > /dev/null 2>&1
		fi
		echo_date 下载opkg安装脚本...
		wget -t 3 -T 3 -O /koolshare/scripts/bxc-opkg-install.sh $ENTWARE_INSTALL_URL > /dev/null 2>&1
		if [ -s /koolshare/scripts/bxc-opkg-install.sh ];then
			echo_date 脚本下载完成，安装opkg...
			chmod +x /koolshare/scripts/bxc-opkg-install.sh > /dev/null 2>&1
			/koolshare/scripts/bxc-opkg-install.sh > /dev/null 2>&1
			opkg_exist=`which opkg > /dev/null 2>&1;echo $?`
			if [ $opkg_exist -ne 0 ];then
				echo_date 安装opkg失败，退出安装!
				exit 1
			else
				opkg_update=`opkg update > /dev/null 2>&1;echo $?`
				if [ $opkg_update -ne 0 ];then
					echo_date opkg 更新信息失败，无法安装相关依赖，退出安装！
					echo_date 您可以在命令行下执行opkg update命令，以验证远程安装依赖是否可行
					exit 1
				else
					echo_date opkg安装成功！
				fi
			fi
		else
			echo_date 下载opkg安装脚本失败，退出安装！
			echo_date 您可以尝试访问"$ENTWARE_INSTALL_URL"，以验证网络是否正常。
			exit 1
		fi
		
	else
		opkg_update=`opkg update > /dev/null 2>&1;echo $?`
		if [ $opkg_update -ne 0 ];then
			echo_date opkg update失败，无法安装相关依赖，退出安装！
			echo_date 您可以在命令行执行：opkg update ，以验证远程安装依赖是否可行
			exit 1
		else
			echo_date 系统中已安装opkg，并且更新信息成功！
		fi	
	fi
}

pkg_install() {
	for pkg in `echo $OPKG_PKGS`
	do
		pkg_full=`opkg list-installed | grep "$pkg"`
		if [ -n "$pkg_full" ];then
			echo_date 系统已安装"$pkg_full"
			continue
		else
			echo_date opkg安装"$pkg"...
			opkg update > /dev/null 2>&1
			opkg install "$pkg" > /dev/null 2>&1
			pkg_full=`opkg list-installed | grep "$pkg"`
			if [ -n "$pkg_full" ];then
				echo_date "$pkg_full"安装成功！
			else
				echo_date 安装"$pkg"失败，退出安装！
				echo_date 您可以在命令行执行：opkg install "$pkg" ，手动验证安装
				exit 1
			fi
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
		remote_md5=`curl -s -m 3 $MD5_CHECK_URL | awk '{print $1}'`
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


# delete install tar
rm -rf /tmp/bxc* >/dev/null 2>&1

echo_date 安装完毕，您可以在软件中心打开BonusCloud-Node，绑定设备后运行程序！
