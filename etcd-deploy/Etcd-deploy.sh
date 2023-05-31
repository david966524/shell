#!/bin/bash
#deploy etcd

ver='3.5.0'

IP=$(str=`ip ad|egrep -A 3 "ens|eth0"|egrep "([0-9]{1,3}\.){3}[0-9]{1,3}"|awk -F'/' '{print $1}'`;echo ${str#*inet});echo "本机IP为:$IP";

echo -e "\033[32m 初始化目录... \033[0m"
mkdir -p /data/etcd/{wal,data} /data/logs/etcd
chmod -R 700 /data/etcd
echo -e "\033[32m 下载安装包... \033[0m"
[ ! -f etcd-v$ver-linux-amd64.tar.gz ] && { wget https://github.com/etcd-io/etcd/releases/download/v$ver/etcd-v$ver-linux-amd64.tar.gz; } || { echo "etcd-v$ver-linux-amd64.tar.gz已存在"; }
echo -e "\033[32m 解压缩压缩包... \033[0m"
tar xf etcd-v$ver-linux-amd64.tar.gz
echo -e "\033[32m 移动到指定服务目录... \033[0m"
mv etcd-v$ver-linux-amd64 /usr/local/etcd
ln -s /usr/local/etcd/etcdctl /usr/bin/
echo -e "\033[32m 初始化配置文件... \033[0m"
cp etcd.conf.yml /usr/local/etcd/
sed -i "s/{{IP}}/$IP/g" /usr/local/etcd/etcd.conf.yml
echo -e "\033[32m 初始化服务脚本... \033[0m"
cat > /lib/systemd/system/etcd.service <<EOF
[Unit]
Description=Etcd Service
#描述服务类别，表示本服务需要在network服务启动后在启动
# After=network.target syslog.target
After=network.target

[Service]
#表示后台运行模式
# Type=forking
#设置服务运行的用户
# User=user
#设置服务运行的用户组
# Group=user
#定义systemd如何停止服务
KillMode=control-group
#存放PID的绝对路径
PIDFile=/var/run/etcd.pid
#设置进程的环境变量， 值是一个空格分隔的 VAR=VALUE 列表。 可以多次使用此选项以增加新的变量或者修改已有的变量 (同一个变量以最后一次的设置为准)。 若设为空， 则表示清空先前所有已设置的变量。
# Environment=OPTS="" PROFILE=""
#与Environment= 类似， 不同之处在于此选项是从文本文件中读取环境变量的设置。 文件中的空行以及以分号(;)或井号(#)开头的行会被忽略，从文件中读取的环境变量会覆盖 Environment= 中设置的同名变量。 文件的读取顺序就是它们出现在单元文件中的顺序， 并且对于同一个变量，以最后读取的文件中的设置为准。
# EnvironmentFile=/data/service/%i/.env
#%i是实例名称,对于实例化的服务，这是指 @和后缀之间的部分
# WorkingDirectory=/data/service/%i
WorkingDirectory=/data/etcd/
PermissionsStartOnly=true
#服务启动命令，命令需要绝对路径
ExecStart=/usr/local/etcd/etcd --config-file=/usr/local/etcd/etcd.conf.yml
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=/bin/kill -s QUIT \$MAINPID
SuccessExitStatus=0 143
#表示给服务分配独立的临时空间
PrivateTmp=true
LimitNOFILE=1000000
LimitNPROC=100000
# TimeoutStartSec=infinity
# TimeoutStopSec=infinity
TimeoutStopSec=0
#定义服务进程退出后，systemd的重启方式，默认是不重启
Restart=on-failure
RestartSec=30
#标准日志输出追加到指定位置,systemd2.36版本以上
StandardOutput=append:/data/logs/etcd/etcd.log
#标准错误输出追加到指定位置,systemd2.36版本以上
StandardError=append:/data/logs/etcd/etcd.err
#日志写入系统日志标识
SyslogIdentifier=[Etcd]
# StandardOutput=syslog
# StandardError=syslog

[Install]
#多用户
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable etcd
systemctl start etcd
[ $? = 0 ] && { echo -e "\033[32m 服务安装启动成功... \033[0m"; } || { echo -e "\033[31m 服务安装启动失败... \033[0m"; }

cat <<EOF
#etcd常用命令
#一个完整的查询前缀<包含了证书访问>
ENDPOINTS=$HOST_1:2379,$HOST_2:2379,$HOST_3:2379
alias etctl='ETCDCTL_API=3 etcdctl --endpoints=$ENDPOINTS --cacert=<ca-file> --cert=<cert-file> --key=<key-file>'
etctl COMMAND
#查看版本号
etcdctl version

#增删改查
##增:
  etcdctl --endpoints=$ENDPOINTS put KEY "VALUE"
##查:
  etcdctl --endpoints=$ENDPOINTS get KEY #
  etcdctl --endpoints=$ENDPOINTS --write-out="json" get KEY #写入到json文件
  etcdctl --endpoints=$ENDPOINTS get KEY --prefix #基于相同KEY前缀来查
  etcdctl --endpoints=$ENDPOINTS get / --prefix --keys-only #列出所有KEY
##删:
  etcdctl --endpoints=$ENDPOINTS del KEY
  etcdctl --endpoints=$ENDPOINTS del KEY --prefix #删除所有以这个KEY作前缀的

#集群状态
etcdctl --write-out=table --endpoints=$ENDPOINTS endpoint status
etcdctl --endpoints=$ENDPOINTS endpoint health

#集群成员
etcdctl --endpoints=$ENDPOINTS member list -w table #表的方式列出集群成员

#
EOF