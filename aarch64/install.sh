#!/usr/bin/env bash 

#https://github.com/BonusCloud/BonusCloud-Node/issues
#Author qinghon https://github.com/qinghon

OS=""
OS_CODENAME=""
PG=""
ARCH=""
VDIS=""
CRI=docker
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

K8S_LOW="1.27.1"
DOC_LOW="1.11.1"
DOC_HIG="20.12.12"

support_os=(
	centos
	debian
	fedora
	raspbian
	ubuntu
	manjarolinux
	manjaro
)
mirror_pods_node=(
	"https://bxc-node.s3.cn-east-2.jdcloud-oss.com"
	"https://bonuscloud.coding.net/p/BonusCloud-Node/d/BonusCloud-Node/git/raw/master/img-modules"
	"https://raw.githubusercontent.com/BonusCloud/BonusCloud-Node/master/img-modules"
)
mirror_pods_git=(
	"https://raw.githubusercontent.com/BonusCloud/BonusCloud-Node/master"
	"https://bonuscloud.coding.net/p/BonusCloud-Node/d/BonusCloud-Node/git/raw/master"
)

echoerr(){ printf "\033[1;31m$1\033[0m";}
echoinfo(){ printf "\033[1;32m$1\033[0m";}
echowarn(){ printf "\033[1;33m$1\033[0m";}
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
run_command(){
	#log '[info]' "$1"
	$1
	return $?
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
sys_osname(){
	if  which lsb_release >/dev/null  2>&1; then
		OS=$(lsb_release -is|tr '[A-Z]' '[a-z]')
		OS_CODENAME=$(lsb_release -cs|tr '[A-Z]' '[a-z]')
		return 
	fi
	source /etc/os-release
	case $ID in
		ubuntu )
			OS="ubuntu" 
			OS_CODENAME=$UBUNTU_CODENAME
			;;
		debian ) 
			OS="debian"
			if [[ $VERSION_CODENAME != "" ]]; then
				OS_CODENAME=$VERSION_CODENAME
			else
				OS_CODENAME=$(echo "$VERSION"|sed -e 's/(//g' -e 's/)//g'|awk '{print $2}')
			fi
			;;
		raspbian )
			OS="raspbian"
			OS_CODENAME=$(echo "$VERSION"|sed -e 's/(//g' -e 's/)//g'|awk '{print $2}')
			;;
		centos ) OS="centos" ;;
		*       ) OS="$ID"

	esac
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
_check_pg(){
	# Detection package manager
	if which apt-get >/dev/null 2>&1 ; then
		# echoinfo "Find apt\n"
		PG="apt-get"
	elif which yum >/dev/null 2>&1 ; then
		# echoinfo "Find yum\n"
		PG="yum"
	elif which pacman>/dev/null 2>&1 ; then
		# log "[info]" "Find pacman"
		PG="pacman"
	else
		log "[error]" "\"apt\" or \"yum\" or \"pacman\" ,not found ,exit "
		exit 1
	fi
}
_check_exec(){
	which "$1" >/dev/null 2>&1
	return $?
}
_install_pg(){
	[[ -z $PG ]] &&_check_pg
	case ${PG} in
		apt-get ) $PG install -y "$1";;
		yum ) $PG install -y "$1" ;;
		pacman ) $PG --needed --noconfirm -S "$1"
	esac
	if [[ -n "$2" ]]; then
		_install_pg $2
	fi
	if [[ $? -ne 0 ]]; then
		case ${PG} in
			apt-get )  $PG update&& _install_pg "$1" apt-transport-https ;;
			yum ) $PG makecache&& _install_pg "$1" ;;
		esac
	fi
}
env_check(){
	# 检查环境
	# Check if the system supports
	sys_osname
	echo "$OS"
	if ! echo "${support_os[@]}"|grep -w "$OS" &>/dev/null ; then
		log "[error]" "This system is not supported by docker, exit"
		exit 1
	else
		log "[info]" "system : $OS ;Package manager $PG"
	fi
	! _check_exec curl &&_install_pg curl
	! _check_exec wget &&_install_pg wget
	! _check_exec lspci &&_install_pg pciutils
	
}
down(){
	# 根据设置的源下载文件,错误时切换源
	local LINK=$1
	if [[ ${LINK:0:1} == "/" ]]; then
		LINK=${LINK:1}
	fi
	for link in "${mirror_pods_node[@]}"; do
		if wget -T 10 "${link}/$LINK" -O "$2" ; then
			break
		else
			continue
		fi
		log "[error]" "Download ${link}/$1 failed"
	done
	return 1
}
down_git(){
	# 根据设置的源下载文件,错误时切换源
	local LINK=$1
	if [[ ${LINK:0:1} == "/" ]]; then
		LINK=${LINK:1}
	fi
	for link in "${mirror_pods_git[@]}"; do
		if wget -T 10 "${link}/$LINK" -O "$2" ; then
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
	local retd
	local doc_v
	retd=$(which docker>/dev/null;echo $?)
	if [ "${retd}" -ne 0 ]; then
		log "[info]" "docker not found"
		return 1
	fi
}
check_k8s(){
	# 检查k8s安装状态和版本
	local reta
	local retl
	local k8s_adm
	local k8s_let
	reta=$(which kubeadm>/dev/null 2>&1;echo $?)
	retl=$(which kubelet>/dev/null 2>&1;echo $?)
	if [ "${reta}" -ne 0 ] || [ "${retl}" -ne 0 ] ; then
		log "[info]" "k8s not found"
		return 1
	else 
		k8s_adm=$(kubeadm version -o short|grep -o '[0-9\.]*')
		k8s_let=$(kubelet --version|grep -o '[0-9\.]*')
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
		return 0
	fi
}
check_info(){
	# 检测node.db文件是否有信息
	local res
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
_docker_apt(){
	# Install docker with APT
	# apt-get 安装docker
	apt-get install gnupg2 -y
	curl -fsSL "https://download.docker.com/linux/$OS/gpg" | apt-key add -
	if [[ $? -ne 0 ]]; then
		echoerr "add source public key failed ,check you network\n添加docker源公钥失败,检查您的网络配置,必要时请将download.docker.com加入代理\n"
		return 2
	fi
	echo "deb http://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/$OS  $OS_CODENAME stable"  >/etc/apt/sources.list.d/docker.list
	apt-get update
	apt-get install -y docker-ce
}   
_docker_yum(){
	yum install -y yum-utils
	yum-config-manager --add-repo  https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
	yum makecache
	yum install -y docker-ce
}
_docker_static(){
	curl https://raw.githubusercontent.com/docker/docker/master/contrib/check-config.sh > ${TMP}/check-config.sh
	if bash ${TMP}/check-config.sh ;then
		log "[error]" "You linux kernel not support runing docker;exit "
		return 1
	fi

	wget -O ${TMP}/docker-18.06.3-ce.tgz "http://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/static/stable/${ARCH}/docker-18.06.3-ce.tgz"
	tar -xvf ${TMP}/docker-18.06.3-ce.tgz
	cp ${TMP}/docker/* /usr/bin/
	groupadd docker --gid 999 --system
	printf "[Unit]
		Description=Docker Socket for the API
		PartOf=docker.service
		
		[Socket]
		ListenStream=/var/run/docker.sock
		SocketMode=0660
		SocketUser=root
		SocketGroup=docker
		
		[Install]
		WantedBy=sockets.target 
	"|sed 's/    //g' >/lib/systemd/system/docker.socket
	printf "[Unit]
		Description=Docker Application Container Engine
		Documentation=https://docs.docker.com
		BindsTo=containerd.service
		After=network-online.target firewalld.service containerd.service
		Wants=network-online.target
		Requires=docker.socket
	
		[Service]
		Type=notify
		ExecStart=/usr/bin/dockerd -H fd://
		ExecReload=/bin/kill -s HUP \$MAINPID
		TimeoutSec=0
		RestartSec=2
		Restart=always
		StartLimitBurst=3
		StartLimitInterval=60s
		LimitNOFILE=infinity
		LimitNPROC=infinity
		LimitCORE=infinity
		TasksMax=infinity
		Delegate=yes
		KillMode=process
	
		[Install]
		WantedBy=multi-user.target
	"|sed 's/    //g' >/lib/systemd/system/docker.service

	systemctl enable docker.socket &&systemctl start docker.socket
}
ins_docker(){
	# 安装docker
	local ret
	check_doc
	ret=$?
	if [[ ${ret} -eq 0 || ${ret} -eq 2 ]]   ; then
		log "[info]" "docker was found! skiped"
		return 0
	fi
	env_check
	case $PG in
		apt-get ) _docker_apt ;;
		yum ) _docker_yum ;;
		pacman ) $PG --needed --noconfirm -S docker ethtool ;;
		* ) _docker_static ;;
		# * ) log "[error]" "package manager ${PG} not support "; return 1 ;;
	esac
	[ -n "${USER}" ] && usermod -aG docker "${USER}"
	systemctl enable docker.socket &&systemctl start docker.socket
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
ins_podman(){
	env_check
	case $PG in
		apt-get ) apt-get install -y podman ;;
		pacman ) $PG --needed --noconfirm -S podman ;;
		 * ) log "[error]" "package manager ${PG} not support podman"; return 1 ;;
	esac
	if ! cat /etc/containers/registries.conf | grep -v '^#'|grep -q 'docker.io' ; then
		echo 'unqualified-search-registries=["docker.io"]' >> /etc/containers/registries.conf
	fi
	if [[ -s /lib/systemd/system/podman-restart.service ]] ; then
		systemctl enable podman-restart.service
		return 0
	fi
	mkdir -p /usr/local/bin
	printf '#!/bin/bash
	podman ps -a|grep -v CON|cut -d " " -f1|while read line;
	do
	if [[ $(podman inspect -f "{{ .HostConfig.RestartPolicy.Name }}" $line ) == "always" ]] ;then
		podman start $line
	fi
	done\n'| sed 's/    //g' > /usr/local/bin/podman-restart.sh
	chmod +x /usr/local/bin/podman-restart.sh
	if ! grep -q 'podman-restart' /etc/rc.local ; then
		sed -i "/exit/i\/usr/local/bin/podman-restart.sh" /etc/rc.local
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
	_check_pg
	case $PG in
		apt-get     ) $PG install -y jq ;;
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
_lvm_ins(){
	case $PG in
		apt-get ) apt-get install -y lvm2;;
		yum ) yum install -y lvm2;;
	esac
}
_k8s_ins_yum(){
	printf "
	[kubernetes]
	name=Kubernetes
	baseurl=https://pkgs.k8s.io/core:/stable:/v1.27/rpm/
	enabled=1
	gpgcheck=1
	repo_gpgcheck=1
	exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
	gpgkey=https://pkgs.k8s.io/core:/stable:/v1.27/rpm/repodata/repomd.xml.key
	"|sed 's/    //g'> /etc/yum.repos.d/kubernetes.repo
	setenforce 0
	yum install  -y kubelet-1.27.1
	yum --exclude kubelet kubeadm kubernetes-cni
	systemctl stop firewalld && systemctl disable firewalld
	systemctl enable kubelet && systemctl start kubelet
}
_k8s_ins_apt(){
	curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.27/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
	echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.27/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
	log "[info]" "installing k8s"
	apt-get update
	apt-mark unhold kubelet kubeadm kubernetes-cni
	apt-get install -y --allow-downgrades kubeadm=1.27.1-1.1
	apt-mark hold kubelet kubeadm kubernetes-cni
	if [[ $OS == "ubuntu" ]]; then
	    containerd config default > /etc/containerd/config.toml
	    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
	fi
}
_k8s_ins_static(){
	sysArch
	export CNI_VERSION="v0.6.0"
	mkdir -p /opt/cni/bin
	wget -O- "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-${VDIS}-${CNI_VERSION}.tgz" | tar -C /opt/cni/bin -xz
	export CRICTL_VERSION="v1.13.0"
	wget -O- "https://github.com/kubernetes-incubator/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${VDIS}.tar.gz" | tar -C /usr/bin -xz

	RELEASE="v1.27.1"
	cd /usr/bin
	curl -L --remote-name-all https://storage.googleapis.com/kubernetes-release/release/${RELEASE}/bin/linux/${VDIS}/{kubeadm,kubelet}
	chmod +x {kubeadm,kubelet}
	cd -

	printf "[Unit]
		Description=kubelet: The Kubernetes Node Agent
		Documentation=http://kubernetes.io/docs/

		[Service]
		ExecStart=/usr/bin/kubelet
		Restart=always
		StartLimitInterval=0
		RestartSec=10

		[Install]
		WantedBy=multi-user.target
	" |sed 's/    //g' >/etc/systemd/system/kubelet.service
	mkdir -p /etc/systemd/system/kubelet.service.d
	printf "
		# Note: This dropin only works with kubeadm and kubelet v1.11+
		[Service]
		Environment=\"KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf\"
		Environment=\"KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml\"
		# This is a file that \"kubeadm init\" and \"kubeadm join\" generates at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
		EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
		# This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
		# the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
		EnvironmentFile=-/etc/default/kubelet
		ExecStart=
		ExecStart=/usr/bin/kubelet \$KUBELET_KUBECONFIG_ARGS \$KUBELET_CONFIG_ARGS \$KUBELET_KUBEADM_ARGS \$KUBELET_EXTRA_ARGS
	"|sed 's/    //g' >/etc/systemd/system/kubelet.service.d/10-kubeadm.conf
	systemctl enable kubelet && systemctl start kubelet
}
pull_docker_image(){
	ins_docker
	case $VDIS in
		arm   ) pause_TAG="arm32-3.1" ; proxy_name="kube-proxy-arm"     ;;
		arm64 ) pause_TAG="arm-3.1"   ; proxy_name="kube-proxy-arm64"   ;;
		amd64 ) pause_TAG="3.1"       ; proxy_name="kube-proxy"         ;;
	esac
#	docker pull registry.cn-beijing.aliyuncs.com/bxc_k8s_gcr_io/pause:$pause_TAG
#	docker pull registry.cn-beijing.aliyuncs.com/bxc_k8s_gcr_io/$proxy_name:v1.12.3

#	docker tag registry.cn-beijing.aliyuncs.com/bxc_k8s_gcr_io/pause:$pause_TAG k8s.gcr.io/pause:3.1
#	docker tag registry.cn-beijing.aliyuncs.com/bxc_k8s_gcr_io/$proxy_name:v1.12.3 k8s.gcr.io/kube-proxy:v1.12.3
}
ins_k8s(){
	swapoff -a
	sed -i 's/\([a-z/\\\.]\+swap\.\+\)/#\1/g' /etc/fstab
	if ! grep -q '^swapoff' /etc/rc.local  ; then
		sed -i "/exit/i\swapoff -a #bxc script" /etc/rc.local
	fi
	systemctl stop armbian-zram-config.service&&systemctl disable armbian-zram-config.service
	if ! check_k8s ; then
		init
		case $PG in
			apt-get ) _k8s_ins_apt ;;
			yum ) _k8s_ins_yum ;;
			*    ) _k8s_ins_static ;;
		esac
		if ! check_k8s ; then
			log "[error]" "k8s install fail!"
			exit 1
		fi
	else
		log "[info]" " k8s was found! skip"
	fi
	_lvm_ins
	pull_docker_image
	printf "vm.swappiness = 0
	net.ipv6.conf.default.forwarding = 1
	net.bridge.bridge-nf-call-iptables = 1
	net.bridge.bridge-nf-call-ip6tables = 1
	net.ipv6.conf.tun0.mtu = 1280
	net.ipv4.tcp_congestion_control = bbr
	net.ipv4.ip_forward = 1 "|sed 's/    //g'>/etc/sysctl.d/k8s.conf
	modprobe br_netfilter
	printf "tcp_bbr\nx_tables\nbr_netfilter\n" > /etc/modules-load.d/k8s.conf
	sysctl -p /etc/sysctl.d/k8s.conf 2>/dev/null
	log "[info]" "k8s install over"
	ins_conf
}
k8s_remove(){
	kubeadm reset -f
	case $PG in
		yum ) $PG remove -y kubeadm kubelet kubectl ;;
		apt-get ) $PG remove -y kubeadm kubelet kubectl --allow-change-held-packages ;;
	esac
	rm -rf /etc/sysctl.d/k8s.conf
}
ins_conf(){
	printf '{"name": "mynet",
	  "cniVersion": "0.3.0",
	  "plugins": [
		{"type": "bridge",
		  "bridge": "cni0",
		  "ipMasq": true,
		  "isGateway": true,
		  "ipam": {"type": "host-local","subnet": "10.244.1.0/24","routes": [{"dst": "0.0.0.0/0"}]}
		},
		{"type": "portmap","capabilities": {"portMappings": true}}
	  ]}' > "$BASE_DIR/compute/10-mynet.conflist"

	printf '{"cniVersion": "0.3.0","type": "loopback"}' > "$BASE_DIR/compute/99-loopback.conf"
}

_set_node_systemd(){
	# 指定网卡启动node
	local INSERT_STR
	local DON_SET_DISK
	if [[ -z "${SET_LINK}" ]]; then
		INSERT_STR=""
	else
		INSERT_STR="--intf ${SET_LINK}"
	fi
	# 启动时不设置硬盘
	if [[ ${_DON_SET_DISK} -eq 1 ]]; then
		DON_SET_DISK="--devoff"
	fi
	printf "
		[Unit]
		Description=bxc node app
		After=docker.service
		
		[Service]
		ExecStart=/opt/bcloud/nodeapi/node --alsologtostderr ${DON_SET_DISK} ${INSERT_STR} 
		Restart=always
		RestartSec=10
		
		[Install]
		WantedBy=multi-user.target
	"|sed 's/	//g' >/lib/systemd/system/bxc-node.service
}
node_ins(){
	mkdir -p $BASE_DIR/{scripts,nodeapi,compute}
	# 安装node组件
	# 区分kernel版本下载文件
	# kel_v=$(uname -r|grep -E -o '([0-9]+\.){2}[0-9]')

	# if  version_ge "$kel_v" "5.0.0" ; then
	#     Rlink="5.0.0-aml-N1-BonusCloud"
	# fi
	# 下载文件列表
	[[ ! -f $TMP/info.txt ]]&&down "info.txt" "$TMP/info.txt"
	if [ ! -s "$TMP/info.txt" ]; then
		log "[error]" "wget \"info.txt\" -O $TMP/info.txt"
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
	rm -rvf /lib/systemd/system/bxc-node.service
	rm -rvf /opt/bcloud/nodeapi/node
}
bxc-network_ins(){
	# 安装网络插件,用与连接到bxc网络
	ret_4=$(apt-get list libcurl4 2>/dev/null|grep -q installed;echo $?)
	if [[ ${ret_4} -eq 0 ]]; then
		log "[info]" "Install libcurl4 library bxc-network"
		down "bxc-network_$ARCH" "${BASE_DIR}/bxc-network"
		chmod +x ${BASE_DIR}/bxc-network
	fi
	ret_3=$(apt-get list libcurl3 2>/dev/null|grep -q installed;echo $?)
	if [[ ${ret_3} -eq 0 ]]; then
		log "[info]" "Install libcurl3 library bxc-network"
		down "5.0.0-aml-N1-BonusCloud/bxc-network_$ARCH" "${BASE_DIR}/bxc-network"
		chmod +x ${BASE_DIR}/bxc-network
	fi
	apt-get install -y liblzo2-2 libjson-c3 
	${BASE_DIR}/bxc-network |grep libraries
	printf "[Unit]
	Description=bxc network daemon
	After=network.target

	[Service]
	ExecStart=/opt/bcloud/bxc-network
	Restart=always
	RestartSec=10
	
	[Install]
	WantedBy=multi-user.target "|sed 's/    //g'>/lib/systemd/system/bxc-network.service
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
	
	printf "[Unit]
	Description=bxc network proxy http
	After=network.target
	[Service]
	ExecStart=/usr/bin/proxy http -p [::]:8901 --log /var/log/goproxy/http_proxy.log
	Restart=always
	RestartSec=10
	[Install]
	WantedBy=multi-user.target \n"|sed 's/    //g'>/lib/systemd/system/bxc-goproxy-http.service
	printf "[Unit]
	Description=bxc network proxy socks
	After=network.target
	[Service]
	ExecStart=/usr/bin/proxy socks -p [::]:8902 --log /var/log/goproxy/socks_proxy.log
	Restart=always
	RestartSec=10
	[Install]
	WantedBy=multi-user.target \n"|sed 's/    //g' >/lib/systemd/system/bxc-goproxy-socks.service

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
	rm -vf /opt/bcloud/teleport
	systemctl disable teleport
	systemctl stop teleport
	rm -vf /lib/systemd/system/teleport.service 2>&1 
	rm -vf /etc/systemd/system/teleport.service 2>&1 
}
iostat_ins(){
	case $PG in
		apt-get ) apt-get update&&apt-get install sysstat -y ;;
		yum ) yum install sysstat -y ;;
	esac
}
smarttool_ins(){
	if which smartctl  >/dev/null 2>&1; then
		return
	fi
	case $PG in
		apt-get|yum ) $PG install smartmontools -y ;;
		pacman ) $PG --needed --noconfirm -S smartmontools ;;
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
	network_result=$($CRI run --rm -it --net=bxc1 "$image_name" \
	/bin/sh -c "curl -m 3 -fs baidu.com -o /dev/null >/dev/null 2>&1";echo $?)
	if [[ $network_result -ne 0 ]]; then
		echoerr "This bridge network can not connect network,curl return $network_result\n"
		read -r -e -p "Delete this network?:" -i "Y" -t 5 choose
		choose=${choose:-"Y"}
		case $choose in
			Y|y ) $CRI network rm bxc1 &&echoerr "\nDelete success\n";;
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
		systemctl enable rc.local.service 2>/dev/null
	fi
	if ! grep -q "${LINK} promisc" /etc/rc.local ; then
		sed -i "/exit/i\ip link set ${LINK} promisc on" /etc/rc.local
	fi
	#add pppoe support
	if [[ $_SET_PPPOE -eq 1 ]]; then
		if grep -q 'ppp' /etc/modules-load.d/bxc-net.conf 2>/dev/null; then
			return 0
		fi
		echo pppoe >> /etc/modules
		printf "tun\nppp-compress-18\nppp_mppe\nppp_deflate\nppp_async\npppoatm\nppp_generic\n">/etc/modules-load.d/bxc-net.conf
		echoinfo "We need reboot,after reboot you should run this command again\n"
		echoinfo "需要重启,重启之后你需要再次运行此命令\n"
		read -r -p "reboot now?(现在重启吗)[Y|n]" choose
		case $choose in
			y|Y ) reboot ;;
		esac
	fi
}
only_ins_network_del_net(){
	$CRI network rm bxc1 && { echoinfo "Delete success\n" ;} || echoerr "Delete error\n"
}
only_ins_network_podman_dhcp(){
	printf "%s\n" '[Unit]
	Description=DHCP Client for CNI

	[Socket]
	ListenStream=%t/cni/dhcp.sock
	SocketMode=0600

	[Install]
	WantedBy=sockets.target'| sed 's/    //g' > /usr/lib/systemd/system/io.podman.dhcp.socket
	printf "[Unit]
	Description=DHCP Client CNI Service
	Requires=io.podman.dhcp.socket
	After=io.podman.dhcp.socket

	[Service]
	Type=simple
	ExecStart=/usr/lib/cni/dhcp daemon
	TimeoutStopSec=30
	KillMode=process

	[Install]
	WantedBy=multi-user.target
	Also=io.podman.dhcp.socket\n"| sed 's/    //g' > /usr/lib/systemd/system/io.podman.dhcp.service
	systemctl --now enable io.podman.dhcp.socket
}

only_net_set_bridge(){
	# 设置macvlan桥接网络
	bxc_network_bridge_id=$($CRI network ls -f name=bxc --format "{{.ID}}:{{.Name}}"|grep -E 'bxc-macvlan|bxc1'|awk -F: '{print $1}')
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
	if [ $CRI == "docker" ]; then
		echoinfo "Set ip range(设置IP范围):\n";read -r -e -i "${LINK_SUBNET}" SET_RANGE
	else
		SET_RANGE=$LINK_SUBNET
	fi
	local NET_CMD
	local AUX
	if [[ $CRI == "podman" ]]; then
		only_ins_network_podman_dhcp
		AUX=""
	else
		AUX=--aux-address=$(hostname)=${LINK_HOSTIP}
	fi


	NET_CMD="$CRI network create -d macvlan --subnet=${LINK_SUBNET} \
	--gateway=${LINK_GW} ${AUX} \
	--ip-range=${SET_RANGE} \
	-o parent=${LINK} -o macvlan_mode=bridge bxc1"
	echo "$NET_CMD"
	#创建macvlan 网络
	run_command "${NET_CMD}"
	echoinfo "Config sure? [Y/n]:\n";read -r -e -i "Y" SURE_NET
	case "$SURE_NET" in
		N|n ) only_ins_network_del_net ;return 4 ;;
	esac
	if [[ $_SET_PPPOE -eq 1 ]]; then
		return 0
	fi
	# 检验网卡通不通
	if ! only_net_check_network ; then
		return 3
	fi
	return 0;
}



generate_mac_addr(){
	# 随机生成mac
	random_mac_addr=$(od /dev/urandom -w4 -tx1 -An|sed -e 's/ //' -e 's/ /:/g'|head -n 1)
	if [[ -z $mac_head ]]; then
		local mac_head_tmp
		mac_head_tmp=$(od /dev/urandom -w2 -tx1 -An|sed -e 's/ //' -e 's/ /:/g'|head -n 1)
		while grep -qE '^(.[13579bdf])' <<< "$mac_head_tmp" ; do
			mac_head_tmp=$(od /dev/urandom -w2 -tx1 -An|sed -e 's/ //' -e 's/ /:/g'|head -n 1)
		done
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
		set_ipaddress="--ip=${ipaddress}"
	else
		set_ipaddress=''
	fi
	# 设置宽带拨号
	if [[ $_SET_PPPOE -eq 1 ]] ;then
		read -r -p "pppoe username:" -e -i "$pppoe_user"  pppoe_user
		read -r -p "pppoe password:" -e -i "$pppoe_passwd" pppoe_passwd
		if [[ -n $pppoe_user && -n $pppoe_passwd ]]; then
			ppp_account="-e PPPOE_NAME=$pppoe_user -e PPPOE_PASSWD=$pppoe_passwd "
		else
			echoerr "set error\n"
			return 1
		fi
	fi
	if [[ $_NEED_PUBIP -eq 1 ]]; then
		local need_pubip=" -e NEED_PUBIP=1"
	fi
	local network_name
	if $CRI network ls -f name=bxc --format "{{.Name}}"|grep -q 'bxc1'; then
		network_name="--net=bxc1"
	else
		network_name="--net=bxc-macvlan"
	fi
	command="$CRI run -d --restart=always  $network_name $set_ipaddress --mac-address=$mac_addr \
		--sysctl net.ipv6.conf.all.disable_ipv6=0 --device /dev/net/tun --device /dev/ppp --cap-add=NET_ADMIN \
		-e bcode=${bcode} -e email=${email} ${ppp_account} ${need_pubip} --name=bxc-${bcode} \
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
	fail_log=$($CRI logs "${con_id}" 2>&1 |grep 'bonud fail'|head -n 1)
	if [[ -n "${fail_log}" ]]; then
		echoerr "bound fail\n${fail_log}\n"
		$CRI stop "${con_id}"
		$CRI rm "${con_id}"
		return 3
	fi
	# 检测是否为mac问题导致不能running,并清除
	create_status=$($CRI container inspect "${con_id}" --format "{{.State.Status}}")
	if [[ "$create_status" == "created" ]]; then
		echowarn "Delete can not run container\n"
		$CRI container rm "${con_id}"
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
		$CRI pull "${image_name}"
		if [[ $? -ne 0 ]]; then
			image_name="registry.cn-hangzhou.aliyuncs.com/bonuscloud/bxc-net:$VDIS"
			$CRI pull "${image_name}"
		fi
	else
		echowarn "Skip $image_name download\n"
	fi
	if ! $CRI image inspect ${image_name} > /dev/null; then
		echoerr "pull failed,exit!,you can try: $CRI pull ${image_name}\n"
		return 1
	fi
}
only_ins_network_docker_openwrt(){
	case $CRI in
		docker ) ins_docker;;
		podman ) ins_podman;;
	esac
	ins_jq
	local image_name=""
	local mac_head=""
	local pppoe_user
	local pppoe_passwd
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
		json=$(curl -fsSL "https://console.bonuscloud.work/api/bcode/getBcodeForOther/?email=${email}")
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
only_ins_network_vps(){
	ins_docker
	local bcode
	local email
	local image_name
	if ! _only_net_get_image ; then
		return 1
	fi
	if ! read_bcode_input ;then
		echoerr "bcode input error(bcode输入错误)\n"
		return 3
	fi
	docker network create bxc1
	if ! only_net_set_bridge ; then
		return 4
	fi
	only_ins_network_docker_run  "${bcode}" "$email"
}
only_ins_network_choose_plan(){
	echoinfo "choose plan:\n"
	echoinfo "\t1) run as base progress,only one(只运行基础进程,兼容性差,内存低,单开)\n"
	echoinfo "\t2) run openwrt as docker, many (运行在docker里,兼容性好,内存占用高,可多开)\n"
	echoinfo "\t3) run as VPS, only one (VPS专用,只能起一个)\n"
	echoinfo "\t4) Delete the created network (删除创建的网络)\n"
	echoinfo "CHOOSE [1|2|3|4]:"
	read -r  CHOOSE
	case $CHOOSE in
		1 ) only_ins_network_base;;
		2 ) only_ins_network_docker_openwrt ;;
		3 ) only_ins_network_vps ;;
		4 ) only_ins_network_del_net ;;
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
		if docker inspect "bxc-$bcode_">/dev/null 2>&1; then
			echoinfo "container $bcode_ already exists\n"
			continue 
		fi
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
		if docker volume inspect "bxc_data_$bcode" >/dev/null 2>&1 ; then
			echoinfo "certificate $bcode already exists \n"
			continue
		fi
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
	down_git "/aarch64/res/N1_kernel/md5sum" "$TMP/md5sum"
	down_git "/aarch64/res/N1_kernel/System.map-5.0.0-aml-N1-BonusCloud-1-1.xz" "$TMP/System.map-5.0.0-aml-N1-BonusCloud-1-1.xz"
	down_git "/aarch64/res/N1_kernel/vmlinuz-5.0.0-aml-N1-BonusCloud-1-1.xz" "$TMP/vmlinuz-5.0.0-aml-N1-BonusCloud-1-1.xz"
	down_git "/aarch64/res/N1_kernel/modules.tar.xz" "$TMP/modules.tar.xz"
	down_git "/aarch64/res/N1_kernel/N1.dtb" "$TMP/N1.dtb"
	echo "verifty file md5..."
	while read line; do
		file_name=$(echo "${line}" |awk '{print $2}')
		git_md5=$(echo "${line}" |awk '{print $1}')
		local_md5=$(md5sum "$TMP/$file_name"|awk '{print $1}')
		if [[ "$git_md5" != "$local_md5" ]]; then
			down_git "/aarch64/res/N1_kernel/$file_name" "$TMP/$file_name"
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
	IDs=$($CRI ps -a --filter="ancestor=bxc-net:$VDIS" --format "{{.ID}}")
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
		con_info=$($CRI container inspect "$i")
		Status=$(echo "$con_info"|jq -r '.[]|.State.Status')
		if [[ "$Status" != "running" ]]; then
			fail_num=$(($fail_num+1))
			_show_info "$Status" "$fail_num" "$i" "1" "" ""
			continue
		fi
		have_tun0=$($CRI exec -it "$i" /bin/sh -c 'ip addr show dev tun0 >/dev/null 2>&1' 2>/dev/null;echo $?)
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
	network_docker=$(docker images --format "{{.Repository}}" 2>/dev/null|grep -q bxc-net;echo $?)
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
	[[ ${doc_che_ret} -ne 1 ]]&& doc_v=$(docker version --format "{{.Server.Version}}" 2>/dev/null)
	[[ ${doc_che_ret} -ne 1 ]]&& doc_ps_num=$(docker ps 2>/dev/null|wc -l)


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
	[[ -n ${doc_v} ]] &&echoinfo "$doc_v\t\t"
	[[ ${doc_che_ret} -eq 1  ]] || echoinfo "${doc_ps_num}"

	echowarn "\n\nProgress:  "
	lvm_have=$(lvs 2>/dev/null|grep -q 'BonusVolGroup';echo $?)
	[[ ${lvm_have} -eq 0  ]] && { echorun "0";}|| echorun "1"
	echowarn "Available space:  "
	free_space=$(vgdisplay | grep 'Free  PE / Size' | awk '{print $7,$8}' | sed 's/\iB//g')
	echoinfo "${free_space}B\n"
	#任务显示
	declare -A dict
	# 任务类型字典
	dict=([iqiyi]="A" [yunduan]="B" [65542v]="C" [65541v]="D" [65540v]="F" [65546v]="G" [65539v]="H")

	[[ ${lvm_have} -eq 0  ]] &&lvs_info=$(lvs 2>/dev/null|grep BonusVolGroup|grep bonusvol)
	local TYPE lvm_size lvlist lvm_num
	# 修正B任务字典后，将按照首字母倒序改为按第四个字母倒序来避免B任务在A任务前面不符合顺序
	[[ ${lvm_have} -eq 0  ]] &&lvlist=$(echo "$lvs_info"|awk '{print $1}'|sed -r 's#bonusvol([A-Za-z0-9]+)[0-9]{2}#\1#g'|sort -ru -k 1.4)
	[[ ${lvm_have} -eq 0  ]] &&echowarn "\t\t Used\t\t Avail\t\t Use%%\n"
	for lv in $lvlist; do
		TYPE=${dict[$lv]}
		lvm_num=$(echo "$lvs_info"|awk '{print $1}'|grep -c "$lv")
		lvm_size=$(echo "$lvs_info"|grep "$lv"|awk '{print $4}'|head -n 1|sed 's/\.00g//g')
		echoinfo "${TYPE}-${lvm_num}-${lvm_size}\n"
		
		echo -e "$(df -h |grep "bonusvol$lv" | awk '{print "  ├──\t\t", $3, "\t\t", $4, "\t\t\033[1;32m", $5,"\033[0m"}')"
	done
}
show_disk_info(){
	smarttool_ins
	echowarn "Power by: "
	echoinfo "smartctl "
	printf "(https://www.smartmontools.org) & "
	echoinfo "404404 "
	printf "(https://github.com/404404) \n"
	local T1 T2 type
	for sd in $(ls /dev/*|grep -E '((sd)|(vd)|(hd))[a-z]$'); do
		for type_tmp in sat scsi nvme ata usbcypress usbjmicron usbprolific usbsunplus marvell areca 3ware hpt megaraid aacraid cciss; do
			# echo $type_tmp
			ret=$(smartctl -d $type_tmp --all $sd >/dev/null;echo $?)
			# echo $ret
			# ret=$(($ret & 8))
			if [[ $ret -eq 4 || $ret -eq 0 ]]; then
				type=$type_tmp
				break
			fi
		done
		
		echowarn "\nDisk: "
		echoinfo "$sd\t Type: $type\t"
		smarttemp=$(smartctl -d $type -a "$sd" | grep 194)
		T1=$(echo "$smarttemp" | awk '{print $10}')
		T2=$(echo "$smarttemp" | awk '{print $11, $12}')
		echowarn "Temperature: "
		echoinfo "${T1}°C"
		printf " ${T2}\n"
		echowarn "SMART overall-health self-assessment test result: "
		smartctl -d $type -H "$sd" | grep 'SMART overall-health self-assessment test result' | awk '{print $6}'
		echowarn "Hard drive information: \n"
		smartctl -d $type -i "$sd" | sed '1,4d' | sed '$d'
		echowarn "Hard drive smart data: \n"
		smartctl -d $type -A "$sd" | sed '1,4d'
	done

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
		* ) echowarn "Your input is incorrect \n"&& return ;;
	esac
}


displayhelp(){
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
		"     └── -D        Show Disk status and info"
		"    -e             Set interfaces name to ethx,only x86_64 and using grub"
		"    -g             Install network job only"
		"     └── -H        Set ip for container"
		"     └── -M        skip bxc-net docker image download"
		"     └── -e        export only network job certificate"
		"     └── -i        import only network job certificate"
		"     └── -P        only net mode using pppoe in container."
		"     └── -p        use podman start network process container"
		"    -A             Install all task component"
		"    -D             Don't set disk for node program"
		"    -I Interface   set interface name to you want"
		"    -S             show Info level output"
		"    -Z function    run the specified function"
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
		"     └── -D        显示硬盘状态"
		"    -e             设置网卡名称为ethx格式,仅支持使用grub的x86设备"
		"    -g             仅安装网络任务"
		"     └── -H        网络容器指定IP"
		"     └── -M        跳过bxc-net镜像下载"
		"     └── -e        导出单网络任务证书"
		"     └── -i        导入单网络任务证书"
		"     └── -P        单网络任务docker开启pppoe拨号"
		"     └── -p        使用podman安装网络任务"
		"    -A             安装所有计算任务组件"
		"    -D             不初始化外挂硬盘"
		"    -I Interface   指定安装时使用的网卡"
		"    -S             显示Info等级日志"
		"    -Z function    运行指定函数"
		" "
		"不加参数时,默认安装计算任务组件,如加了\"仅安装..\"等参数时将安装对应组件")
	# echo -e "\033[2J"
	case $_LANG in
		en_US.UTF-8|en_us )
			for i in "${!en_us_help[@]}"; do
				help_arr[$i]="${en_us_help[$i]}"
			done 
			;;
		*  )
			for i in "${!zh_cn_help[@]}"; do
				help_arr[$i]="${zh_cn_help[$i]}"
			done
			;;
	esac

	for i in "${!help_arr[@]}"; do
		printf "%s\n" "${help_arr[$i]}"
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
_check_pg

DISPLAYINFO="0"
_LANG=""
_SYSARCH=1
_INIT=0
_NET_CONF=0
_DOCKER_INS=0
_USE_PODMAN=0
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
_SET_PPPOE=0
_NEED_PUBIP=0
#_TEST=0

if [[ $# == 0 ]]; then
	install_all
fi

while  getopts "bdiknrstceghpAI:DSHL:MPEZ:" opt ; do
	case $opt in
		i ) _INIT=1         ;;
		b ) _BOUND=1        ;;
		c ) _CHANGE_KN=1    ;;
		d ) _DOCKER_INS=1   ;;
		p ) _USE_PODMAN=1 ; CRI=podman  ;;
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
		P ) _SET_PPPOE=1    ;;
		E ) _NEED_PUBIP=1   ;;
		Z ) ${OPTARG} ;;
		? ) echoerr "Unknow arg. exiting\n" ;displayhelp; exit 1 ;;
	esac
done
[[ $_SHOW_HELP -eq 1 ]]		&&displayhelp
[[ $_SYSARCH -eq 1 ]]		&&sysArch   &&sys_osname  &&run_as_root "$*"
[[ $_SHOW_STATUS -eq 1 && $_ONLY_NET -eq 1 ]] &&_ONLY_NET=0&& _SHOW_STATUS=0&&only_net_show
[[ $_ONLY_NET -eq 1 && $_SET_ETHX -eq 1 ]]  &&_ONLY_NET=0 && _SET_ETHX=0&&only_net_cert_export
[[ $_ONLY_NET -eq 1 && $_INIT -eq 1 ]]      &&_ONLY_NET=0 && _INIT=0 &&only_net_cert_import
[[ $_DON_SET_DISK -eq 1 && $_SHOW_STATUS -eq 1 ]] &&_SHOW_STATUS=0 && show_disk_info
[[ $_INIT -eq 1 ]]			&&init
[[ $_DOCKER_INS -eq 1 ]]	&&ins_docker
[[ $_USE_PODMAN -eq 1 ]]	&&ins_podman
[[ $_NODE_INS -eq 1 ]]		&&node_ins
[[ $_K8S_INS -eq 1 ]]		&&ins_k8s
[[ $_TELEPORT -eq 1 ]]		&&teleport_ins
[[ $_SYSSTAT -eq 1 ]]		&&iostat_ins
[[ $_CHANGE_KN -eq 1 ]]		&&ins_kernel
[[ $_ONLY_NET -eq 1 ]]		&&only_ins_network_choose_plan
[[ $_NET_CONF -eq 1 ]]		&&ins_conf
[[ $_BOUND -eq 1 ]]			&&bound
[[ $_SET_ETHX -eq 1 ]]		&&set_interfaces_name
[[ $_SHOW_STATUS -eq 1 ]]	&&mg
[[ $_REMOVE -eq 1 ]]		&&remove

sync
