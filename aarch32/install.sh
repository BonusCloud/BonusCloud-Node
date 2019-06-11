#!/usr/bin/env bash 

#https://github.com/BonusCloud/BonusCloud-Node/issues
#Author qinghon https://github.com/qinghon
OS=""
PG=""

BASE_DIR="/opt/bcloud"
BOOTCONFIG="$BASE_DIR/scripts/bootconfig"
NODE_INFO="$BASE_DIR/node.db"
SSL_CA="$BASE_DIR/ca.crt"
SSL_CRT="$BASE_DIR/client.crt"
SSL_KEY="$BASE_DIR/client.key"
VERSION_FILE="$BASE_DIR/VERSION"
DEVMODEL=$(tr -d '\0' </proc/device-tree/model)
DEFAULT_LINK=$(ip route list|grep 'default'|awk '{print $5}')
DEFAULT_MACADDR=$(ip link show ${DEFAULT_LINK}|grep 'ether'|awk '{print $2}')
SET_LINK=""
MACADDR=""

TMP="tmp"
LOG_FILE="ins.log"

K8S_LOW="1.12.3"
DOC_LOW="1.11.1"
DOC_HIG="18.06.3"

support_os=(
    centos
    debian
    fedora
    raspbian
    ubuntu
)
mirror_pods=(
    "https://raw.githubusercontent.com/BonusCloud/BonusCloud-Node/master"
    "https://raw.githubusercontent.com/qinghon/BonusCloud-Node/master"
)
mkdir -p $TMP
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
env_check(){
    # Check if the system is arm32
    if [[ "`uname -m |grep -qE 'arm';echo $?`" -ne 0 ]]; then
        log "[error]" "this is 64 system install script for arm64 ,if you's not ,please install correspond system"
        exit 1
    fi
    # Detection package manager
    ret_a=`which apt >/dev/null;echo $?`
    ret_y=`which yum >/dev/null;echo $?`
    if [[ $ret_a -eq 0 ]]; then
        PG="apt"
    elif [[ $ret_y -eq 0 ]]; then
        PG="yum"
    else
        log "[error]" "\"apt\" or \"yum\" ,not found ,exit "
        exit 1
    fi
    ret_c=`which curl >/dev/null;echo $?`
    ret_w=`which wget >/dev/null;echo $?`
    case ${PG} in
        apt )
            $PG install -y curl wget apt-transport-https
            ;;
        yum )
            $PG install -y curl wget
    esac
    # Check if the system supports
    [ ! -s $TMP/screenfetch ]&&wget  -nv --show-progress -O $TMP/screenfetch "https://raw.githubusercontent.com/KittyKatt/screenFetch/master/screenfetch-dev" 
    chmod +x $TMP/screenfetch
    OS=`$TMP/screenfetch -n |grep 'OS:'|awk '{print $3}'|tr 'A-Z' 'a-z'`
    if [[ -z "$OS" ]]; then
        read -p "The release version is not detected, please enter it manually,like \"ubuntu\"" OS
    fi
    if ! echo "${support_os[@]}"|grep -w "$OS" &>/dev/null ; then
        log "[error]" "This system is not supported by docker, exit"
        exit 1
    else
        log "[info]" "system : $OS ;Package manager $PG"
    fi
}
down(){
    for link in ${mirror_pods[@]}; do
        wget  -nv --show-progress "$link/$1" -O $2
        if [[ $? -eq 0 ]]; then
            break
        else
            continue
        fi
        log "[error]" "Download $link/$1 failed"
    done
    return 1
}
function version_ge() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"; }
function version_le() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" == "$1"; }
check_doc(){
    retd=`which docker>/dev/null;echo $?`
    if [ $retd -ne 0 ]; then
        log "[info]" "docker not found"
        return 1
    else
        doc_v=`docker version |grep Version|grep -o '[0-9\.]*'|sed -n '2p'`
        if version_ge $doc_v $DOC_LOW && version_le $doc_v $DOC_HIG ; then
            log "[info]" "docker version above $DOC_LOW and below $DOC_HIG"
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
check_info(){
    if [ ! -s $NODE_INFO ]; then
        touch $NODE_INFO
    else
        res=`grep -q -e '@' -e '-' $NODE_INFO; echo $? `
        if [ $res -ne 0 ]; then
            log "[info]" "$NODE_INFO file not found bcode or mail,need empty file "
            rm $NODE_INFO
            touch $NODE_INFO
        else
            log "[info]" "$NODE_INFO file have bcode or mail,skip"
        fi
        
    fi
}
ins_docker(){
    if ! check_doc ; then
        if [[ "$PG" == "apt" ]]; then
            # Install docker with APT
            curl -fsSL https://download.docker.com/linux/$OS/gpg | apt-key add -
            echo "deb https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/$OS  $(lsb_release -cs) stable"  >/etc/apt/sources.list.d/docker.list
            apt update
            for line in `apt-cache madison docker-ce|awk '{print $3}'` ; do
                if version_le `echo $line |egrep -o '([0-9]+\.){2}[0-9]+'` $DOC_HIG ; then
                    apt-mark unhold docker-ce
                    apt install -y --allow-downgrades docker-ce=$line 
                    if ! check_doc ; then
                        log "[error]" "docker install fail,please check Apt environment"
                        exit 1
                    else
                        log "[info]" "apt install -y --allow-downgrades docker-ce=$line "
                    fi
                    break
                fi
            done
            apt-mark hold docker-ce 
        elif [[ "$PG" == "yum" ]]; then
            # Install docker with yum
            yum install -y yum-utils
            yum-config-manager --add-repo  https://download.docker.com/linux/$OS/docker-ce.repo
            yum makecache
            for line in `yum list docker-ce --showduplicates|grep 'docker-ce'|awk '{print $2}'|sort -r` ; do
                if version_le `echo $line |egrep -o '([0-9]+\.){2}[0-9]+'` $DOC_HIG ; then
                    yum remove  -y docer-ce docker-ce-cli
                    if `echo $line|grep -q ':'` ; then
                        line=`echo $line|awk -F: '{print $2}'`
                    fi
                    yum install -y  docker-ce-$line 
                    if ! check_doc ; then
                        log "[error]" "docker install fail,please check yum environment"
                        exit 1
                    else
                        log "[info]" "yum install -y  docker-ce-$line "
                    fi
                    break
                fi
            done
        fi
        systemctl enable docker &&systemctl start docker
    else
        log "[info]" "docker was found! skiped"
    fi
}
init(){
    echo >$LOG_FILE
    systemctl enable ntp  >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        timedatectl set-ntp true
    else
        systemctl start ntp
    fi
    mkdir -p /etc/cni/net.d
    mkdir -p $BASE_DIR/{scripts,nodeapi,compute}
    swapoff -a
    env_check
    ins_docker
    check_info
}

ins_k8s(){
    yum_k8s(){
        cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-armhfp/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
        setenforce 0
        yum install  -y kubelet-1.12.3 kubeadm-1.12.3 kubectl-1.12.3 kubernetes-cni-0.6.0
        systemctl enable kubelet && systemctl start kubelet
    }
    apt_k8s(){
        curl -L https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
        echo "deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main"|tee /etc/apt/sources.list.d/kubernetes.list
        log "[info]" "installing k8s"
        apt update
        apt-mark unhold kubelet kubeadm kubectl kubernetes-cni
        apt install -y --allow-downgrades kubeadm=1.12.3-00 kubectl=1.12.3-00 kubelet=1.12.3-00 kubernetes-cni=0.6.0-00 
        apt-mark hold kubelet kubeadm kubectl kubernetes-cni
    }
    if ! check_k8s ; then
        if [[ "$PG" == "apt" ]]; then
            apt_k8s
        elif [[ "$PG" == "yum" ]]; then
            yum_k8s
        fi
        if ! check_k8s ; then
            log "[error]" "k8s install fail!"
            exit 1
        fi
    else
        log "[info]" " k8s was found! skip"
    fi
    
    docker pull registry.cn-beijing.aliyuncs.com/bxc_k8s_gcr_io/pause:arm32-3.1
    docker pull registry.cn-beijing.aliyuncs.com/bxc_k8s_gcr_io/kube-proxy-arm:v1.12.3
    docker tag registry.cn-beijing.aliyuncs.com/bxc_k8s_gcr_io/pause:arm32-3.1 k8s.gcr.io/pause:3.1
    docker tag registry.cn-beijing.aliyuncs.com/bxc_k8s_gcr_io/kube-proxy-arm:v1.12.3 k8s.gcr.io/kube-proxy:v1.12.3
    
    cat <<EOF >  /etc/sysctl.d/k8s.conf
vm.swappiness = 0
net.ipv6.conf.default.forwarding = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv6.conf.tun0.mtu = 1280
net.ipv4.tcp_congestion_control = bbr
net.ipv4.ip_forward = 1
EOF
    modprobe br_netfilter
    echo "tcp_bbr">>/etc/modules
    sysctl -p /etc/sysctl.d/k8s.conf 2>/dev/null
    log "[info]" "k8s install over"
}
ins_conf(){
    down "aarch32/res/compute/10-mynet.conflist" "$BASE_DIR/compute/10-mynet.conflist"
    down "aarch32/res/compute/99-loopback.conf" "$BASE_DIR/compute/99-loopback.conf"
}
_set_node_systemd(){
    if [[ -z "${SET_LINK}" ]]; then
        INSERT_STR="#--intf ${DEFAULT_LINK}"
    else
        INSERT_STR="--intf ${SET_LINK}"
    fi
    cat <<EOF >/lib/systemd/system/bxc-node.service
[Unit]
Description=bxc node app
After=network.target

[Service]
ExecStart=/opt/bcloud/nodeapi/node --alsologtostderr ${INSERT_STR}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
}
ins_node(){
    arch=`uname -m`
    kel_v=`uname -r|egrep  -o '([0-9]+\.){2}[0-9]'`
    Rlink="img-modules"
    if  version_ge $kel_v "5.0.0" ; then
        Rlink="$Rlink/5.0.0-aml-N1-BonusCloud"
    fi
    down "$Rlink/info.txt" "$TMP/info.txt"
    if [ ! -s "$TMP/info.txt" ]; then
        log "[error]" "wget \"$Rlink/info.txt\" -O $TMP/info.txt"
        return 1
    fi
    for line in `grep "$arch" $TMP/info.txt`
    do
        git_file_name=`echo $line | awk -F: '{print $1}'`
        git_md5_val=`echo $line | awk -F: '{print $2}'`
        file_path=`echo $line | awk -F: '{print $3}'`
        mod=`echo $line | awk -F: '{print $4}'`
        local_md5_val=`[ -x $file_path ] && md5sum $file_path | awk '{print $1}'`
        
        if [[ "$local_md5_val"x == "$git_md5_val"x ]]; then
            log "[info]" "local file $file_path version equal git file version,skip"
            continue
        fi
        down "$Rlink/$git_file_name" "$TMP/$git_file_name" 
        download_md5=`md5sum $TMP/$git_file_name | awk '{print $1}'`
        if [ "$download_md5"x != "$git_md5_val"x ];then
            log "[error]" " download file $TMP/$git_file_name md5 $download_md5 different from git md5 $git_md5_val"
            continue
        else
            log "[info]" " $TMP/$git_file_name download success."
            cp -f $TMP/$git_file_name $file_path > /dev/null
            chmod $mod $file_path > /dev/null            
        fi
    done
    _set_node_systemd
    systemctl daemon-reload
    systemctl enable bxc-node
    systemctl start bxc-node
    sleep 1
    isactive=`ps aux | grep -v grep | grep "nodeapi/node" > /dev/null; echo $?`
    if [ $isactive -ne 0 ];then
        log "[error]" " node start faild, rollback and restart"
        systemctl restart bxc-node
    else
        log "[info]" " node start success."
    fi
}

ins_salt(){
    which salt-minion>/dev/null
    if [[ $? -ne 0 ]] ;then
        case $OS in
            raspbian|debian )
                curl -fSL https://bootstrap.saltstack.com |bash -s -P git v2017.7.2
                ;;
            * )
                curl -fSL https://bootstrap.saltstack.com |bash -s -P stable 2019.2.0
                ;;
        esac
    fi
    if [[ '${DEVMODEL}' == '' ]]; then
        DEVMODEL="Unknow"
    fi
    if [[ -z "${MACADDR}" ]]; then
        ID_STR="id: ${DEVMODEL}_${DEFAULT_MACADDR}"
    else
        ID_STR="id: ${DEVMODEL}_${MACADDR}"
    fi
    cat <<EOF >/etc/salt/minion
master: nodemaster.bxcearth.com
master_port: 14506
user: root
log_level: quiet
${ID_STR}
EOF
    rm /var/lib/salt/pki/minion/minion_master.pub 2>/dev/null
    systemctl restart salt-minion
}
ins_salt_check(){
    echo "Would you like to install salt-minion for remote debugging by developers? "
    echo "If not, the program has problems, you need to solve all the problems you encounter  "
    echo "您是否愿意安装salt-minion ，供开发人员远程调试."
    echo "如果否，程序出了问题，您需要自己解决所有遇到的问题，默认YES"
    read -p "[Default YES/N]:" choose
    case $choose in
        N|n|no|NO ) return ;;
        * ) ins_salt;;
    esac
}

_select_interface(){
    if [[  -n $0 ]]; then
        SET_LINK=$1
    fi
    MACADDR=$(ip link show ${SET_LINK}|grep 'ether'|awk '{print $2}')
    if [[ -z "${MACADDR}" ]]; then
        log "[error]" "Get interface ${SET_LINK} mac address get error"
        SET_LINK=""
    fi
}
verifty(){
    [ ! -s $BASE_DIR/nodeapi/node ] && return 2
    [ ! -s $BASE_DIR/compute/10-mynet.conflist ] && return 3
    [ ! -s $BASE_DIR/compute/99-loopback.conf ] && return 4
    log "[info]" "verifty file over"
    return 0 
}
remove(){
    read -p "Are you sure all remove BonusCloud plugin? yes/n:" CHOSE
    case $CHOSE in
        yes )
            systemctl disable bxc-node
            rm -rf /opt/bcloud /lib/systemd/system/bxc-node.service $TMP
            echo "BonusCloud plugin removed"
            
            apt remove -y kubelet kubectl kubeadm
            echo "k8s removed"
            echo "see you again!"
            ;;
        * )
            exit 0
            ;;
    esac

}
displayhelp(){
    echo "bash $0 [option]" 
    echo -e "    -h             Print this and exit"
    echo -e "    -i             Installation environment check and initialization"
    echo -e "    -k             Install the k8s environment and the k8s components that" 
    echo -e "                   BonusCloud depends on"
    echo -e "    -n             Install node management components"
    echo -e "    -r             Fully remove bonuscloud plug-ins and components"
    echo -e "    -s             Install salt-minion for remote debugging by developers"
    echo -e "    -I Interface   set interface name to you want"
    echo -e "    -c             change kernel to compiled dedicated kernels,only \"Phicomm N1\"" 
    echo -e "                   and is danger!"
    exit 0
}
while  getopts "iknrschI:" opt ; do
    case $opt in
        i ) action="init" ;;
        k ) action="k8s" ;;
        n ) action="node" ;;
        r ) action="remove" ;;
        s ) action="salt" ;;
        c ) action="change_kn" ;;
        h ) displayhelp ;;
        I ) _select_interface ${OPTARG} ;;
        ?) echo "Unknow arg. exiting" ;exit 1 ;;
    esac
done
case $action in
    init     ) init ;;
    node     ) ins_node ;;
    remove   ) remove ;;
    salt     ) ins_salt ;;
    change_kn) ins_kernel ;;
    k8s      )
        env_check
        ins_k8s
        ;;
    * )
        init
        ins_k8s
        ins_conf
        ins_node
        ins_salt_check
        res=`verifty;echo $?` 
        if [[ $res -ne 0 ]] ; then
            log "[error]" "verifty error $res,install fail"
        else
            log "[info]" "All install over"
        fi
        ;;
esac
sync