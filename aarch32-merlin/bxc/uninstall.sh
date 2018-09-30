#!/bin/sh

/koolshare/scripts/bxc.sh stop

dbus remove bxc_bcode
dbus remove bxc_option
dbus remove bxc_status
dbus remove bxc_wan_mac
dbus remove bxc_local_version
dbus remove bxc_node_info
dbus remove softcenter_module_bxc_install
dbus remove softcenter_module_bxc_version
dbus remove softcenter_module_bxc_title
dbus remove softcenter_module_bxc_description
dbus remove softcenter_module_bxc_home_url
dbus remove softcenter_module_bxc_name

rm /koolshare/bin/bxc-*
rm /koolshare/res/icon-bxc.png
rm /koolshare/res/bxc_run.htm
rm /koolshare/scripts/bxc*
rm /koolshare/webs/Module_BxC.asp
rm /koolshare/init.d/*bxc.sh
rm -rf /koolshare/bxc
rm /koolshare/scripts/uninstall_bxc.sh
rm -fr /tmp/etc/bxc-network
rm -fr /tmp/bxc_log.txt