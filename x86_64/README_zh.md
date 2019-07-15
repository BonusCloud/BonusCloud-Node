### 安装
在Shell里运行
```
wget https://raw.githubusercontent.com/qinghon/BonusCloud-Node/master/x86_64/install.sh -O install.sh&&sudo bash install.sh
```
### 卸载/清除
```
wget https://raw.githubusercontent.com/qinghon/BonusCloud-Node/master/x86_64/install.sh -O install.sh&&sudo bash install.sh -r
```

以下系统通过测试
- ubuntu-18.04.02 4.15.0-45-generic [下载](https://www.ubuntu.com/download/server)
- debian-9.9 4.9.168-1 (2019-04-12) [下载](https://www.debian.org/distrib/)

### 绑定
```
curl -H "Content-Type: application/json" -d '{"bcode":"xxxx-xxxxxxxx","email":"xxxx@xxxx"}' http://localhost:9017/bound
```
或者用APP [下载](https://console.bonuscloud.io/download)
或者使用命令行选项
```bash
bash install.sh -b
```

### 命令行选项
```bash
bash install.sh [选项] 
    -h             打印此帮助并退出
     └── -L        指定帮助语言,如"-h -L zh_cn" 
    -b             命令行绑定
    -d             仅安装Docker程序
    -c             安装定制内核,仅支持"Phicomm N1"
    -i             仅初始化
    -k             仅安装k8s组件
    -n             安装node组件
    -r             清除所有安装的相关程序
    -s             仅安装teleport远程调试程序,默认安装
    -t             显示各组件运行状态
    -e             设置网卡名称为ethx格式,仅支持使用grub的x86设备
    -g             仅安装网络任务
     └── -H        网络容器指定IP
    -D             不初始化外挂硬盘
    -I Interface   指定安装时使用的网卡
    -S             显示Info等级日志
 
不加参数时,默认安装计算任务组件,如加了"仅安装.."等参数时将安装对应组件
```
