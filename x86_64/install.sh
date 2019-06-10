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
DEVMODEL=$(cat /proc/device-tree/model 2>/dev/null |tr -d '\0')
DEFAULT_LINK=$(ip route list|grep 'default'|head -n 1|awk '{print $5}')
DEFAULT_MACADDR=$(ip link show "${DEFAULT_LINK}"|grep 'ether'|awk '{print $2}')
SET_LINK=""
MACADDR=""

TMP="tmp"
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
    "https://raw.githubusercontent.com/qinghon/BonusCloud-Node/master"
)
mkdir -p $TMP
DISPLAYINFO="1"

echoerr(){
    printf "\033[1;31m$1\033[0m"
}
echoinfo(){
    printf "\033[1;32m$1\033[0m"
}
echowarn(){
    printf "\033[1;33m$1\033[0m"
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
            [[ "${DISPLAYINFO}" == "1"x ]]&&echoinfo "${timeOut} $1 $2\n"
            ;;
        "[warn]" )
            echo "${timeOut} $1 $2" >>$LOG_FILE
            echowarn "${timeOut} $1 $2\n"
            ;;
    esac
}
env_check(){
    # Check if the system is x86_64
    if ! uname -m |grep -qE 'x86_64'; then
        log "[error]" "this is 64 system install script for x86_64 ,if you's not ,please install correspond system"
        exit 1
    fi
    # Detection package manager
    ret_a=$(which apt >/dev/null;echo $?)
    ret_y=$(which yum >/dev/null;echo $?)
    if which apt >/dev/null ; then
        echoinfo "Find apt\n"
        PG="apt"
    elif which yum >/dev/null ; then
        echoinfo "Find yum\n"
        PG="yum"
    else
        log "[error]" "\"apt\" or \"yum\" ,not found ,exit "
        exit 1
    fi
    ret_c=$(which curl >/dev/null;echo $?)
    ret_w=$(which wget >/dev/null;echo $?)
    case ${PG} in
        apt )
            $PG install -y curl wget apt-transport-https
            ;;
        yum )
            $PG install -y curl wget
    esac
    # Check if the system supports
    [ ! -s $TMP/screenfetch ]&&wget  -nv -O $TMP/screenfetch "https://raw.githubusercontent.com/KittyKatt/screenFetch/master/screenfetch-dev" 
    chmod +x $TMP/screenfetch
    OS=$($TMP/screenfetch -n |grep 'OS:'|awk '{print $3}'|tr '[:upper:]' '[:lower:]')
    if [[ -z "$OS" ]]; then
        read -r -p "The release version is not detected, please enter it manually,like \"ubuntu\"" OS
    fi
    if ! echo "${support_os[@]}"|grep -w "$OS" &>/dev/null ; then
        log "[error]" "This system is not supported by docker, exit"
        exit 1
    else
        log "[info]" "system : $OS ;Package manager $PG"
    fi
}
down(){
    for link in "${mirror_pods[@]}"; do
        
        if wget -nv "${link}/$1" -O "$2" ; then
            break
        else
            continue
        fi
        log "[error]" "Download ${link}/$1 failed"
    done
    return 1
}
function version_ge() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"; }
function version_le() { test "$(echo "$@" | tr " " "\n" | sort -V  | head -n 1)" == "$1"; }
check_doc(){
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
    reta=$(which kubeadm>/dev/null;echo $?)
    retl=$(which kubelet>/dev/null;echo $?)
    retc=$(which kubectl>/dev/null;echo $?)
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
    ret=$(check_doc)
    if [[ $(ret) -eq 0 || ${ret} -eq 2 ]]   ; then
        log "[info]" "docker was found! skiped"
        return 0
    fi
    env_check
    if [[ "$PG" == "apt" ]]; then
        # Install docker with APT
        curl -fsSL "https://download.docker.com/linux/$OS/gpg" | apt-key add -
        echo "deb https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/$OS  $(lsb_release -cs) stable"  >/etc/apt/sources.list.d/docker.list
        apt update
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
        yum install -y yum-utils
        yum-config-manager --add-repo  https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
        yum makecache
        for line in $(yum list docker-ce --showduplicates|grep 'docker-ce'|awk '{print $2}'|sort -r) ; do
            if version_le "$(echo "$line" |grep -E -o '([0-9]+\.){2}[0-9]+')" "$DOC_HIG" ; then
                yum remove  -y docer-ce docker-ce-cli
                if echo "$line"|grep -q ':' ; then
                    line=$(echo "$line"|awk -F: '{print $2}')
                fi
                yum install -y  docker-ce-"$line" 
                break
            fi
        done
    else 
        log "[error]" "package manager ${PG} not support "
    fi
    if ! check_doc ; then
        log "[error]" "docker install fail,please check ${PG} environment"
        exit 1
    else
        log "[info]" "${PG} install -y  docker-ce-$line "
        systemctl enable docker &&systemctl start docker
    fi
}
init(){
    echo >$LOG_FILE
    if ! systemctl enable ntp  >/dev/null 2>&1 ; then
        timedatectl set-ntp true
    else
        systemctl start ntp
    fi
    mkdir -p /etc/cni/net.d
    mkdir -p $BASE_DIR/{scripts,nodeapi,compute}
    swapoff -a
    env_check
    check_info
}
_k8s_ins_yum(){
    cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
    setenforce 0
    yum install  -y kubelet-1.12.3 kubeadm-1.12.3 kubectl-1.12.3 kubernetes-cni-0.6.0
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
    if ! check_k8s ; then
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
node_ins(){
    arch=$(uname -m)
    kel_v=$(uname -r|grep -E -o '([0-9]+\.){2}[0-9]')
    Rlink="img-modules"
    if  version_ge "$kel_v" "5.0.0" ; then
        Rlink="$Rlink/5.0.0-aml-N1-BonusCloud"
    fi
    down "$Rlink/info.txt" "$TMP/info.txt"
    if [ ! -s "$TMP/info.txt" ]; then
        log "[error]" "wget \"$Rlink/info.txt\" -O $TMP/info.txt"
        return 1
    fi
    for line in $(grep "$arch" $TMP/info.txt)
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
        down "$Rlink/$git_file_name" "$TMP/$git_file_name" 
        download_md5=$(md5sum $TMP/"$git_file_name" | awk '{print $1}')
        if [ "$download_md5"x != "$git_md5_val"x ];then
            log "[error]" " download file $TMP/$git_file_name md5 $download_md5 different from git md5 $git_md5_val"
            continue
        else
            log "[info]" " $TMP/$git_file_name download success."
            cp -f $TMP/"$git_file_name" "$file_path" > /dev/null
            chmod "$mod" "$file_path" > /dev/null            
        fi
    done
    _set_node_systemd
    systemctl daemon-reload
    systemctl enable bxc-node
    systemctl start bxc-node
    sleep 1
    isactive=$(curl -fsSL http://localhost:9017/version>/dev/null; echo $?)
    if [ "${isactive}" -ne 0 ];then
        log "[error]" " node start faild, rollback and restart"
        systemctl restart bxc-node
    else
        log "[info]" " node start success."
    fi
}
node_remove(){
    systemctl stop bxc-node
    systemctl disable bxc-node
    rm -rf /lib/systemd/system/bxc-node.service /opt/bcloud/nodeapi/node
}
bxc-network_ins(){
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
    
    if ! which proxy >/dev/null ; then
        LAST_VERSION=$(curl --silent "https://api.github.com/repos/snail007/goproxy/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')
        [ ! -s ${TMP}/proxy-linux-amd64.tar.gz ] &&wget "https://github.com/snail007/goproxy/releases/download/${LAST_VERSION}/proxy-linux-amd64.tar.gz" -O ${TMP}/proxy-linux-amd64.tar.gz
        mkdir -p ${TMP}/goproxy/
        tar -xf  ${TMP}/proxy-linux-amd64.tar.gz -C ${TMP}/goproxy/
        cp -f ${TMP}/goproxy/proxy /usr/bin/
        chmod +x /usr/bin/proxy
        if [ ! -e /etc/proxy ]; then
            mkdir /etc/proxy
            cp -f ${TMP}/goproxy/blocked /etc/proxy/
            cp -f ${TMP}/goproxy/direct  /etc/proxy/
        fi
        mkdir -p /var/log/goproxy
    fi
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
}

ins_salt(){
    
    if ! which salt-minion>/dev/null  ;then
        curl -fSL https://bootstrap.saltstack.com |bash -s -P stable 2019.2.0
    fi
    if [[ "${DEVMODEL}" == '' ]]; then
        DEVMODEL="x86_64"
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
    read -r -p "[Default YES/N]:" choose
    case $choose in
        N|n|no|NO ) return ;;
        * ) ins_salt ;;
    esac
}
read_bcode_input(){
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
only_ins_network_docker_openwrt(){
    ins_docker
    #docker pull qinghon/bxc-op:18.06.2
    docker tag qinghon/bxc-op:18.06.2 bxc-op:18.06.2
    if ! docker images --format "{{.Repository}}"|grep -q bxc-op ; then
        echoerr "pull failed,exit!"
        return 1
    fi
    local bcode=""
    local email=""
    if ! read_bcode_input ; then
        echoerr "read bcode or email failed,can't run! exit!"
        return 2
    fi
    bxc_network_bridge_id=$(docker network ls -f name=bxc --format "{{.ID}}:{{.Name}}"|grep bxc|awk -F: '{print $1}')
    if [[ -z "${bxc_network_bridge_id}" ]]; then
        docker network create  bxc
    fi
    mac_addr=$(od /dev/urandom -w6 -tx1 -An|sed -e 's/ //' -e 's/ /:/g'|head -n 1)
    echoinfo "Set mac address:";read -r -e -i "${mac_addr}" mac_addr
    if [[ -z "${mac_addr}" ]]; then
        mac_addr=$(od /dev/urandom -w6 -tx1 -An|sed -e 's/ //' -e 's/ /:/g'|head -n 1)
        echoinfo "Generate a mac address: $mac_addr\n"
    fi
    con_id=$(docker run -d --cap-add=NET_ADMIN --net=bxc --device /dev/net/tun --restart=always \
    --sysctl net.ipv6.conf.all.disable_ipv6=0 --mac-address="$mac_addr"\
    -e bcode="${bcode}" -e email="${email}" --name=bxc-network-"${bcode}" \
    -v bxc_data_"${bcode}":/opt/bcloud \
    qinghon/bxc-op:18.06.2)
    echo "${con_id}"
    sleep 2
    fail_log=$(docker logs "${con_id}" 2>&1 |grep 'bonud fail'|head -n 1)
    if [[ -n "${fail_log}" ]]; then
        echoerr "bound fail\n${fail_log}\n"
        docker stop "${con_id}"
        docker rm "${con_id}"
    fi
}
only_ins_network_choose_plan(){
    echoinfo "choose plan:\n"
    echoinfo "\t1) run as base progress(只运行基础进程,兼容性差,内存占用低)\n"
    echoinfo "\t2) run openwrt as docker (运行在docker里,兼容性好,内存占用高)\n"
    echoinfo "CHOOSE [1|2]:"
    read -r  CHOOSE
    case $CHOOSE in
        1 ) only_ins_network_base;;
        2 ) only_ins_network_docker_openwrt ;;
        * ) echowarn "\nno choose(未选择)\n";;
    esac
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
    network_docker=$(docker images --format "{{.Repository}}"|grep -q bxc-op;echo $?)
    network_file_have=$([ -s ${BASE_DIR}/bxc-network ] || [ "${network_docker}" -eq 0 ];echo $?)   
    
    network_progress=$(pgrep bxc-network>/dev/null;echo $?)
    [[ ${network_progress} -eq 0 ]] &&network_con_id=$(docker ps --filter="ancestor=bxc-op:18.06.2" --format "{{.ID}}"|head -n 1)
    
    tun0exits=$(ip link show tun0 >/dev/null 2>&1 ;echo $?)
    [[ ${network_file_have} -eq 0 ]] &&tun0exits=$(ip link show tun0 >/dev/null 2>&1 ;echo $?)
    [[ ${network_docker} -eq 0  && -n "${network_con_id}" ]] &&tun0exits=$(docker exec -i "${network_con_id}" /bin/sh -c "ip link show dev tun0>/dev/null;echo $?")
    [[ $network_file_have -ne 0 && -z "${network_con_id}" ]] &&tun0exits=1

    goproxy_progress=$(curl -x "127.0.0.1:8901" https://www.baidu.com -o /dev/null 2>/dev/null;echo $?)
    [[ -n "${network_con_id}" ]] &&goproxy_progress=$(docker exec -i "${network_con_id}" /bin/sh -c "pgrep bxc-worker>/dev/null;echo $?")
    # node check
    node_progress=$(pgrep  node>/dev/null;echo $?)
    node_file=$([ -s ${BASE_DIR}/nodeapi/node ];echo $?)
    [ "${node_progress}" -eq 0 ]&&node_version=$(curl -fsS localhost:9017/version|grep -E -o 'v[0-9]\.[0-9]\.[0-9]')
    # k8s check
    k8s_file=$(check_k8s;echo $?)
    k8s_progress=$(pgrep kubelet>/dev/null;echo $?)
    
    #docker check
    doc_che_ret=$(check_doc)

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
    echowarn "\ndocker:\n"
    [[ ${doc_che_ret} -eq 1  ]] && { echoins "1";}||echoins "0"
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
            echoinfo "BonusCloud plugin removed"
            k8s_remove
            echoinfo "k8s removed"
            echoinfo "see you again!"
            ;;
        * ) return ;;
    esac

}
displayhelp(){
    echo -e "\033[2J"
    echo "bash $0 [option]" 
    echo -e "    -h             Print this and exit"
    echo -e "    -i             Installation environment check and initialization"
    echo -e "    -k             Install the k8s environment and the k8s components that" 
    echo -e "                   BonusCloud depends on"
    echo -e "    -n             Install node management components"
    echo -e "    -r             Fully remove bonuscloud plug-ins and components"
    echo -e "    -s             Install salt-minion for remote debugging by developers"
    echo -e "    -c             change kernel to compiled dedicated kernels,only \"Phicomm N1\"" 
    echo -e "                   and is danger!"
    echo -e "    -e             set interfaces name to ethx"
    echo -e "    -g             Install network job only"
    echo -e "    -I Interface   set interface name to you want"
    echo -e "    -S             Don'n show Info level output "
    exit 0
}
while  getopts "bdiknrstceghI:TS" opt ; do
    case $opt in
        i ) action="init" ;;
        b ) bound ;exit 0;;
        d ) action="docker" ;;
        k ) action="k8s" ;;
        n ) action="node" ;;
        r ) action="remove" ;;
        s ) action="salt" ;;
        c ) action="change_kn" ;;
        e ) action="set_ethx" ;;
        g ) action="only_net" ;;
        h ) displayhelp ;;
        t ) mg ;exit 0 ;;
        T ) bxc-network_ins;exit 0 ;;
        I ) _select_interface "${OPTARG}" ;;
        S ) DISPLAYINFO="0" ;;
        ? ) echoerr "Unknow arg. exiting" ;displayhelp; exit 1 ;;
    esac
done
echo $action
case $action in
    init     ) init ;;
    docker   ) env_check;ins_docker ;;
    node     ) node_ins ;;
    remove   ) remove ;;
    salt     ) ins_salt ;;
    change_kn) ins_kernel ;;
    set_ethx ) set_interfaces_name ;;
    only_net ) only_ins_network_choose_plan;;
    k8s      )
        env_check
        ins_k8s
        ;;
    * )
        init
        ins_docker
        ins_k8s
        ins_conf
        node_ins
        ins_salt_check
        res=$(verifty;echo $?) 
        if [[ ${res} -ne 0 ]] ; then
            log "[error]" "verifty error $res,install fail"
        else
            log "[info]" "All install over"
        fi
        ;;
esac
sync