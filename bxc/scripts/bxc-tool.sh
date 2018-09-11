#!/bin/sh

unset LD_LIBRARY_PATH
unset LD_PRELOAD

source /koolshare/bxc/bxc.config

logdebug(){
  if [ "$LOG_LEVEL"x == "debug"x ];then
    echo "[$(TZ=UTC-8 date -R +%Y-%m-%d\ %X)] INFO: $1 " >> /tmp/log-bxc
  fi
}

logerr(){
  if [ "$LOG_LEVEL"x == "error"x ] || [ "$LOG_LEVEL"x == "debug"x ];then
    echo "[$(TZ=UTC-8 date -R +%Y-%m-%d\ %X)] ERROR: $1 " >> /tmp/log-bxc
  fi
}

logdebug "Checking for prerequisites and creating folders..."
mkdir -p /opt
# no need to create many folders. entware-opt package creates most
for folder in bin etc lib/opkg tmp var/lock
do
  if [ -d "/opt/$folder" ]
  then
    logdebug "Folder /opt/$folder exists!"
  else
    mkdir -p /opt/$folder 
  fi
done

logdebug "Opkg package manager deployment..."
DLOADER="ld-linux.so.3"
URL=http://bin.entware.net/armv7sf-k2.6/installer

cp -f /koolshare/bxc/lib/opkg/opkg /opt/bin/opkg > /dev/null 2>&1
if [ ! -f /opt/bin/opkg ];then 
  logdebug "local file /koolshare/bxc/lib/opkg/opkg copy faild, try remote install..."
  wget $URL/opkg -O /opt/bin/opkg > /dev/null 2>&1
  [ ! -f /opt/bin/opkg ] && logerr "/opt/bin/opkg download faild" && exit 1
fi
chmod 755 /opt/bin/opkg > /dev/null 2>&1

cp -f /koolshare/bxc/lib/opkg/opkg.conf /opt/etc/opkg.conf > /dev/null 2>&1
if [ ! -f /opt/etc/opkg.conf ];then
  logdebug "local file /koolshare/bxc/lib/opkg/opkg.conf faild, try remote install..."
  wget $URL/opkg.conf -O /opt/etc/opkg.conf > /dev/null 2>&1
  [ ! -f /opt/etc/opkg.conf ] && logerr "/opt/etc/opkg.conf download faild" && exit 1
fi

cp -f /koolshare/bxc/lib/opkg/ld-2.23.so /opt/lib/ld-2.23.so > /dev/null 2>&1
if [ ! -f /opt/lib/ld-2.23.so ];then
  logdebug "local file /koolshare/bxc/lib/opkg/ld-2.23.so faild, try remote install..."
  wget $URL/ld-2.23.so -O /opt/lib/ld-2.23.so > /dev/null 2>&1
  [ ! -f /opt/lib/ld-2.23.so ] && logerr "/opt/lib/ld-2.23.so download faild" && exit 1
fi

cp -f /koolshare/bxc/lib/opkg/libc-2.23.so /opt/lib/libc-2.23.so > /dev/null 2>&1
if [ ! -f /opt/lib/libc-2.23.so ];then
  logdebug "local file /koolshare/bxc/lib/opkg/libc-2.23.so faild, try remote install..."
  wget $URL/libc-2.23.so -O /opt/lib/libc-2.23.so > /dev/null 2>&1
  [ ! -f /opt/lib/libc-2.23.so ] && logerr "/opt/lib/libc-2.23.so download faild" && exit 1
fi

cp -f /koolshare/bxc/lib/opkg/libgcc_s.so.1 /opt/lib/libgcc_s.so.1 > /dev/null 2>&1
if [ ! -f /opt/lib/libgcc_s.so.1 ];then
  logdebug "local file /koolshare/bxc/lib/opkg/libgcc_s.so.1 faild, try remote install..."
  wget $URL/libgcc_s.so.1 -O /opt/lib/libgcc_s.so.1 > /dev/null 2>&1
  [ ! -f /opt/lib/libgcc_s.so.1 ] && logerr "/opt/lib/libgcc_s.so.1 download faild" && exit 1
fi

cp -f /koolshare/bxc/lib/opkg/libpthread-2.23.so /opt/lib/libpthread-2.23.so > /dev/null 2>&1
if [ ! -f /opt/lib/libpthread-2.23.so ];then
  logdebug "local file /koolshare/bxc/lib/opkg/libpthread-2.23.so faild, try remote install..."
  wget $URL/libpthread-2.23.so -O /opt/lib/libpthread-2.23.so > /dev/null 2>&1
  [ ! -f /opt/lib/libpthread-2.23.so ] && logerr "/opt/lib/libpthread-2.23.so download faild" && exit 1
fi

cd /opt/lib
chmod 755 ld-2.23.so
ln -s ld-2.23.so $DLOADER
ln -s libc-2.23.so libc.so.6
ln -s libpthread-2.23.so libpthread.so.0

logdebug "Basic packages installation..."
for pkg in `cat /koolshare/bxc/lib/opkg/pkg/install_order`
do
  logdebug "/opt/bin/opkg install /koolshare/bxc/lib/opkg/pkg/$pkg"
	/opt/bin/opkg install /koolshare/bxc/lib/opkg/pkg/$pkg > /dev/null 2>&1
done
pkg_exist=`/opt/bin/opkg list-installed | grep entware-opt > /dev/null 2>&1;echo $?`
if [ $pkg_exist -ne 0 ];then
  logdebug "entware-opt local install faild, try opkg remote install ..."
	/opt/bin/opkg update > /dev/null 2>&1
	/opt/bin/opkg install entware-opt > /dev/null 2>&1
fi
pkg_exist=`/opt/bin/opkg list-installed | grep entware-opt > /dev/null 2>&1;echo $?`
if [ $pkg_exist -ne 0 ];then
  logerr "entware-opt install faild, exit"
  exit 1
fi

# Fix for multiuser environment
chmod 777 /opt/tmp

# now try create symlinks - it is a std installation
if [ -f /etc/passwd ]
then
    ln -sf /etc/passwd /opt/etc/passwd
else
    cp /opt/etc/passwd.1 /opt/etc/passwd
fi

if [ -f /etc/group ]
then
    ln -sf /etc/group /opt/etc/group
else
    cp /opt/etc/group.1 /opt/etc/group
fi

if [ -f /etc/shells ]
then
    ln -sf /etc/shells /opt/etc/shells
else
    cp /opt/etc/shells.1 /opt/etc/shells
fi

if [ -f /etc/shadow ]
then
    ln -sf /etc/shadow /opt/etc/shadow
fi

if [ -f /etc/gshadow ]
then
    ln -sf /etc/gshadow /opt/etc/gshadow
fi

if [ -f /etc/localtime ]
then
    ln -sf /etc/localtime /opt/etc/localtime
fi

exit 0
