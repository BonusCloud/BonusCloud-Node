#!/bin/bash 

#https://github.com/BonusCloud/BonusCloud-Node/issues

BASE_DIR="/opt/bcloud"
BOOTCONFIG="$BASE_DIR/scripts/bootconfig"
NODE_INFO="$BASE_DIR/node.db"
SSL_CA="$BASE_DIR/ca.crt"
SSL_CRT="$BASE_DIR/client.crt"
SSL_KEY="$BASE_DIR/client.key"
VERSION_FILE="$BASE_DIR/VERSION"
REPORT_URL="https://bxcvenus.com/idb/dev"

TMP="tmp"
LOG_FILE="ins.log"

K8S_LOW="1.12.3"
DOC_LOW="1.11.1"

log(){
    if [ "$1" = "[error]" ]; then
        echo "[`date '+%Y-%m-%d %H:%M:%S'`] $1 $2" >>$LOG_FILE
        echo -e "[`date '+%Y-%m-%d %H:%M:%S'`] \033[31m $1 $2 \033[0m"
    elif [ "$1" = "[info]" ]; then
        echo "[`date '+%Y-%m-%d %H:%M:%S'`] $1 $2" >>$LOG_FILE
    else
        echo "[`date '+%Y-%m-%d %H:%M:%S'`] [debug] $1 $2" >>$LOG_FILE
    fi
}
function version_ge() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"; }
check_doc(){
    retd=`which docker>/dev/null;echo $?`
    if [ $retd -ne 0 ]; then
        log "[info]" "docker not found"
        return 1
    else
        doc_v=`docker version |grep Version|grep -o '[0-9\.]*'|head -n 1`
        if version_ge $doc_v $DOC_LOW ; then
            log "[info]" "docker version ok"
            return 0
        else
            log "[info]" "docker version fail"
            return 1
        fi
    fi
}
check_k8s(){
    reta=`which kubeadm>/dev/null;echo $?`
    retl=`which kubelet>/dev/null;echo $?`
    retc=`which kubectl>/dev/null;echo $?`
    if [ $reta -ne 0 ] || [ $retl -ne 0 ] || [ $retc -ne 0 ] ; then
        log "[info]" "k8s not found"
        return 1
    else 
        k8s_adm=`kubeadm version|grep -o '\"v[0-9\.]*\"'|grep -o '[0-9\.]*'`
        k8s_let=`kubelet --version|grep -o '[0-9\.]*'`
        k8s_ctl=`kubectl  version --short --client|grep -o '[0-9\.]*'`
        if version_ge $k8s_adm $K8S_LOW ; then
            log "[info]" "kubeadm version ok"
        else
            log "[info]" "kubeadm version fail"
            return 1
        fi
        if version_ge $k8s_let $K8S_LOW ; then
            log "[info]"  "kubelet version ok"
        else
            log "[info]"  "kubelet version fail"
            return 1
        fi
        if version_ge $k8s_ctl $K8S_LOW ; then
            log "[info]"  "kubectl version ok"
        else
            log "[info]"  "kubectl version fail"
            return 1
        fi
        return 0
    fi
}
check_apt(){
    ret=`which apt >/dev/null;echo $?`
    if [ $ret -ne 0 ]; then
        log "[error]" "apt not found !install fail"
        exit 1
    fi
    ret=`getconf LONG_BIT`
    if [ "$ret" -ne 64 ]; then
        log "[error]" "this is 64 system install script ,if you's not ,please install correspond system"
        exit 1
    fi
    apt update
    apt install -y curl apt-transport-https
}
down_env(){
    ret=`$BASE_DIR/bxc-network 2>&1`
    if [ -z "$ret" ]; then
        return 0
    fi 
    mkdir -p /usr/lib/bxc
    echo "/usr/lib/bxc">/etc/ld.so.conf.d/bxc.conf
    #lib_url="https://raw.githubusercontent.com/BonusCloud/BonusCloud-Node/master/aarch64/res/lib"
    lib_url="https://raw.githubusercontent.com/qinghon/BonusCloud-Node/master/aarch64/res/lib"
    i=44
    wget "$lib_url/lib_md5" -O $TMP/lib_md5
    if [ ! -s "$TMP/lib_md5" ]; then
        log "[error]" "wget \"$lib_url/lib_md5\" -O $TMP/lib_md5 ,you can try ./install.sh down_env"
        return 1 
    fi
    while `$BASE_DIR/bxc-network 2>&1|grep -q 'libraries'` ; do
        LIB=`$BASE_DIR/bxc-network 2>&1|awk -F: '{print $3}'|awk '{print $1}'`
        log "[info]" "$LIB will download"
        wget "$lib_url/$LIB" -O /usr/lib/bxc/$LIB
        local_md5=`md5sum /usr/lib/bxc/$LIB|awk '{print $1}'`
        git_md5=`grep -F "$LIB" "$TMP/lib_md5"|awk '{print $1}'`
        if [[ "$local_md5"x != "$git_md5"x ]]; then
            log "[error]" "git lib file md5 $git_md5 not equal $local_md5 download lib file md5,try agin"
            rm -f /usr/lib/bxc/$LIB
            continue
        else
            ldconfig
        fi
        if [[ $i -le 0 ]]; then
            log "[error]" "`$BASE_DIR/bxc-network 2>&1`"
            break
        fi
        i=`expr $i - 1`
        echo "$i"
    done
    
}
check_info(){
    if [ ! -s $NODE_INFO ]; then
        touch $NODE_INFO
    else
        res=`grep -q -e '@' -e '-' $NODE_INFO; echo $? `
        if [ $res -ne 0 ]; then
            log "" "$NODE_INFO file not found bcode or mail,need empty file "
            rm $NODE_INFO
            touch $NODE_INFO
        else
            log "[info]" "$NODE_INFO file have bcode or mail,skip"
        fi
        
    fi
}
ins_docker(){
    if ! check_doc ; then
        apt install -y docker.io
    else
        log "[info]" " docker was found! skiped"
    fi
}
init(){
    echo >$LOG_FILE
    systemctl enable ntp
    if [ $? -ne 0 ]; then
        timedatectl set-ntp true
    else
        systemctl start ntp
    fi
    swapoff -a
    check_apt  
    apt update 
    ins_docker
    mkdir -p /etc/cni/net.d
    mkdir -p $BASE_DIR/scripts $BASE_DIR/nodeapi $BASE_DIR/compute
    mkdir -p $TMP
    check_info
}

ins_k8s(){
    if ! check_k8s ; then
        curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
        cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF
        log "[info]" "installing k8s"
        apt update
        apt install -y kubeadm=1.12.3-00 kubectl=1.12.3-00 kubelet=1.12.3-00
        apt-mark hold kubelet kubeadm kubectl
        if ! check_k8s ; then
            log "[error]" "k8s install fail!"
            exit 1
        fi
    else
        log "[info]" " k8s was found! skip"
    fi
    
    docker pull registry.cn-beijing.aliyuncs.com/bxc_k8s_gcr_io/pause:arm-3.1
    docker pull registry.cn-beijing.aliyuncs.com/bxc_k8s_gcr_io/kube-proxy-arm:v1.12.3
    docker tag registry.cn-beijing.aliyuncs.com/bxc_k8s_gcr_io/pause:arm-3.1 k8s.gcr.io/pause:3.1
    docker tag registry.cn-beijing.aliyuncs.com/bxc_k8s_gcr_io/kube-proxy-arm:v1.12.3 k8s.gcr.io/kube-proxy:v1.12.3
    
    docker pull  registry.cn-beijing.aliyuncs.com/bxc_public/bxc-worker:v2-arm64

    docker tag registry.cn-beijing.aliyuncs.com/bxc_public/bxc-worker:v2-arm64 bxc-worker:v2
    cat <<EOF >  /etc/sysctl.d/k8s.conf
vm.swappiness = 0
net.ipv6.conf.default.forwarding = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
    sysctl -p /etc/sysctl.d/k8s.conf
    log "[info]" "k8s install over"
}
ins_conf(){
    wget https://github.com/BonusCloud/BonusCloud-Node/raw/master/aarch64/res/compute/10-mynet.conflist -O $BASE_DIR/compute/10-mynet.conflist
    wget https://github.com/BonusCloud/BonusCloud-Node/raw/master/aarch64/res/compute/99-loopback.conf -O $BASE_DIR/compute/99-loopback.conf
}
ins_node(){
    arch=`uname -m`
    curl -s -t 3 -m 5 "https://raw.githubusercontent.com/BonusCloud/BonusCloud-Node/master/img-modules/md5.txt" -o $TMP/md5.txt
    if [ ! -s "$TMP/md5.txt" ]; then
        log "[error]" "curl -s -t 3 -m 5 \"https://raw.githubusercontent.com/BonusCloud/BonusCloud-Node/master/img-modules/md5.txt\" -O $TMP/md5.txt"
        return 1
    fi
    for line in `grep "$arch" $TMP/md5.txt`
    do
        git_file_name=`echo $line | awk -F: '{print $1}'`
        git_md5_val=`echo $line | awk -F: '{print $2}'`
        file_path=`echo $line | awk -F: '{print $3}'`
        start_wait=`echo $line | awk -F: '{print $4}'`
        local_md5_val=`md5sum $file_path | awk '{print $1}'`

        if [[ "$local_md5_val"x == "$git_md5_val"x ]]; then
            log "[info]" "local file $file_path version equal git file version,skip"
            continue
        fi
        curl -s -t 3 -m 300 "https://raw.githubusercontent.com/BonusCloud/BonusCloud-Node/master/img-modules/$git_file_name" -o $TMP/$git_file_name
        download_md5=`md5sum $TMP/$git_file_name | awk '{print $1}'`
        if [ "$download_md5"x != "$git_md5_val"x ];then
            log "[error]" " download file $TMP/$git_file_name md5 $download_md5 different from git md5 $git_md5_val, ignore this update and continue ..."
            continue
        else
            log "[info]" " $TMP/$git_file_name download success."
            #cp -f $file_path ${file_path}.bak > /dev/null
            cp -f $TMP/$git_file_name $file_path > /dev/null
            chmod +x $file_path > /dev/null            
        fi
    done
    git_version=`grep "version" $TMP/md5.txt | awk -F: '{print $2}'`
    echo $git_version >$VERSION_FILE
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
    down_env
    isactive=`ps aux | grep -v grep | grep "nodeapi/node" > /dev/null; echo $?`
    if [ $isactive -ne 0 ];then
        log "[error]" " node start faild, rollback and restart"
        systemctl restart bxc-node
    else
        log "[info]" " node start success."
    fi
}

ins_bxcup(){
    wget https://github.com/BonusCloud/BonusCloud-Node/raw/master/aarch64/res/bxc-update -O /etc/cron.daily/bxc-update
    chmod +x /etc/cron.daily/bxc-update
    log "[info]"" install bxc_update over"
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
    log "[info]" " verifty file over"
    return 0 
}
check_v(){
    res=`grep -q 'v' $VERSION_FILE; echo $?`
    if [ $res -ne 0 ]; then
        log "[error]" "$VERSION_FILE not find version,try reinstall "
    else
        log "[info]" "$VERSION_FILE found"
    fi
    return "$res"
}
report_V(){
    report(){
        local_version=`cat $VERSION_FILE`
        mac=`ip addr list dev eth0 | grep "ether" | awk '{print $2}'`
        bcode=` cat $NODE_INFO |sed 's/,/\n/g' | grep "bcode" | awk -F: '{print $NF}' | sed 's/"//g'`
        status_code=`curl -m 5 -k --cacert $SSL_CA --cert $SSL_CRT --key $SSL_KEY -H "Content-Type: application/json" -d "{\"mac\":\"$mac\", \"info\":\"$local_version\"}" -X PUT -w "\nstatus_code:"%{http_code}"\n" "$REPORT_URL/$bcode" | grep "status_code" | awk -F: '{print $2}'`
        if [ $status_code -eq 200 ];then
            log "[info]" "version $local_version reported success!"
        else
            log "[error]" "version reported failed($status_code):curl -m 5 -k --cacert $SSL_CA --cert $SSL_CRT --key $SSL_KEY -H \"Content-Type: application/json\" -d \"{\"mac\":\"$mac\", \"info\":\"$local_version\",}\" -X PUT -w \"status_code:\"%{http_code}\" \"$REPORT_URL/$bcode\""
        fi
    }
    if [ ! -s $SSL_CA ] || [ ! -s $SSL_CRT ] || [ ! -s $SSL_KEY ] || [ ! -s $NODE_INFO ];then
        log "[error]" "ssl file or node.db file not found, ignore to report verison."
        exit 1
    fi
    check_v
    if  [ $? -ne 0 ] ; then
        ins_node
        check_v
        if [ $? -ne 0 ] ; then
            log "[error]" "install node failed"
            exit 1
        else 
            log "[info]" "update node success,try report version"
            report
        fi
    else
        report
    fi
}
remove(){
    read -p "Are you sure all remove BonusCloud plugin? yes/n:" CHOSE
    if [ -z $CHOSE ]; then
        exit 0
    elif [ "$CHOSE" == "n" -o "$CHOSE" == "N" -o "$CHOSE" == "no" ]; then
        exit 0
    elif [ "$CHOSE" == "yes" -o "$CHOSE" == "YES" ]; then
        rm -rf /opt/bcloud /lib/systemd/system/bxc-node.service /etc/cron.daily/bxc-update
        echo "BonusCloud plugin removed"
        rm -rf /etc/ld.so.conf.d/bxc.conf /usr/lib/bxc
        echo "libraries removed"
        apt remove -y kubelet kubectl kubeadm
        echo "k8s removed"
        
        echo "see you again!"
    fi
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
    bxcup )
        ins_bxcup
        ;;
    down_env )
        down_env
        ;;
    report_v )
        report_V
        ;;
    remove )
        remove
        ;;
    * )
        init
        ins_k8s
        ins_conf
        ins_node
        ins_bxcup
        if ! verifty ; then
            log "[error]" " verifty error ,install fail"
        else
            log "[info]" "all install over"
        fi
        ;;
esac
