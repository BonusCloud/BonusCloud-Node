#!/bin/sh

unset LD_LIBRARY_PATH
unset LD_PRELOAD

echo "Info: Checking for prerequisites and creating folders..."

if [ -d /opt ]
then
    echo "Warning: Folder /opt exists!"
else
    mkdir /opt
fi
# no need to create many folders. entware-opt package creates most
for folder in bin etc lib/opkg tmp var/lock
do
  if [ -d "/opt/$folder" ]
  then
    echo "Warning: Folder /opt/$folder exists!"
    echo "Warning: If something goes wrong please clean /opt folder and try again."
  else
    mkdir -p /opt/$folder
  fi
done

echo "Info: Opkg package manager deployment..."
DLOADER="ld-linux.so.3"
#URL=http://bin.entware.net/armv7sf-k2.6/installer
#wget $URL/opkg -O /opt/bin/opkg
#chmod 755 /opt/bin/opkg
#wget $URL/opkg.conf -O /opt/etc/opkg.conf
#wget $URL/ld-2.23.so -O /opt/lib/ld-2.23.so
#wget $URL/libc-2.23.so -O /opt/lib/libc-2.23.so
#wget $URL/libgcc_s.so.1 -O /opt/lib/libgcc_s.so.1
#wget $URL/libpthread-2.23.so -O /opt/lib/libpthread-2.23.so
cp -f /tmp/bxc/lib/opkg/opkg /opt/bin/opkg
chmod 755 /opt/bin/opkg
cp -f /tmp/bxc/lib/opkg/opkg.conf /opt/etc/opkg.conf
cp -f /tmp/bxc/lib/opkg/ld-2.23.so /opt/lib/ld-2.23.so
cp -f /tmp/bxc/lib/opkg/libc-2.23.so /opt/lib/libc-2.23.so
cp -f /tmp/bxc/lib/opkg/libgcc_s.so.1 /opt/lib/libgcc_s.so.1
cp -f /tmp/bxc/lib/opkg/libpthread-2.23.so /opt/lib/libpthread-2.23.so

cd /opt/lib
chmod 755 ld-2.23.so
ln -s ld-2.23.so $DLOADER
ln -s libc-2.23.so libc.so.6
ln -s libpthread-2.23.so libpthread.so.0

echo "Info: Basic packages installation..."
#/opt/bin/opkg update
#/opt/bin/opkg install entware-opt
for pkg in `cat /tmp/bxc/lib/opkg/pkg/install_order`
do
	/opt/bin/opkg install /tmp/bxc/lib/opkg/pkg/$pkg > /dev/null 2>&1
done
pkg_exist=`/opt/bin/opkg list-installed | grep entware-opt > /dev/null 2>&1;echo $?`
if [ $pkg_exist -ne 0 ];then
	/opt/bin/opkg update
	/opt/bin/opkg install entware-opt
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

echo "Info: Congratulations!"
echo "Info: If there are no errors above then Entware was successfully initialized."
echo "Info: Add /opt/bin & /opt/sbin to your PATH variable"
echo "Info: Add '/opt/etc/init.d/rc.unslung start' to startup script for Entware services to start"
echo "Info: Found a Bug? Please report at https://github.com/Entware/Entware/issues"
