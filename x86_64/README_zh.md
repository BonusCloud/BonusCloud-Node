### 安装
在Shell里运行
```
wget https://raw.githubusercontent.com/BonusCloud/BonusCloud-Node/master/x86_64/install.sh -O install.sh&&sudo bash install.sh
```
### 卸载/清除
```
wget https://raw.githubusercontent.com/BonusCloud/BonusCloud-Node/master/x86_64/install.sh -O install.sh&&sudo bash install.sh -r
```

以下系统通过测试
- ubuntu-18.04.02 4.15.0-45-generic [下载](https://www.ubuntu.com/download/server)
- debian-9.9 4.9.168-1 (2019-04-12) [下载](https://www.debian.org/distrib/)

### 绑定
```
curl -H "Content-Type: application/json" -d '{"bcode":"xxxx-xxxxxxxx","email":"xxxx@xxxx"}' http://localhost:9017/bound
```
或者用APP [下载](https://console.bonuscloud.io/download)

### 命令行选项

    -h             打印帮助并退出
    -i             初始化安装环境
    -k             安装k8s及其组件依赖
    -n             安装node管理程序(绑定等操作需要用)
    -r             重置k8s并删除所有已安装程序
    -s             安装salt-minion管理程序
    -t             显示进程安装运行情况
    -e             设置网络接口名称为ethx格式
    -g             仅安装网络任务程序
    -I Interface   指定网卡
    -S             不显示Info等级日志
