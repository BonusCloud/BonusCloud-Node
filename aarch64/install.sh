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
DEFAULT_LINK=$(ip route list|grep 'default'|awk '{print $5}')
DEFAULT_MACADDR=$(ip link show "${DEFAULT_LINK}"|grep 'ether'|awk '{print $2}')
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
    # Check if the system is arm64
    if [[ "`uname -m |grep -qE 'aarch64';echo $?`" -ne 0 ]]; then
        log "[error]" "this is 64 system install script for arm64 ,if you's not ,please install correspond system"
        exit 1
    fi
    # Detection package manager
    ret_a=$(which apt >/dev/null;echo $?)
    ret_y=$(which yum >/dev/null;echo $?)
    if [[ ${ret_a} -eq 0 ]]; then
        PG="apt"
    elif [[ ${ret_y} -eq 0 ]]; then
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
    [ ! -s $TMP/screenfetch ]&&wget  -nv --show-progress -O $TMP/screenfetch "https://raw.githubusercontent.com/KittyKatt/screenFetch/master/screenfetch-dev" 
    chmod +x $TMP/screenfetch
    OS=$($TMP/screenfetch -n |grep 'OS:'|awk '{print $3}'|tr 'A-Z' 'a-z')
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
function version_le() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" == "$1"; }
check_doc(){
    retd=$(which docker>/dev/null;echo $?)
    if [ "${retd}" -ne 0 ]; then
        log "[info]" "docker not found"
        return 1
    fi
    doc_v=$(docker version |grep Version|grep -o '[0-9\.]*'|sed -n '2p')
    if version_ge "${doc_v}" "${DOC_LOW}" && version_le "${doc_v}" "${DOC_HIG}" ; then
        log "[info]" "docker version above ${DOC_LOW} and below ${DOC_HIG}"
        return 0
    else
        log "[info]" "docker version fail"
        return 1
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
        k8s_adm=$(kubeadm version|grep -o '\"v[0-9\.]*\"'|grep -o '[0-9\.]*')
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
    if ! check_doc ; then
        log "[info]" "docker was found! skiped"
        return 0
    fi
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
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-aarch64/
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
    docker pull registry.cn-beijing.aliyuncs.com/bxc_k8s_gcr_io/pause:arm-3.1
    docker pull registry.cn-beijing.aliyuncs.com/bxc_k8s_gcr_io/kube-proxy-arm:v1.12.3
    docker tag registry.cn-beijing.aliyuncs.com/bxc_k8s_gcr_io/pause:arm-3.1 k8s.gcr.io/pause:3.1
    docker tag registry.cn-beijing.aliyuncs.com/bxc_k8s_gcr_io/kube-proxy-arm:v1.12.3 k8s.gcr.io/kube-proxy:v1.12.3 
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
    ${PG} remove -y kubelet kubeadm kubectl kubernetes-cni
    rm -rf /etc/sysctl.d/k8s.conf
}
ins_conf(){
    down "aarch64/res/compute/10-mynet.conflist" "$BASE_DIR/compute/10-mynet.conflist"
    down "aarch64/res/compute/99-loopback.conf" "$BASE_DIR/compute/99-loopback.conf"
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



ins_salt(){
    
    if ! which salt-minion>/dev/null  ;then
        curl -fSL https://bootstrap.saltstack.com |bash -s -P stable 2019.2.0
    fi
    if [[ "${DEVMODEL}" == '' ]]; then
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
    read -r -p "[Default YES/N]:" choose
    case $choose in
        N|n|no|NO ) return ;;
        * ) ins_salt ;;
    esac
}
bound(){
    [ -s ${NODE_INFO} ]&&log "[info]" "${NODE_INFO} exits ,skip" && return 0
    read -r -p "Input bcode:" bcode
    read -r -p "Input email:" email
    if [[ -z "${bcode}" ]] || [[ -z "${email}" ]]; then
        echo "Please Input bcode and email. You can try \"bash $0 -b\" to bound"
        return 1
    fi
    replacebcode=$(echo "${bcode}"|grep -E -o "[0-9a-f]{4}-[0-9a-f]{8}-([0-9a-f]{4}-){2}[0-9a-f]{4}-[0-9a-f]{12}")
    if [[ -n "${replacebcode}" ]]; then
        echo "bcode:${replacebcode}  email:${email}"
        curl -H "Content-Type: application/json" -d "{\"bcode\":\"${replacebcode}\",\"email\":\"${email}\"}" http://localhost:9017/bound
        
    else
        echo "Please input verifty you bcode!You can try \"bash $0 -b\" to bound"
        return 1
    fi
}
change_net(){
    if [[ "$PG" == "apt" ]]; then
        apt -y purge network-manager
    fi
    rm /etc/dhcp/dhclient-enter-hooks.d/resolvconf
    echo -e '#!/bin/sh \nifconfig eth0 mtu 1400 '>/etc/network/if-pre-up.d/mtu
    chmod +x /etc/network/if-pre-up.d/mtu
    apt install -y netplug
}
ins_kernel_from_armbian(){

    kernel_version=` uname -r|egrep -o '([0-9]+\.){2}[0-9]+'`
    if version_ge $kernel_version 5.0.0 ; then
        echo "This system kernel version greater than 5.0.0 ,nothing can do"
        return 
    fi
    _device=`apt list linux-dtb-*|grep linux|awk -F/ '{print $1}'`
    device=${_device:10}
    # don't run it ,this unverified
    aptitude remove ~nlinux-dtb ~nlinux-u-boot ~nlinux-image ~nlinux-headers
    aptitude remove ~nlinux-firmware ~narmbian-firmware ~nlinux-$(lsb_release -cs)-root
    apt install -y linux-image-dev-${device} linux-dtb-dev-${device} linux-headers-dev-${device}
    apt install -y linux-u-boot-${device}-dev linux-$(lsb_release -cs)-root-dev-${device}
    apt-get install armbian-firmware ${device}-tools swconfig a10disp
}
ins_kernel(){
    if [[ "${DEVMODEL}" != "Phicomm N1" ]]; then
        echo "this device not ${device_tree} exit"
        return 1
    fi
    down "/aarch64/res/N1_kernel/md5sum" "$TMP/md5sum"
    down "/aarch64/res/N1_kernel/System.map-5.0.0-aml-N1-BonusCloud-1-1.xz" "$TMP/System.map-5.0.0-aml-N1-BonusCloud-1-1.xz"
    down "/aarch64/res/N1_kernel/vmlinuz-5.0.0-aml-N1-BonusCloud-1-1.xz" "$TMP/vmlinuz-5.0.0-aml-N1-BonusCloud-1-1.xz"
    down "/aarch64/res/N1_kernel/modules.tar.xz" "$TMP/modules.tar.xz"
    down "/aarch64/res/N1_kernel/N1.dtb" "$TMP/N1.dtb"
    echo "verifty file md5..."
    while read line; do
        file_name=`echo ${line} |awk '{print $2}'`
        git_md5=`echo ${line} |awk '{print $1}'`
        local_md5=`md5sum $TMP/$file_name|awk '{print $1}'`
        if [[ "$git_md5" != "$local_md5" ]]; then
            down "/aarch64/res/N1_kernel/$file_name" "$TMP/$file_name"
            local_md5=`md5sum $TMP/$file_name|awk '{print $1}'`
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
    res=`grep -q 'N1.dtb' /boot/uEnv.ini;echo $?`
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
    network_progress=$(pgrep bxc-network>/dev/null;echo $?)
    tun0exits=$(ip link show tun0 >/dev/null 2>&1 ;echo $?)
    network_file=$([ -s ${BASE_DIR}/bxc-network ];echo $?)
    node_progress=$(pgrep  node>/dev/null;echo $?)
    node_file=$([ -s ${BASE_DIR}/nodeapi/node ];echo $?)
    [ "${node_progress}" -eq 0 ]&&node_version=$(curl -fsS localhost:9017/version|grep -E -o 'v[0-9]\.[0-9]\.[0-9]')
    check_k8s
    k8s_file=$?
    k8s_progress=$(pgrep kubelet>/dev/null;echo $?)
    goproxy_progress=$(curl -x "127.0.0.1:8901" https://www.baidu.com -o /dev/null 2>/dev/null;echo $?)

    echowarn "\nbxc-network:\n"
    echo -e -n "|install?\t|running?\t|connect?\t|proxy aleady?\n"
    [ "${network_file}" -ne 0 ]&&{ echoins "1";}||echoins "0"
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
    check_doc
    [ $? -ne 0 ]&& { echoins "1";}||echoins "0"

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
    read -r -p "Are you sure all remove BonusCloud plugin? yes/n:" CHOSE
    case $CHOSE in
        yes )
            systemctl disable bxc-node
            rm -rf /opt/bcloud /lib/systemd/system/bxc-node.service $TMP
            echoinfo "BonusCloud plugin removed"
            
            apt remove -y kubelet kubectl kubeadm
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
    echo -e "    -I Interface   set interface name to you want"
    echo -e "    -c             change kernel to compiled dedicated kernels,only \"Phicomm N1\"" 
    echo -e "                   and is danger!"
    exit 0
}
while  getopts "bdiknrsceghI:tTS" opt ; do
    case $opt in
        i ) action="init" ;;
        b ) bound ;exit 0;;
        d ) action="docker" ;;
        k ) action="k8s" ;;
        n ) action="node" ;;
        r ) action="remove" ;;
        s ) action="salt" ;;
        c ) action="change_kn" ;;
        h ) displayhelp ;;
        t ) mg ;exit 0 ;;
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