#!/bin/sh

BASE_DIR="/opt/bcloud"
BOOTCONFIG="$BASE_DIR/scripts/bootconfig"
NODE_INFO="$BASE_DIR/node.db"
LOG_FILE="ins.log"

log(){
   echo "[`date '+%Y-%m-%d %H:%M:%S'`] $1" >$LOG_FILE
}
init(){
    systemctl enable ntp
    systemctl start ntp

    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

    curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
    cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF
    apt update 
    apt install -y docker.io salt-minion
    mkdir -p /etc/cni/net.d
    mkdir -p /opt/bcloud/scripts
    if [ ! -s $NODE_INFO ]; then
        touch $NODE_INFO
    else
        rm $NODE_INFO
        touch $NODE_INFO
    fi
    cp -r ./res/compute $BASE_DIR
}

ins_k8s(){
    apt install -y kubeadm=1.12.3-00 kubectl=1.12.3-00 kubelet=1.12.3-00
    apt-mark hold kubelet kubeadm kubectl

    docker pull registry.cn-beijing.aliyuncs.com/bxc_k8s_gcr_io/pause:arm-3.1
    docker pull registry.cn-beijing.aliyuncs.com/bxc_k8s_gcr_io/kube-proxy-arm:v1.12.3
    docker tag registry.cn-beijing.aliyuncs.com/bxc_k8s_gcr_io/pause:arm-3.1 k8s.gcr.io/pause:3.1
    docker tag registry.cn-beijing.aliyuncs.com/bxc_k8s_gcr_io/kube-proxy-arm:v1.12.3 k8s.gcr.io/kube-proxy:v1.12.3
    
    docker pull  registry.cn-beijing.aliyuncs.com/bxc_public/bxc-worker:v2-arm64

    docker tag 08367 bxc-worker:v2
    cat <<EOF >  /etc/sysctl.d/k8s.conf
vm.swappiness = 0
net.ipv6.conf.default.forwarding = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
    sysctl -p /etc/sysctl.d/k8s.conf
    log "k8s install over"
}
ins_node(){
    mkdir -p /opt/bcloud/nodeapi 
    mkdir -p /opt/bcloud/scripts
    arch=`uname -m`
    curl -s -t 3 -m 5 "https://raw.githubusercontent.com/BonusCloud/BonusCloud-Node/master/img-modules/md5.txt" -o /tmp/md5.txt
    if [ ! -s "/tmp/md5.txt" ]; then
        log "[error] curl -t 3 -m 5 \"https://raw.githubusercontent.com/BonusCloud/BonusCloud-Node/master/img-modules/md5.txt\" -o /tmp/md5.txt"
        return
    fi
    for line in `grep "$arch" /tmp/md5.txt`
    do
        git_file_name=`echo $line | awk -F: '{print $1}'`
        git_md5_val=`echo $line | awk -F: '{print $2}'`
        file_path=`echo $line | awk -F: '{print $3}'`
        start_wait=`echo $line | awk -F: '{print $4}'`
        #local_md5_val=`md5sum $file_path | awk '{print $1}'`
    
        curl -s -t 3 -m 300 "https://raw.githubusercontent.com/BonusCloud/BonusCloud-Node/master/img-modules/$git_file_name" -o /tmp/$git_file_name
        download_md5=`md5sum /tmp/$git_file_name | awk '{print $1}'`
        if [ "$download_md5"x != "$git_md5_val"x ];then
            log "[error] download file /tmp/$git_file_name md5 $download_md5 different from git md5 $git_md5_val, ignore this update and continue ..."
            continue
        else
            log "[info] /tmp/$git_file_name download success."
            #cp -f $file_path ${file_path}.bak > /dev/null
            cp -f /tmp/$git_file_name $file_path > /dev/null
            chmod +x $file_path > /dev/null            
        fi
        
    done
    cat <<EOF >/lib/systemd/system/bxc-node.service
[Unit]
Description=bxc node app
After=network.target

[Service]
ExecStart=/opt/bcloud/nodeapi/node
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable bxc-node
    systemctl start bxc-node
    isactive=`ps aux | grep -v grep | grep "nodeapi/node" > /dev/null; echo $?`
    if [ $isactive -ne 0 ];then
        log "[error] node start faild, rollback and restart"
        systemctl restart bxc-node
    else
        log "[info] node start success."
    fi
}

ins_salt(){
    res=`grep 'Reatart=always' /lib/systemd/system/salt-minion.service`
    if [ -z "$res" ]; then
        sed -i '/salt-minion/a\Reatart=always\nRestartSec=30' /lib/systemd/system/salt-minion.service
    else
        log "[info] service already chranged!" 
    fi
    echo -e "master: nodeadmin.bxcearth.com\nmaster_port: 14506\nuser: root" > /etc/salt/minion
    systemctl restart salt-minion
    systemctl daemon-reload
    log "[info] install salt over"
}
ins_bc(){
    cat <<EOF >"$BOOTCONFIG"
#!/bin/sh

DEVMODEL=`cat /proc/device-tree/model | sed 's/ /-/g'`
MACADDR=`ip addr list dev eth0 | grep "ether" | awk '{print $2}'`

saltconfig() {
    sed -i "/^id:/d" /etc/salt/minion
    echo "id: ${DEVMODEL}_${MACADDR}" >> /etc/salt/minion
    /etc/init.d/salt-minion restart > /dev/null 2>&1
}
saltconfig
clear
exit 0
EOF
    chmod +x "$BOOTCONFIG"
    res=`grep 'bootconfig' /etc/rc.local`
    if [ -z "$res" ]; then
        sed -i '/exit/i\\/opt\/bcloud\/scripts\/bootconfig' /etc/rc.local
    else
        log "[info] rc.local is chranged"
    fi
    log "[info] install bootconfig over"
}
ins_bxcup(){
    cp ./res/bxc-update /etc/cron.daily/bxc-update
    chmod +x /etc/cron.daily/bxc-update
    log "[info] install bxc_update over"
}
verifty(){
    if [ ! -s $BASE_DIR/bxc-network ]; then
        return 1
    fi
    if [ ! -s $BASE_DIR/nodeapi/node ]; then
        return 2
    fi
    if [ ! -s $BASE_DIR/compute/10-mynet.conflist ]; then
        return 3
    fi
    if [ ! -s $BASE_DIR/compute/99-loopback.conf ]; then
        return 4
    fi
    if [ ! -s $BOOTCONFIG ]; then
        return 5
    fi
    log "[info] verifty over"
    return 0 
}

case $1 in
    init )
        init
        ;;
    k8s )
        ins_k8s
        ;;
    node )
        ins_node
        ;;
    salt )
        ins_salt
        ;;
    bc )
        ins_bc
        ;;
    bxcup )
        ins_bxcup
        ;;
    * )
        init
        ins_k8s
        ins_node
        ins_salt
        ins_bc
        ins_bxcup
        verifty
        res=`echo $?`
        if [ $res -ne 0 ]; then
            echo "install faild! return $res"
            log "[error] verifty error ,install fail"
        fi
        ;;
esac
