#!/usr/bin/env bash 

#https://github.com/BonusCloud/BonusCloud-Node/issues
#Author qinghon https://github.com/qinghon

OS=""
OS_CODENAME=""
PG=""
ARCH=""
VDIS=""
BASE_DIR="/opt/bcloud"
NODE_INFO="$BASE_DIR/node.db"
SSL_CA="$BASE_DIR/ca.crt"
SSL_CRT="$BASE_DIR/client.crt"
SSL_KEY="$BASE_DIR/client.key"
DEVMODEL=$(cat /proc/device-tree/model 2>/dev/null |tr -d '\0')
DEFAULT_LINK=$(ip route list|grep 'default'|head -n 1|awk '{print $5}')
if [[ -n $DEFAULT_LINK ]]; then
    DEFAULT_MACADDR=$(ip link show "${DEFAULT_LINK}"|grep 'ether'|awk '{print $2}')
    DEFAULT_GW=$(ip route list|grep 'default'|head -n 1|awk '{print $3}')
    DEFAULT_SUBNET=$(ip addr show "${DEFAULT_LINK}"|grep 'inet '|awk '{print $2}')
    DEFAULT_HOSTIP=$(echo "${DEFAULT_SUBNET}"|awk -F/ '{print $1}')
fi

SET_LINK=""
MACADDR=""

TMP="tmp"
mkdir -p $TMP
LOG_FILE="ins.log"

K8S_LOW="1.12.3"
DOC_LOW="1.11.1"
DOC_HIG="18.06.4"

support_os=(
    centos
    debian
    fedora
    raspbian
    ubuntu
)
mirror_pods=(
    "https://raw.githubusercontent.com/BonusCloud/BonusCloud-Node/master"
    "https://bonuscloud-node.s3.cn-north-1.jdcloud-oss.com"
)


echoerr(){ printf "\033[1;31m$1\033[0m" 
}
echoinfo(){ printf "\033[1;32m$1\033[0m"
}
echowarn(){ printf "\033[1;33m$1\033[0m"
}
echo-(){
    local columns
    columns=$(stty size 2>/dev/null|awk '{print $2}')
    columns=${columns:-80}
    yes "-"|sed "${columns}q"|tr -d '\n'
    printf "\n"
}
log(){
    timeOut="[$(date '+%Y-%m-%d %H:%M:%S')]"
    case $1 in
        "[error]" )
            echo "${timeOut} $1 $2" >>$LOG_FILE
            echoerr "${timeOut} $1 $2\n"
            ;;
        "[info]" )
            echo "${timeOut} $1 $2" >>$LOG_FILE
            [[ "${DISPLAYINFO}" == "1" ]]&&echoinfo "${timeOut} $1 $2\n"
            ;;
        "[warn]" )
            echo "${timeOut} $1 $2" >>$LOG_FILE
            echowarn "${timeOut} $1 $2\n"
            ;;
    esac
}
sysArch(){
    ARCH=$(uname -m)
    if   [[ "$ARCH" == "i686" ]] || [[ "$ARCH" == "i386" ]]; then
        VDIS="32"
    elif [[ "$ARCH" == "x86_64" ]] ; then
        VDIS="amd64"
    elif [[ "$ARCH" == *"armv7"* ]] || [[ "$ARCH" == "armv6l" ]]; then
        VDIS="arm"
    elif [[ "$ARCH" == *"armv8"* ]] || [[ "$ARCH" == "aarch64" ]]; then
        VDIS="arm64"
    elif [[ "$ARCH" == *"mips64le"* ]]; then
        VDIS="mips64le"
    elif [[ "$ARCH" == *"mips64"* ]]; then
        VDIS="mips64"
    elif [[ "$ARCH" == *"mipsle"* ]]; then
        VDIS="mipsle"
    elif [[ "$ARCH" == *"mips"* ]]; then
        VDIS="mips"
    elif [[ "$ARCH" == *"s390x"* ]]; then
        VDIS="s390x"
    elif [[ "$ARCH" == "ppc64le" ]]; then
        VDIS="ppc64le"
    elif [[ "$ARCH" == "ppc64" ]]; then
        VDIS="ppc64"
    fi
    return 0
}
sys_codename(){
    if  which lsb_release >/dev/null  2>&1; then
        OS_CODENAME=$(lsb_release -cs)
    fi
}
run_as_root(){
    # 检测是否有root权限
    if [[ $(id -u) -eq 0 ]]; then
        return 0
    fi
    if which sudo >/dev/null 2>&1; then
        echoerr "Please run as sudo:\nsudo bash $0 $1\n"
        exit 1
    else
        echoerr "Please run as root user!\n"
        exit 2
    fi
}
env_check(){
    # 检查环境
    # Detection package manager
    if which apt >/dev/null 2>&1 ; then
        echoinfo "Find apt\n"
        PG="apt"
    elif which yum >/dev/null 2>&1 ; then
        echoinfo "Find yum\n"
        PG="yum"
    elif which pacman>/dev/null 2>&1 ; then
        log "[info]" "Find pacman"
        PG="pacman"
    else
        log "[error]" "\"apt\" or \"yum\" ,not found ,exit "
        exit 1
    fi
    ret_c=$(which curl >/dev/null 2>&1;echo $?)
    ret_w=$(which wget >/dev/null 2>&1;echo $?)
    case ${PG} in
        apt ) $PG install -y curl wget apt-transport-https pciutils;;
        yum ) $PG install -y curl wget ;;
    esac
    # Check if the system supports
    # 使用screenfetch工具检测系统发行版
    [[ ! -s $TMP/screenfetch ]]&&down "screenfetch-dev" "$TMP/screenfetch"
    chmod +x $TMP/screenfetch
    OS_line=$($TMP/screenfetch -n |grep 'OS:')
    OS=$(echo "$OS_line"|awk '{print $3}'|tr '[:upper:]' '[:lower:]')
    if [[ -z "$OS" ]]; then
        source /etc/os-release
        if echo "${support_os[@]}"|grep -w "$ID" &>/dev/null  ; then
            OS="$ID"
            case $ID in
                ubuntu ) OS_CODENAME="$VERSION_CODENAME" ;;
            esac
        else
            read -r -p "The release version is not detected, please enter it manually,like \"ubuntu\"" OS
        fi
    fi
    if ! echo "${support_os[@]}"|grep -w "$OS" &>/dev/null ; then
        log "[error]" "This system is not supported by docker, exit"
        exit 1
    else
        log "[info]" "system : $OS ;Package manager $PG"
    fi
}
down(){
    # 根据设置的源下载文件,错误时切换源
    for link in "${mirror_pods[@]}"; do
        
        if wget -t 2 --timeout=3  "${link}/$1" -O "$2" ; then
            break
        else
            continue
        fi
        log "[error]" "Download ${link}/$1 failed"
    done
    return 1
}
# 版本大小对比函数
function version_ge() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"; }
function version_le() { test "$(echo "$@" | tr " " "\n" | sort -V  | head -n 1)" == "$1"; }
check_doc(){
    # 检查docker 安装状态和版本
    retd=$(which docker>/dev/null;echo $?)
    if [ "${retd}" -ne 0 ]; then
        log "[info]" "docker not found"
        return 1
    fi
    doc_v=$(docker version --format "{{.Server.Version}}")
    if version_ge "${doc_v}" "${DOC_LOW}" && version_le "${doc_v}" "${DOC_HIG}" ; then
        log "[info]" "dockerd version ${doc_v} above ${DOC_LOW} and below ${DOC_HIG}"
        return 0
    else
        log "[info]" "docker version ${doc_v} fail"
        return 2
    fi
}
check_k8s(){
    # 检查k8s安装状态和版本
    reta=$(which kubeadm>/dev/null 2>&1;echo $?)
    retl=$(which kubelet>/dev/null 2>&1;echo $?)
    retc=$(which kubectl>/dev/null 2>&1;echo $?)
    if [ "${reta}" -ne 0 ] || [ "${retl}" -ne 0 ] || [ "${retc}" -ne 0 ] ; then
        log "[info]" "k8s not found"
        return 1
    else 
        k8s_adm=$(kubeadm version -o short|grep -o '[0-9\.]*')
        k8s_let=$(kubelet --version|grep -o '[0-9\.]*')
        k8s_ctl=$(kubectl  version --short --client|grep -o '[0-9\.]*')
        if version_ge "${k8s_adm}" "${K8S_LOW}" ; then
            log "[info]" "kubeadm version ok"
        else
            log "[info]" "kubeadm version fail"
            return 1
        fi
        if version_ge "${k8s_let}" "${K8S_LOW}" ; then
            log "[info]"  "kubelet version ok"
        else
            log "[info]"  "kubelet version fail"
            return 1
        fi
        if version_ge "${k8s_ctl}" "${K8S_LOW}" ; then
            log "[info]"  "kubectl version ok"
        else
            log "[info]"  "kubectl version fail"
            return 1
        fi
        return 0
    fi
}
check_info(){
    # 检测node.db文件是否有信息
    if [ ! -s ${NODE_INFO} ]; then
        touch ${NODE_INFO}
    else
        res=$(grep -q -e '@' -e '-' ${NODE_INFO}; echo $? )
        if [ "${res}" -ne 0 ]; then
            log "[info]" "${NODE_INFO} file not found bcode or mail,need empty file "
            rm ${NODE_INFO}
            touch ${NODE_INFO}
        else
            log "[info]" "${NODE_INFO} file have bcode or mail,skip"
        fi
        
    fi
}
ins_docker(){
    # 安装docker
    check_doc
    ret=$?
    if [[ ${ret} -eq 0 || ${ret} -eq 2 ]]   ; then
        log "[info]" "docker was found! skiped"
        return 0
    fi
    env_check
    if [[ "$PG" == "apt" ]]; then
        # Install docker with APT
        # apt 安装docker
        curl -fsSL "https://download.docker.com/linux/$OS/gpg" | apt-key add -
        echo "deb https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/$OS  $OS_CODENAME stable"  >/etc/apt/sources.list.d/docker.list
        apt update
        # 遍历版本号,安装不能超过限制的版本
        for line in $(apt-cache madison docker-ce|awk '{print $3}') ; do
            if version_le "$(echo "$line" |grep -E -o '([0-9]+\.){2}[0-9]+')" "$DOC_HIG" ; then
                apt-mark unhold docker-ce
                apt install -y --allow-downgrades docker-ce="$line" 
                break
            fi
        done
        apt-mark hold docker-ce 
    elif [[ "$PG" == "yum" ]]; then
        # Install docker with yum
        # 同上
        yum install -y yum-utils
        yum-config-manager --add-repo  https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
        yum makecache
        for line in $(yum list docker-ce --showduplicates|grep 'docker-ce'|awk '{print $2}'|sort -r) ; do
            if version_le "$(echo "$line" |grep -E -o '([0-9]+\.){2}[0-9]+')" "$DOC_HIG" ; then
                yum remove  -y docer-ce docker-ce-cli
                if echo "$line"|grep -q ':' ; then
                    line=$(echo "$line"|awk -F: '{print $2}')
                fi
                yum install -y docker-ce-"$line" 
                break
            fi
        done
    else 
        log "[error]" "package manager ${PG} not support "
        return 1
    fi
    usermod -aG docker $USER
    systemctl enable docker.service
    systemctl start docker.service
    check_doc
    ret=$?
    if [[ ${ret} -eq 1 || ${ret} -eq 2 ]]  ; then
        log "[error]" "docker install fail,please check ${PG} environment"
        exit 1
    else
        log "[info]" "${PG} install -y  docker-ce-$line "
        systemctl enable docker &&systemctl start docker
    fi
}
jq_yum_ins(){
    # 安装EPEL仓库就为了装个jq,可恶
    wget -O $TMP/epel-release-latest-7.noarch.rpm http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    rpm -ivh $TMP/epel-release-latest-7.noarch.rpm
    yum install -y jq
}
ins_jq(){
    # 安装jq json文件分析工具
    if which jq>/dev/null 2>&1; then
        return
    fi
    env_check
    case $PG in
        apt     ) $PG install -y jq ;;
        yum     ) jq_yum_ins ;;
        pacman  ) $PG -S jq ;;
    esac
    if ! which jq>/dev/null 2>&1; then
        echoerr "jq install fail,please check you package sources and try \`$PG install jq -y\`\n"
    fi
}
init(){
    # 初始化目录/文件
    printf "">$LOG_FILE
    if ! systemctl enable ntp  >/dev/null 2>&1 ; then
        timedatectl set-ntp true
    else
        systemctl start ntp
    fi
    mkdir -p /etc/cni/net.d
    mkdir -p $BASE_DIR/{scripts,nodeapi,compute}
    
    env_check
    check_info
}
_k8s_ins_yum(){
    cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-$(uname -m)/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
    setenforce 0
    yum install  -y kubelet-1.12.3 kubeadm-1.12.3 kubectl-1.12.3 kubernetes-cni-0.6.0
    yum --exclude kubelet kubeadm kubectl kubernetes-cni
    systemctl enable kubelet && systemctl start kubelet
    
}
_k8s_ins_apt(){
    curl -L https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
    echo "deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main"|tee /etc/apt/sources.list.d/kubernetes.list
    log "[info]" "installing k8s"
    apt update
    apt-mark unhold kubelet kubeadm kubectl kubernetes-cni
    apt install -y --allow-downgrades kubeadm=1.12.3-00 kubectl=1.12.3-00 kubelet=1.12.3-00 kubernetes-cni=0.6.0-00 
    apt-mark hold kubelet kubeadm kubectl kubernetes-cni
}
pull_docker_image(){
    ins_docker
    docker pull registry.cn-beijing.aliyuncs.com/bxc_k8s_gcr_io/pause:3.1
    docker pull registry.cn-beijing.aliyuncs.com/bxc_k8s_gcr_io/kube-proxy:v1.12.3
    docker tag registry.cn-beijing.aliyuncs.com/bxc_k8s_gcr_io/pause:3.1 k8s.gcr.io/pause:3.1
    docker tag registry.cn-beijing.aliyuncs.com/bxc_k8s_gcr_io/kube-proxy:v1.12.3 k8s.gcr.io/kube-proxy:v1.12.3
}
ins_k8s(){
    swapoff -a
    sed -i 's/\([a-z/\\\.]\+swap\.\+\)/#\1/g' /etc/fstab
    if ! grep -q '^swapoff' /etc/rc.local  ; then
        sed -i "/exit/i\swapoff -a #bxc script" /etc/rc.local
    fi
    if ! check_k8s ; then
        init
        if [[ "$PG" == "apt" ]]; then
            _k8s_ins_apt
        elif [[ "$PG" == "yum" ]]; then
            _k8s_ins_yum
        fi
        if ! check_k8s ; then
            log "[error]" "k8s install fail!"
            exit 1
        fi
    else
        log "[info]" " k8s was found! skip"
    fi
    pull_docker_image
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
k8s_remove(){
    kubeadm reset -f
    ${PG} remove -y kubelet kubectl kubeadm --allow-change-held-packages
    rm -rf /etc/sysctl.d/k8s.conf
}
ins_conf(){
    down "x86_64/res/compute/10-mynet.conflist" "$BASE_DIR/compute/10-mynet.conflist"
    down "x86_64/res/compute/99-loopback.conf" "$BASE_DIR/compute/99-loopback.conf"
}

_set_node_systemd(){
    # 指定网卡启动node
    if [[ -z "${SET_LINK}" ]]; then
        INSERT_STR=""
    else
        INSERT_STR="--intf ${SET_LINK}"
    fi
    # 启动时不设置硬盘
    if [[ ${_DON_SET_DISK} -eq 1 ]]; then
        DON_SET_DISK="--devoff"
    fi
    cat <<EOF >/lib/systemd/system/bxc-node.service
[Unit]
Description=bxc node app
After=network.target

[Service]
ExecStart=/opt/bcloud/nodeapi/node --alsologtostderr ${DON_SET_DISK} ${INSERT_STR} 
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
}
node_ins(){
    mkdir -p $BASE_DIR/{scripts,nodeapi,compute}
    # 安装node组件
    # 区分kernel版本下载文件
    kel_v=$(uname -r|grep -E -o '([0-9]+\.){2}[0-9]')
    Rlink="img-modules"
    if  version_ge "$kel_v" "5.0.0" ; then
        Rlink="$Rlink/5.0.0-aml-N1-BonusCloud"
    fi
    # 下载文件列表
    [[ ! -f $TMP/info.txt ]]&&down "$Rlink/info.txt" "$TMP/info.txt"
    if [ ! -s "$TMP/info.txt" ]; then
        log "[error]" "wget \"$Rlink/info.txt\" -O $TMP/info.txt"
        return 1
    fi
    # 遍历文件列表下载文件
    for line in $(grep "$ARCH" $TMP/info.txt)
    do
        git_file_name=$(echo "$line" | awk -F: '{print $1}')
        git_md5_val=$(echo "$line" | awk -F: '{print $2}')
        file_path=$(echo "$line" | awk -F: '{print $3}')
        mod=$(echo "$line" | awk -F: '{print $4}')
        local_md5_val=$([ -x "$file_path" ] && md5sum "$file_path" | awk '{print $1}')
        
        if [[ "$local_md5_val"x == "$git_md5_val"x ]]; then
            log "[info]" "local file $file_path version equal git file version,skip"
            continue
        fi
        tmp_md5=$([ -f "$file_path" ] &&md5sum "$TMP/$git_file_name"| awk '{print $1}')
        if [[ ! -f $TMP/$git_file_name || "$tmp_md5" != "$git_md5_val" ]] ;then
            down "$Rlink/$git_file_name" "$TMP/$git_file_name"
        else
            log "[info]" "local file $TMP/$git_file_name md5sum equal remote md5sum "
        fi 
        download_md5=$(md5sum $TMP/"$git_file_name" | awk '{print $1}')
        if [ "$download_md5"x != "$git_md5_val"x ];then
            log "[error]" " download file $TMP/$git_file_name md5 $download_md5 different from git md5 $git_md5_val"
            continue
        fi
        log "[info]" " $TMP/$git_file_name download success."
        cp -fv $TMP/"$git_file_name" "$file_path" 2> /dev/null
        chmod "$mod" "$file_path" > /dev/null            
        if [[ -x "$file_path" ]]; then
            rm -v "$TMP/$git_file_name"
        fi
    done
    rm -v "$TMP/info.txt"
    _set_node_systemd
    systemctl daemon-reload
    systemctl enable bxc-node
    systemctl start bxc-node
    sleep 1
    #检验是否启动成功
    isactive=$(curl -fsSL http://localhost:9017/version>/dev/null; echo $?)
    if [ "${isactive}" -ne 0 ];then
        log "[error]" " node start faild, rollback and restart"
        systemctl restart bxc-node
    else
        log "[info]" " node start success."
    fi
}
node_remove(){
    # 清除上面安装的node组件
    systemctl stop bxc-node
    systemctl disable bxc-node
    rm -rf /lib/systemd/system/bxc-node.service 
}
bxc-network_ins(){
    # 安装网络插件,用与连接到bxc网络
    ret_4=$(apt list libcurl4 2>/dev/null|grep -q installed;echo $?)
    if [[ ${ret_4} -eq 0 ]]; then
        log "[info]" "Install libcurl4 library bxc-network"
        down "img-modules/bxc-network_x86_64" "${BASE_DIR}/bxc-network"
        chmod +x ${BASE_DIR}/bxc-network
    fi
    ret_3=$(apt list libcurl3 2>/dev/null|grep -q installed;echo $?)
    if [[ ${ret_3} -eq 0 ]]; then
        log "[info]" "Install libcurl3 library bxc-network"
        down "img-modules/5.0.0-aml-N1-BonusCloud/bxc-network_x86_64" "${BASE_DIR}/bxc-network"
        chmod +x ${BASE_DIR}/bxc-network
    fi
    apt install -y liblzo2-2 libjson-c3 
    ${BASE_DIR}/bxc-network |grep libraries
    cat <<EOF >/lib/systemd/system/bxc-network.service
[Unit]
Description=bxc network daemon
After=network.target

[Service]
ExecStart=/opt/bcloud/bxc-network
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    systemctl enable bxc-network&&systemctl start bxc-network
}
bxc-network_run(){
    # 检验是否运行
    [ ! -s ${SSL_KEY} ] && log "[info]" "${SSL_KEY} file not found"&&return 1

    ${BASE_DIR}/bxc-network
    sleep 3
    ret=$(ip link show tun0 >/dev/null;echo $?)
    if [[ ${ret} -ne 0 ]]; then
        log "[error]" "tun0 interface not found,try start "
        ${BASE_DIR}/bxc-network
        sleep 3 
        ret=$(ip link show tun0 >/dev/null;echo $?)
        if [[ ${ret} -ne 0 ]]; then
            log "[error]" "bxc-network start fail ,error info :$(${BASE_DIR}/bxc-network)"
        fi
    else
        log "[info]" "bxc-network start success"
    fi
}
goproxy_ins(){
    # 安装goproxy本地代理程序
    if which proxy>/dev/null 2>&1; then
        return 0
    fi
    LAST_VERSION=$(curl --silent "https://api.github.com/repos/snail007/goproxy/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')
    BASE_URl="https://github.com/snail007/goproxy/releases/download/${LAST_VERSION}"
    case $ARCH in
        x86_64 )
            [ ! -s ${TMP}/proxy-linux.tar.gz ] &&wget "${BASE_URl}/proxy-linux-amd64.tar.gz" -O ${TMP}/proxy-linux.tar.gz
            ;;
        arm64 )
            [ ! -s ${TMP}/proxy-linux.tar.gz ] &&wget "${BASE_URl}/proxy-linux-arm64-v8.tar.gz" -O ${TMP}/proxy-linux.tar.gz
            ;;
        arm  )
            [ ! -s ${TMP}/proxy-linux.tar.gz ] &&wget "${BASE_URl}/proxy-linux-arm-v7.tar.gz" -O ${TMP}/proxy-linux.tar.gz
            ;;
    esac
    [ ! -s ${TMP}/proxy-linux.tar.gz ] &&echoerr "Download proxy failed"&&return 1
    mkdir -p ${TMP}/goproxy/
    tar -xf  ${TMP}/proxy-linux.tar.gz -C ${TMP}/goproxy/
    cp -f ${TMP}/goproxy/proxy /usr/bin/
    chmod +x /usr/bin/proxy
    if [ ! -e /etc/proxy ]; then
        mkdir /etc/proxy
        cp -f ${TMP}/goproxy/blocked /etc/proxy/
        cp -f ${TMP}/goproxy/direct  /etc/proxy/
    fi
    rm -rf ${TMP}/goproxy/
    mkdir -p /var/log/goproxy
    
    cat <<EOF >/lib/systemd/system/bxc-goproxy-http.service
[Unit]
Description=bxc network proxy http
After=network.target
[Service]
ExecStart=/usr/bin/proxy http -p [::]:8901 --log /var/log/goproxy/http_proxy.log
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
EOF
    cat <<EOF >/lib/systemd/system/bxc-goproxy-socks.service
[Unit]
Description=bxc network proxy socks
After=network.target
[Service]
ExecStart=/usr/bin/proxy socks -p [::]:8902 --log /var/log/goproxy/socks_proxy.log
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
EOF
    systemctl enable bxc-goproxy-http  &&systemctl start bxc-goproxy-http
    systemctl enable bxc-goproxy-socks &&systemctl start bxc-goproxy-socks
    sleep 2
}
goproxy_remove(){
    systemctl disable bxc-goproxy-http  &&systemctl stop bxc-goproxy-http 
    systemctl disable bxc-goproxy-socks &&systemctl stop bxc-goproxy-socks
    rm -rf /lib/systemd/system/bxc-goproxy-* 2>/dev/null
    rm -rf /usr/bin/proxy /etc/goproxy /var/log/goproxy 2>/dev/null
}
goproxy_check(){
    if ! pgrep "proxy" >/dev/null ; then
        log "[error]" "goproxy not runing"
    fi
    ret_s=$(curl -x 'socks5://localhost:8902' https://www.baidu.com -o /dev/null 2>/dev/null;echo $?)
    ret_h=$(curl -x "localhost:8901" https://www.baidu.com -o /dev/null 2>/dev/null;echo $?)
    if [[ ${ret_s} -ne 0 ]]; then
         log "[error]" "goproxy socks not run!"
         return 1
    fi
    if [[ ${ret_h} -ne 0 ]]; then
        log "[error]" "goproxy http not run!"
        return 2
    fi
    return 0
}
teleport_ins(){
    echo "Would you like to install teleprot for remote debugging by developers? "
    echo "If not, the program has problems, you need to solve all the problems you encounter  "
    echo "您是否愿意安装teleport ，供开发人员远程调试."
    echo "如果否，程序出了问题，您需要自己解决所有遇到的问题，默认YES"
    read -r -p "[Default YES/N]:" choose
    case $choose in
        N|n|no|NO ) return ;;
        * ) curl -fSL https://teleport.s3.cn-north-1.jdcloud-oss.com/teleport.sh |bash  ;;
    esac
}
teleport_remove(){
    rm -f /opt/bcloud/teleport
    systemctl disable teleport
    systemctl stop teleport
    rm -f /lib/systemd/system/teleport.service
    rm -f /etc/systemd/system/teleport.service
}
iostat_ins(){
    case $PG in
        apt ) apt update&&apt install sysstat -y ;;
        yum ) yum install sysstat -y ;;
    esac
}
read_bcode_input(){
    # 交互输入bcode
    echoinfo "Input bcode:";read -r  bcode
    echoinfo "Input email:";read -r  email
    if [[ -z "${bcode}" ]] || [[ -z "${email}" ]]; then
        echowarn "Please Input bcode and email. You can try \"bash $0 -b\" to bound\n"
        return 1
    fi
    read_bcode=$(echo "${bcode}"|grep -E -o "[0-9a-f]{4}-[0-9a-f]{8}-([0-9a-f]{4}-){2}[0-9a-f]{4}-[0-9a-f]{12}")
    if [[ -z "${read_bcode}" ]]; then
        echoerr "bcode input error\n"
        return 2
    fi
    return 0
}
bound(){
    # 命令行绑定
    local bcode=""
    local email=""
    [ -s /opt/bcloud/node.db ]&&log "[info]" "${NODE_INFO} exits ,skip" && return 0
    if ! read_bcode_input ; then 
        return 1
    fi
    echoinfo "bcode:${bcode}  email:${email}\n"
    curl -H "Content-Type: application/json" -d "{\"bcode\":\"${bcode}\",\"email\":\"${email}\"}" http://localhost:9017/bound
    if [[ $? -ne 0 ]]; then
        log "[error]" "bound failed"
        return 1
    fi
    # printf "\ncurl -H \"Content-Type: application/json\" -d \"{\"bcode\":\"${bcode}\",\"email\":\"${email}\"}\" http://localhost:9017/bound\n"
    return 0
}
only_ins_network_base(){
    init 
    [ ! -s ${BASE_DIR}/bxc-network ]&&bxc-network_ins
    [ ! -s ${BASE_DIR}/nodeapi/node ]&&node_ins
    goproxy_ins
    goproxy_check
    echoinfo "bound now?(现在绑定?)[Y/N]:";read -r choose
    case ${choose} in
        n|N ) return ;;
        y|Y ) bound&&systemctl stop bxc-node ;;
        * ) bound&&systemctl stop bxc-node ;;
    esac
}
only_net_check_network(){
    echoinfo "Testing network... \n"
    network_result=$(docker run --rm -it --net=bxc1 "qinghon/bxc-net:$VDIS" \
    /bin/sh -c "curl -m 3 -fs baidu.com -o /dev/null >/dev/null 2>&1";echo $?)
    if [[ $network_result -ne 0 ]]; then
        echoerr "This bridge network can not connect network,curl return $network_result\n"
        read -r -e -p "Delete this network?:" -i "Y" -t 5 choose
        choose=${choose:-"Y"}
        case $choose in
            Y|y ) docker network rm bxc1 &&echoerr "\nDelete success\n";;
            *   ) echoerr "\nCancel!\n";;
        esac
        return 1
    else
        echoinfo "network seting success!\n"
        return 0
    fi
}
only_net_set_promisc(){
    # 开启网卡混杂模式,还需外部配合
    local LINK="$1"
    if [[ -z "$LINK" ]]; then
        return 1
    fi
    ip link set "${LINK}" promisc on
    # 持久化
    if [[ ! -s /etc/rc.local ]] ;then
        echo -e '#!/bin/bash\nexit 0'>/etc/rc.local
        chmod 755 /etc/rc.local
        systemctl enable rc-local.service
        systemctl enable rc.local.service
    fi
    if ! grep -q "${LINK} promisc" /etc/rc.local ; then
        sed -i "/exit/i\ip link set ${LINK} promisc on" /etc/rc.local
    fi
}
only_net_set_bridge(){
    # 设置macvlan桥接网络
    bxc_network_bridge_id=$(docker network ls -f name=bxc --format "{{.ID}}:{{.Name}}"|grep -E 'bxc-macvlan|bxc1'|awk -F: '{print $1}')
    if [[ -n "${bxc_network_bridge_id}" ]]; then
        return 0
    fi
    LINK=$DEFAULT_LINK
    if [[ -n "${SET_LINK}" ]]; then
        LINK=${SET_LINK}
    fi
    if echo "$LINK"|grep -q "wlan"; then
        echoerr "THE Wireless Interface $LINK can not use macvlan;exit\n"
        return 1
    fi
    if [[ -z "${LINK}" ]]; then
        echoerr "NET Interface not found"
        return 2
    fi
    LINK_GW=$(ip route list|grep 'default'|grep "$LINK"|awk '{print $3}')
    LINK_SUBNET=$(ip addr show "${LINK}"|grep 'inet '|awk '{print $2}')
    LINK_HOSTIP=$(echo "${LINK_SUBNET}"|awk -F/ '{print $1}')
    only_net_set_promisc "$LINK"
    echoinfo "Set ip range(设置IP范围):\n";read -r -e -i "${LINK_SUBNET}" SET_RANGE
    echo "docker network create -d macvlan --subnet=\"${LINK_SUBNET}\" \
    --gateway=\"${LINK_GW}\" --aux-address=\"exclude_host=${LINK_HOSTIP}\" \
    --ip-range=\"${SET_RANGE}\" \
    -o parent=\"${LINK}\" -o macvlan_mode=\"bridge\" bxc1"
    docker network create -d macvlan --subnet="${LINK_SUBNET}" \
    --gateway="${LINK_GW}" --aux-address="exclude_host=${LINK_HOSTIP}" \
    --ip-range="${SET_RANGE}" \
    -o parent="${LINK}" -o macvlan_mode="bridge" bxc1
    # 检验网卡通不通
    if ! only_net_check_network ; then
        return 3
    fi
}
generate_mac_addr(){
    # 随机生成mac
    random_mac_addr=$(od /dev/urandom -w4 -tx1 -An|sed -e 's/ //' -e 's/ /:/g'|head -n 1)
    if [[ -z $mac_head ]]; then
        local mac_head_tmp
        mac_head_tmp=$(od /dev/urandom -w2 -tx1 -An|sed -e 's/ //' -e 's/ /:/g'|head -n 1)
        echoinfo "Set mac address:\n";read -r -e -i "${mac_head_tmp}:${random_mac_addr}" mac_addr
    else
        echoinfo "Set mac address:\n";read -r -e -i "${mac_head}:${random_mac_addr}" mac_addr
    fi
    check_mac_addr=$(echo "${mac_addr}"|grep -E -o '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}')
    if [[ -z "${check_mac_addr}" ]]; then
        echowarn "Input mac address type fail, "
        mac_addr=$(od /dev/urandom -w6 -tx1 -An|sed -e 's/ //' -e 's/ /:/g'|head -n 1)
        echoinfo "Generate a mac address: $mac_addr\n"
    fi
}
run_command(){
    #log '[info]' "$1"
    $1
    return $?
}

only_ins_network_docker_run(){
    bcode="$1"
    email="$2"
    mac_import="$3"
    local mac_addr
    #local mac_head="$mac_head"
    # 获取或生成mac
    if [[ -n $mac_import ]] ;then 
        mac_addr="$mac_import"
    else
        generate_mac_addr
    fi
    mac_head_tmp=$(echo "$mac_addr"|awk -F: '{print $1,$2}'|sed 's/ /:/g')
    # -H 选项 设置静态IP
    if [[ $_SET_IP_ADDRESS -eq 1 ]]; then
        local set_ipaddress
        local ipaddress
        echoinfo "Set ip address:\n" ;read -r ipaddress
        set_ipaddress="--ip=\"${ipaddress}\""
    else
        set_ipaddress=''
    fi
    # 选择新旧网卡名
    local network_name
    if docker network ls -f name=bxc --format "{{.Name}}"|grep -q 'bxc1'; then
        network_name="--net=bxc1"
    else
        network_name="--net=bxc-macvlan"
    fi
    command="docker run -d --cap-add=NET_ADMIN $network_name $set_ipaddress --mac-address=$mac_addr \
        --sysctl net.ipv6.conf.all.disable_ipv6=0 --device /dev/net/tun --restart=always  \
        -e bcode=${bcode} -e email=${email} --name=bxc-${bcode} \
        -v bxc_data_${bcode}:/opt/bcloud \
        ${image_name}"
    # 运行命令
    con_id=$(run_command "$command")
    if [[ -z $con_id ]]; then
        return 2
    fi
    echo "${con_id}"
    sleep 3
    # 检测绑定成功与否
    fail_log=$(docker logs "${con_id}" 2>&1 |grep 'bonud fail'|head -n 1)
    if [[ -n "${fail_log}" ]]; then
        echoerr "bound fail\n${fail_log}\n"
        docker stop "${con_id}"
        docker rm "${con_id}"
        return 3
    fi
    # 检测是否为mac问题导致不能running,并清除
    create_status=$(docker container inspect "${con_id}" --format "{{.State.Status}}")
    if [[ "$create_status" == "created" ]]; then
        echowarn "Delete can not run container\n"
        docker container rm "${con_id}"
        return 4
    else
        # 运行成功时,修改自身脚本定义的mac头为可用头
        if [[ -z $mac_head ]]; then
            mac_head="$mac_head_tmp"
            sed -i "s/local mac_head=\"\"/local mac_head=\"${mac_head_tmp}\"/g" "$0"
        fi
    fi
    echo-
}
_get_ip_mainland(){
    geoip=$(curl -4 -fsSL "https://api.ip.sb/geoip")
    country=$(echo "$geoip"|jq '.country')
    if [[ "${country}" == "China" ]]; then
        return 0
    else
        return 1
    fi
}
_only_net_get_image(){
    # 保证为最新镜像
    case $VDIS in
        amd64  ) image_name="qinghon/bxc-net:amd64" ;;
        arm64  ) image_name="qinghon/bxc-net:arm64" ;;
        *      ) echoerr "No support $VDIS\n";return 4  ;;
    esac
    if [[ $_DON_DOWN_IMAGE -eq 0 ]]; then
        echoinfo "Downloading $image_name ...\n"
        docker pull "${image_name}"
    else
        echowarn "Skip $image_name download\n"
    fi
    if ! docker images --format "{{.Repository}}"|grep -q 'qinghon/bxc-net' ; then
        echoerr "pull failed,exit!,you can try: docker pull ${image_name}\n"
        return 1
    fi
}
only_ins_network_docker_openwrt(){
    ins_docker
    ins_jq
    local image_name=""
    local mac_head=""
    if ! _only_net_get_image ; then
        return 1
    fi
    if ! only_net_set_bridge ; then
        return 4
    fi
    echoinfo "Input bcode:";read -r  bcode
    echoinfo "Input email:";read -r  email
    if [[ -z "${bcode}" ]] || [[ -z "${email}" ]]; then
        echowarn "Please Input bcode and email. You can try \"bash $0 -b\" to bound\n"
        return 2
    fi
    if [[ ${#bcode} -le 3 && ${bcode} -le 100 ]]; then
        json=$(curl -fsSL "https://console.bonuscloud.io/api/bcode/getBcodeForOther/?email=${email}")
        # 输入为数字时,获取用户账户里的bcode,区分海内外
        if ! _get_ip_mainland ; then
            all_bcode_length=$(echo "${json}"|jq '.ret.mainland|length')
            bcode_list=$(echo "${json}"|jq '.ret.mainland')
        else
            all_bcode_length=$(echo "${json}"|jq '.ret.non_mainland|length')
            bcode_list=$(echo "${json}"|jq '.ret.non_mainland')
        fi
        
        read_all_bcode=$(echo "${bcode_list}"|jq -r '.[]|.bcode')
        if [[ $bcode -ge $all_bcode_length ]]; then
            len=$all_bcode_length
        else
            len=$bcode
        fi
        if [[ -z ${read_all_bcode} ]]; then
            echoerr "not found bcode in ${email}\n"
        fi
    else
        # 直接输入bcode时
        read_bcode=$(echo "${bcode}"|grep -E -o "[0-9a-f]{4}-[0-9a-f]{8}-([0-9a-f]{4}-){2}[0-9a-f]{4}-[0-9a-f]{12}")
        if [[ -z "${read_bcode}" ]]; then
            echowarn "bcode input error\n"
            return 3
        else
            read_all_bcode="${read_bcode}"
            len=1
        fi
    fi
    # 遍历bcode,启动容器
    for i in $(echo "${read_all_bcode}"|head -n "$len") ; do
        echoinfo "bcode: $i\n"
        only_ins_network_docker_run "${i}" "${email}"
    done
}
only_ins_network_choose_plan(){
    echoinfo "choose plan:\n"
    echoinfo "\t1) run as base progress,only one(只运行基础进程,兼容性差,内存低,单开)\n"
    echoinfo "\t2) run openwrt as docker,more(运行在docker里,兼容性好,内存占用高,可多开)\n"
    echoinfo "CHOOSE [1|2]:"
    read -r  CHOOSE
    case $CHOOSE in
        1 ) only_ins_network_base;;
        2 ) only_ins_network_docker_openwrt ;;
        * ) echowarn "\nno choose(未选择)\n";;
    esac
}
only_net_cert_export(){
    Datas=$(docker volume ls --format "{{.Name}}"|grep 'bxc_data_')
    [[ -z "$Datas" ]]&&echoerr "not found volumes,exit\n"&&return 1
    echoinfo "Find $(echo "${Datas}"|grep -c '') volume \n"
    ABSOLUTE_PATH=$(pwd)
    for data in $Datas ; do
        echoinfo "backuping \t$data\n"
        docker run --rm -it -v "$data:/opt/bcloud" -v "$ABSOLUTE_PATH/$TMP":/backup qinghon/bxc-net:$VDIS \
        /bin/sh -c "[ -s /opt/bcloud/ca.crt ] &&tar -cpf \"/backup/$data.tar\" $NODE_INFO $SSL_CA $SSL_CRT $SSL_KEY 2>/dev/null"
        [[ ! -s  "$ABSOLUTE_PATH/$TMP/$data.tar" ]]&&echoerr "not file in\t$data\n"&&docker volume rm "$data"
    done
    echoinfo "backup all over!files in $ABSOLUTE_PATH/$TMP\n"
}
only_net_cert_import_run(){
    # 根据导入的证书启动容器
    local FILEs bcode_ email_ mac_addr_ image_name
    FILEs=$(find . -name 'bxc_data_*.tar')
    [[ -z "$FILEs" ]]&&echoerr "not found certificate file,exit"&&return 1
    if ! _only_net_get_image ; then
        return 1
    fi
    echoinfo "Find $(echo "${FILEs}"|grep -c '') file\n"
    for i in $FILEs ;do
        info=$(tar -xf "$i" opt/bcloud/node.db -O 2>/dev/null)
        if [[ -z $info ]]; then
            echoerr "not found bcode from $i\n"
            continue
        fi
        bcode_=$(echo "$info"|jq -r '.bcode')
        email_=$(echo "$info"|jq -r '.email')
        mac_addr_=$(echo "$info"|jq -r '.mac_address')
        only_ins_network_docker_run "$bcode_" "$email_" "$mac_addr_"
    done
}
only_net_cert_import(){
    # 从tar文件导入证书
    local FILEs
    FILEs=$(find . -name 'bxc_data_*.tar')
    [[ -z "$FILEs" ]]&&echoerr "not found certificate file,exit"&&return 1
    echoinfo "Find $(echo "${FILEs}"|grep -c '') file\n"
    ABSOLUTE_PATH=$(pwd)
    for i in $FILEs; do
        DIR=$(dirname "$i")
        DIR="${ABSOLUTE_PATH}${DIR:1}"

        filename=$(basename "$i")
        bcode=$(echo "$i"|grep -E -o "[0-9a-f]{4}-[0-9a-f]{8}-([0-9a-f]{4}-){2}[0-9a-f]{4}-[0-9a-f]{12}")
        [[ -z $bcode ]]&& echoerr "can not get bcode for $i" && continue
        echoinfo "importing\t$bcode ...\n"
        docker create -v "bxc_data_$bcode":/opt/bcloud --name "bxc_date_tmp_$bcode" qinghon/bxc-net:$VDIS true 1>/dev/null 
        docker run --rm --volumes-from="bxc_date_tmp_$bcode" \
        -v "$DIR":/backup qinghon/bxc-net:$VDIS tar xf "/backup/$filename" -C /
        docker rm "bxc_date_tmp_$bcode" 1>/dev/null
        set +x
    done
    # 手动选择是否现在启动
    read -r -e -p "Run it now?:" -i "Y"  choose
    case $choose in
        Y|y ) only_net_cert_import_run ;;
    esac
}
only_net_remove(){
    IDs=$(docker ps -a --filter="ancestor=qinghon/bxc-net:$VDIS" --format "{{.ID}}")
    docker container stop "$IDs"
    docker container rm "$IDs"
    docker network rm bxc-macvlan
    echowarn "清除证书?[Y/N]";read -e -r -i "N" choose
    case  $choose in
        Y|y ) docker volume rm "$(docker volume ls --format="{{.Name}}"|grep bxc_data)" ;;
    esac
    goproxy_remove
}
ins_kernel(){
    if [[ "${DEVMODEL}" != "Phicomm N1" ]]; then
        echo "this device not Phicomm N1 exit"
        return 1
    fi
    down "/aarch64/res/N1_kernel/md5sum" "$TMP/md5sum"
    down "/aarch64/res/N1_kernel/System.map-5.0.0-aml-N1-BonusCloud-1-1.xz" "$TMP/System.map-5.0.0-aml-N1-BonusCloud-1-1.xz"
    down "/aarch64/res/N1_kernel/vmlinuz-5.0.0-aml-N1-BonusCloud-1-1.xz" "$TMP/vmlinuz-5.0.0-aml-N1-BonusCloud-1-1.xz"
    down "/aarch64/res/N1_kernel/modules.tar.xz" "$TMP/modules.tar.xz"
    down "/aarch64/res/N1_kernel/N1.dtb" "$TMP/N1.dtb"
    echo "verifty file md5..."
    while read line; do
        file_name=$(echo "${line}" |awk '{print $2}')
        git_md5=$(echo "${line}" |awk '{print $1}')
        local_md5=$(md5sum "$TMP/$file_name"|awk '{print $1}')
        if [[ "$git_md5" != "$local_md5" ]]; then
            down "/aarch64/res/N1_kernel/$file_name" "$TMP/$file_name"
            local_md5=$(md5sum "$TMP/$file_name"|awk '{print $1}')
            if [[ "$git_md5" != "$local_md5" ]]; then
                echo "download $TMP/$file_name failed,md5 check fail"
            fi
        fi
    done <$TMP/md5sum
    xz -d -c $TMP/System.map-5.0.0-aml-N1-BonusCloud-1-1.xz > $TMP/System.map-5.0.0-aml-N1-BonusCloud-1-1
    xz -d -c $TMP/vmlinuz-5.0.0-aml-N1-BonusCloud-1-1.xz > $TMP/zImage
    echo "backup old kernel to $TMP/kernel_bak/"
    mkdir -p $TMP/kernel_bak
    cp /boot/zImage $TMP/kernel_bak/
    cp /boot/vmlinuz* $TMP/kernel_bak/
    cp /boot/System.map-* $TMP/kernel_bak/
    echo "installing new kernel"
    cp $TMP/zImage /boot/zImage
    cp /boot/zImage /boot/vmlinuz-5.0.0-aml-N1-BonusCloud-1-1
    cp $TMP/System.map-5.0.0-aml-N1-BonusCloud-1-1 /boot/System.map-5.0.0-aml-N1-BonusCloud-1-1
    tar -Jxf $TMP/modules.tar.xz -C /lib/modules/
    res=$(grep -q 'N1.dtb' /boot/uEnv.ini;echo $?)
    if [[ ${res} -ne 0 ]]; then
        cp $TMP/N1.dtb /boot/N1.dtb
        sed -i -e 's/dtb_name/#dtb_name/g' -e '/N1.dtb$/'d /boot/uEnv.ini
        sed -i '1i\dtb_name=\/N1.dtb' /boot/uEnv.ini
    fi
    echo "接下来会重启,准备好了吗?给你10秒,CTRL-C 停止"
    sync
    sleep 10
    reboot
}
_select_interface(){
    if [[  -n $0 ]]; then
        SET_LINK=$1
    fi
    MACADDR=$(ip link show "${SET_LINK}"|grep 'ether'|awk '{print $2}')
    if [[ -z "${MACADDR}" ]]; then
        log "[error]" "Get interface ${SET_LINK} mac address get error"
        SET_LINK=""
    fi
}
set_interfaces_name(){
    echo -e "手动修改网卡名称为ethx方法 https://jianpengzhang.github.io/2017/04/18/2017041801/"

    read -r -p "是否自动修改网卡名称为ethx,可能会失联,默认否 yes/n:" CHOSE
    case ${CHOSE} in
        yes )
            sed -i 's/^GRUB_CMDLINE_LINUX=/#GRUB_CMDLINE_LINUX=/' /etc/default/grub
            sed -i '/^GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0" #script/d' /etc/default/grub
            sed -i '/GRUB_CMDLINE_LINUX=""/a\GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0" #script' /etc/default/grub
            update-grub2
            echo -e '# The primary network interface\nallow-hotplug eth0\niface eth0 inet dhcp' >/etc/network/interfaces
            echo "接下来会重启,准备好了吗?给你10秒,CTRL-C 停止"
            sync
            sleep 10
            reboot
            ;;
        * ) return  ;;
    esac
    
}
_show_info(){
    Status="$1"
    num=$2
    con_ID="$3"
    have_tun0=$4
    ip_addr="$5"
    mac_addr="$6"
    if [[ "$Status" != "running" || $have_tun0 -ne 0 ]]; then
        echoerr "${num}  ${Status}\ttun0 not create\t$con_ID\t\t${mac_addr}\t\n"
    else
        echoinfo "${num}  ${Status}\t\ttun0 run\t${ip_addr}\t${mac_addr}\n"
    fi
}
only_net_show(){
    # 显示单网络任务的所有容器
    ins_jq
    IDs=$(docker ps -a --filter="ancestor=qinghon/bxc-net:$VDIS" --format "{{.ID}}")
    echoerr  "num Status\ttun0 Status\tcontainer ID\t\tMAC\n"
    echoinfo "num Status\t\ttun0 Status\tIP\t\tMAC address\n"
    echo-
    local LFS_tmp=$LFS
    LFS=\n
    IDs_arr=($IDs)
    LFS=$LFS_tmp
    run_num=0
    fail_num=0
    for i in $IDs; do
        con_info=$(docker container inspect "$i")
        Status=$(echo "$con_info"|jq -r '.[]|.State.Status')
        if [[ "$Status" != "running" ]]; then
            fail_num=$(($fail_num+1))
            _show_info "$Status" "$fail_num" "$i" "1" "" ""
            continue
        fi
        have_tun0=$(docker exec -it "$i" /bin/sh -c 'ip addr show dev tun0 >/dev/null 2>&1' 2>/dev/null;echo $?)
        network_name=$(echo "$con_info"|jq -r '.[]|.NetworkSettings.Networks|to_entries|.[]|.key')
        if [[ "$network_name" == "bxc1" ]]; then
            ip_addr=$(echo "$con_info"|jq -r '.[]|.NetworkSettings.Networks.bxc1.IPAddress')
            mac_addr=$(echo "$con_info"|jq -r '.[]|.NetworkSettings.Networks.bxc1.MacAddress')
        else
            ip_addr=$(echo "$con_info"|jq -r '.[]|.NetworkSettings.Networks."bxc-macvlan".IPAddress')
            mac_addr=$(echo "$con_info"|jq -r '.[]|.NetworkSettings.Networks."bxc-macvlan".MacAddress')
        fi 

        if [[ $have_tun0 -ne 0 ]] ; then
            fail_num=$(($fail_num+1))
            _show_info "$Status" "$fail_num" "$i" "$have_tun0" "$ip_addr" "$mac_addr"
            continue
        fi
        run_num=$(($run_num+1))
        _show_info "$Status" "$run_num" "$i" "$have_tun0" "$ip_addr" "$mac_addr"
    done
    echo-
    echoinfo "${run_num} running\t\t"
    echoerr "${fail_num} not running\t\t"
    echoinfo "${#IDs_arr[@]} Total\n"
}
mg(){
    echoins(){
        case $1 in
            "1" ) echoerr "not install\t" ;;
            "0" ) echoinfo "installed\t";;
        esac
    }
    echorun(){
        case $1 in
            "1" ) echoerr "not running\t" ;;
            "0" ) echoinfo "running\t\t";;
        esac
    }
    # network check
    network_docker=$(docker images --format "{{.Repository}}"|grep -q bxc-net;echo $?)
    network_file_have=$([[ -s ${BASE_DIR}/bxc-network || "${network_docker}" -eq 0 ]];echo $?)   
    
    network_progress=$(pgrep bxc-network>/dev/null;echo $?)
    [[ ${network_progress} -eq 0 ]] &&network_con_id=$(docker ps --filter="ancestor=qinghon/bxc-net:$VDIS" --format "{{.ID}}"|head -n 1)
    
    tun0exits=$(ip link show tun0 >/dev/null 2>&1 ;echo $?)
    [[ ${network_file_have} -eq 0 ]] &&tun0exits=$(ip link show tun0 >/dev/null 2>&1 ;echo $?)
    [[ ${network_docker} -eq 0  && -n "${network_con_id}" ]] &&tun0exits=$(docker exec -i "${network_con_id}" /bin/sh -c "ip link show dev tun0>/dev/null 2>&1;echo $?")
    [[ $network_file_have -ne 0 && -z "${network_con_id}" ]] &&tun0exits=1

    goproxy_progress=$(goproxy_check >/dev/null 2>&1 ;echo $?)
    [[ -n "${network_con_id}" ]] &&goproxy_progress=$(docker exec -i "${network_con_id}" /bin/sh -c "pgrep bxc-worker>/dev/null;echo $?")
    # node check
    node_progress=$(pgrep  node>/dev/null;echo $?)
    node_file=$([ -s ${BASE_DIR}/nodeapi/node ];echo $?)
    [ "${node_progress}" -eq 0 ]&&node_version=$(curl -fsS localhost:9017/version|grep -E -o 'v[0-9]\.[0-9]\.[0-9]')
    # k8s check
    k8s_file=$(check_k8s >/dev/null;echo $?)
    k8s_progress=$(pgrep kubelet>/dev/null;echo $?)
    [[ $k8s_file -eq 0 ]] &&k8s_version=$(kubelet --version|awk '{print $2}')

    #docker check
    doc_che_ret=$(check_doc2 >/dev/null 2>&1 ;echo $?)
    [[ ${doc_che_ret} -ne 1 ]]&& doc_v=$(docker version --format "{{.Server.Version}}")
    #output
    echowarn "\nbxc-network:\n"
    echo -e -n "|install?\t|running?\t|connect?\t|proxy aleady?\n"
    [ "${network_file_have}" -ne 0 ]&&{ echoins "1";}||echoins "0"
    [ "${network_progress}" -ne 0 ]&&{ echorun "1";}||echorun "0"
    [ "${tun0exits}" -ne 0 ] && { echoerr "tun0 not create\t";}  || echoinfo "tun0 run!\t"
    [ "${goproxy_progress}" -ne 0 ]&&{ echorun "1";}||echorun "0"
    echowarn "\nbxc-node:\n"
    echo -e -n "|install?\t|running?\t|version\n"
    [ "${node_file}" -ne 0 ]&&{ echoins "1";}||echoins "0"
    [ "${node_progress}" -ne 0 ]&&{ echorun "1";}||echorun "0"
    [ "${node_progress}" -eq 0 ]&&echoinfo "${node_version}"
    echowarn "\nk8s:\n"
    [ "${k8s_file}" -ne 0 ]&&{ echoins "1";}||echoins "0"
    [ "${k8s_progress}" -ne 0 ]&&{ echorun "1";}||echorun "0"
    [[ -n $k8s_version ]] &&echoinfo "${k8s_version}\t"
    echowarn "\ndocker:\n"
    [[ ${doc_che_ret} -eq 1  ]] && { echoins "1";}||echoins "0"
    [[ -n ${doc_v} ]] &&echoinfo "$doc_v\t"
    echoinfo "\n"
}
verifty(){
    [ ! -s $BASE_DIR/nodeapi/node ] && return 2
    [ ! -s $BASE_DIR/compute/10-mynet.conflist ] && return 3
    [ ! -s $BASE_DIR/compute/99-loopback.conf ] && return 4
    log "[info]" "verifty file over"
    return 0 
}
remove(){
    echowarn "Are you sure all remove BonusCloud plugin? yes/n:" ;read -r CHOSE
    case $CHOSE in
        yes )
            node_remove
            rm -rf /opt/bcloud  $TMP
            echoinfo "BonusCloud plugin removed\n"
            k8s_remove
            echoinfo "k8s removed\n"
            teleport_remove
            echoinfo "teleport removed\n"
            echoinfo "see you again!\n"
            ;;
        * ) return ;;
    esac

}

en_us_help=(
    "bash $0 [option]    "
    "    -h             Print this and exit"
    "     └── -L        Specify help language,like \"-h -L zh_cn\""
    "    -b             bound for command"
    "    -d             Only install docker"
    "    -c             change kernel to compiled dedicated kernels,only \"Phicomm N1\"" 
    "                   and is danger!"
    "    -i             Installation environment check and initialization"
    "    -k             Install the k8s environment and the k8s components that" 
    "                   BonusCloud depends on"
    "    -n             Only install node management components "
    "    -r             Fully remove bonuscloud plug-ins and components"
    "    -s             Install teleport for remote debugging by developers"
    "    -t             Show all plugin running status"
    "    -e             Set interfaces name to ethx,only x86_64 and using grub"
    "    -g             Install network job only"
    "     └── -H        Set ip for container"
    "     └── -M        skip bxc-net docker image download"
    "     └── -e        export only network job certificate"
    "     └── -i        import only network job certificate"
    "    -A             Install all task component"
    "    -D             Don't set disk for node program"
    "    -I Interface   set interface name to you want"
    "    -S             show Info level output"
    " "
    "When no parameters are added, the calculation task component is installed "
    "by default. If the parameter \"only install\" is added, the corresponding "
    "component will be installed.")
zh_cn_help=(
    "bash $0 [选项]    "
    "    -h             打印此帮助并退出"
    "     └── -L        指定帮助语言,如\"-h -L zh_cn\" "
    "    -b             命令行绑定"
    "    -d             仅安装Docker程序"
    "    -c             安装定制内核,仅支持\"Phicomm N1\""
    "    -i             仅初始化"
    "    -k             仅安装k8s组件"
    "    -n             安装node组件"
    "    -r             清除所有安装的相关程序"
    "    -s             仅安装teleport远程调试程序,默认安装"
    "    -t             显示各组件运行状态"
    "    -e             设置网卡名称为ethx格式,仅支持使用grub的x86设备"
    "    -g             仅安装网络任务"
    "     └── -H        网络容器指定IP"
    "     └── -M        跳过bxc-net镜像下载"
    "     └── -e        导出单网络任务证书"
    "     └── -i        导入单网络任务证书"
    "    -A             安装所有计算任务组件"
    "    -D             不初始化外挂硬盘"
    "    -I Interface   指定安装时使用的网卡"
    "    -S             显示Info等级日志"
    " "
    "不加参数时,默认安装计算任务组件,如加了\"仅安装..\"等参数时将安装对应组件")

displayhelp(){
    echo -e "\033[2J"
    case $_LANG in
        zh_CN.UTF-8|zh_cn )
            for i in "${!zh_cn_help[@]}"; do
                help_arr[$i]="${zh_cn_help[$i]}"
            done 
            ;;
        *           )
            for i in "${!en_us_help[@]}"; do
                help_arr[$i]="${en_us_help[$i]}"
            done
            ;;
    esac
    for i in "${!help_arr[@]}"; do
        printf "${help_arr[$i]}\n"
    done
    exit 0
}
install_all(){
    _INIT=1
    _DOCKER_INS=1
    _NODE_INS=1
    _TELEPORT=1
    _K8S_INS=1
    _NET_CONF=1
    _SYSSTAT=1
}

DISPLAYINFO="0"
_LANG="${LANG}"
_SYSARCH=1
_INIT=0
_NET_CONF=0
_DOCKER_INS=0
_NODE_INS=0
_REMOVE=0
_TELEPORT=0
_SYSSTAT=0
_CHANGE_KN=0
_ONLY_NET=0
_K8S_INS=0
_BOUND=0
_SHOW_STATUS=0
_SET_ETHX=0
_DON_SET_DISK=0
_SET_IP_ADDRESS=0
_SHOW_HELP=0
_DON_DOWN_IMAGE=0
#_TEST=0

if [[ $# == 0 ]]; then
    install_all
fi

while  getopts "bdiknrstceghAI:DSHL:M" opt ; do
    case $opt in
        i ) _INIT=1         ;;
        b ) _BOUND=1        ;;
        c ) _CHANGE_KN=1    ;;
        d ) _DOCKER_INS=1   ;;
        k ) _K8S_INS=1      ;;
        n ) _NODE_INS=1     ;;
        r ) _REMOVE=1       ;;
        s ) _TELEPORT=1     ;;
        e ) _SET_ETHX=1     ;;
        t ) _SHOW_STATUS=1  ;;
        g ) _ONLY_NET=1     ;;
        h ) _SHOW_HELP=1    ;;
        A ) install_all     ;;
        D ) _DON_SET_DISK=1 ;;
        I ) _select_interface "${OPTARG}" ;;
        M ) _DON_DOWN_IMAGE=1 ;;
        S ) DISPLAYINFO="1" ;;
        H ) _SET_IP_ADDRESS=1   ;;
        L ) _LANG="${OPTARG}"   ;;
        ? ) echoerr "Unknow arg. exiting" ;displayhelp; exit 1 ;;
    esac
done
[[ $_SHOW_HELP -eq 1 ]]     &&displayhelp
[[ $_SYSARCH -eq 1 ]]       &&sysArch   &&sys_codename  &&run_as_root "$*"
[[ $_SHOW_STATUS -eq 1 && $_ONLY_NET -eq 1 ]] &&_ONLY_NET=0&& _SHOW_STATUS=0&&only_net_show
[[ $_ONLY_NET -eq 1 && $_SET_ETHX -eq 1 ]]  &&_ONLY_NET=0 && _SET_ETHX=0&&only_net_cert_export
[[ $_ONLY_NET -eq 1 && $_INIT -eq 1 ]]      &&_ONLY_NET=0 && _INIT=0 &&only_net_cert_import
[[ $_INIT -eq 1 ]]          &&init
[[ $_DOCKER_INS -eq 1 ]]    &&ins_docker
[[ $_NODE_INS -eq 1 ]]      &&node_ins
[[ $_TELEPORT -eq 1 ]]      &&teleport_ins
[[ $_SYSSTAT -eq 1 ]]       &&iostat_ins
[[ $_CHANGE_KN -eq 1 ]]     &&ins_kernel
[[ $_ONLY_NET -eq 1 ]]      &&only_ins_network_choose_plan
[[ $_K8S_INS -eq 1 ]]       &&ins_k8s
[[ $_NET_CONF -eq 1 ]]      &&ins_conf
[[ $_BOUND -eq 1 ]]         &&bound
[[ $_SET_ETHX -eq 1 ]]      &&set_interfaces_name
[[ $_SHOW_STATUS -eq 1 ]]   &&mg
[[ $_REMOVE -eq 1 ]]        &&remove

sync
