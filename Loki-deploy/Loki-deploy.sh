#!/bin/bash
#Loki deploy
# wget https://github.com/grafana/loki/releases/download/v2.3.0/logcli-linux-amd64.zip
# wget https://github.com/grafana/loki/releases/download/v2.3.0/loki-canary-linux-amd64.zip

LOKI_IP='54.254.66.115'
IP=$(str=`ip ad|egrep -A 3 "ens|eth0"|egrep "([0-9]{1,3}\.){3}[0-9]{1,3}"|awk -F'/' '{print $1}'`;echo ${str#*inet});echo "本机IP为:$IP";
NAME=$(hostname)

WORK_PATH=`pwd`

Init_Tools(){
echo -e "\033[32m 基础工具包开始安装... \033[0m"
cd $WORK_PATH
# which mysql &>/dev/null;[ $? != 0 ] && { yum -y install mysql; } || { echo "mysql已安装..."; }
# which wget &>/dev/null;[ $? != 0 ] && { yum -y install wget; } || { echo "wget已安装..."; }
which unzip &>/dev/null;[ $? != 0 ] && { yum -y install unzip; } || { echo "unzip已安装..."; }
# which git&>/dev/null;[ $? != 0 ] && { yum -y install git; } || { echo "git已安装..."; }
# node -v &>/dev/null;[ $? != 0 ] && { wget https://nodejs.org/dist/v14.17.5/node-v14.17.5-linux-x64.tar.xz;tar xf node-v14.17.5-linux-x64.tar.xz;mv node-v14.17.5-linux-x64 /usr/local/node;echo 'export PATH="$PATH:/usr/local/node/bin"' >> /etc/profile && source /etc/profile;echo "nodejs安装完成"; }
# go version &>/dev/null;[ $? = 0 ] && { echo "go已安装..."; } || { wget https://golang.org/dl/go1.16.3.linux-amd64.tar.gz;tar xf go*.linux-amd64.tar.gz -C /usr/local/;echo 'export PATH=$PATH:/usr/local/go/bin' >>/etc/profile;source /etc/profile;echo "golang安装完成"; }
# docker -v &>/dev/null;[ $? != 0 ] && { curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh && systemctl enable docker;systemctl start docker; } || { echo "docker已安装..."; }
# docker-compose -v &>/dev/null;[ $? != 0 ] && { curl -L "https://github.com/docker/compose/releases/download/1.29.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose;chmod +x /usr/local/bin/docker-compose;ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose; } || { echo "docker-compose已安装..."; }
# docker-compose -v &>/dev/null;[ $? != 0 ] && { curl -L "https://github.com/docker/compose/releases/download/1.28.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose;chmod +x /usr/local/bin/docker-compose;ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose; } || { echo "docker-compose已安装..."; }
# cat > /etc/docker/daemon.json <<EOF
# {
#   "exec-opts": ["native.cgroupdriver=systemd"],
#   "registry-mirrors": ["https://mirror.gcr.io", "https://tuv7rqqq.mirror.aliyuncs.com", "http://hub-mirror.c.163.com", "https://dockerhub.azk8s.cn", "https://docker.mirrors.ustc.edu.cn", "https://registry.docker-cn.com", "https://mirror.baidubce.com"],
#   "log-driver": "json-file",
#   "log-opts": {
#     "max-size": "100m",
#     "max-file": "10"
#   },
#   "storage-driver": "overlay2"
# }
# EOF
# systemctl daemon-reload
# systemctl restart docker
}



loki_deploy(){
Init_Tools

echo -e "\033[32m 初始化loki用户... \033[0m"
id srv &>/dev/null;[ $? != 0 ] && { groupadd srv;useradd srv -M -g srv -s /sbin/nologin; } || { echo "用户srv已创建"; }
! id loki &>/dev/null && { groupadd loki;useradd loki -g loki -s /sbin/nologin -M; } || { echo "loki用户已存在..."; }

echo -e "\033[32m 初始化目录... \033[0m"
LOKI_PATH='/usr/local/loki'
DATA_PATH='/data/loki'
[ ! -d $LOKI_PATH ] && { mkdir -p $LOKI_PATH; }
[ ! -d $DATA_PATH ] && { mkdir -p $DATA_PATH/{wal,index,trunks,cache,rules,rules-tmp,compactor}; }

echo -e "\033[32m Loki安装... \033[0m"
[ ! -f loki-linux-amd64.zip ] && { wget https://github.com/grafana/loki/releases/download/v2.3.0/loki-linux-amd64.zip; }
unzip loki-linux-amd64.zip -d $LOKI_PATH

echo -e "\033[32m Loki配置更新... \033[0m"
sed -i "s#{{DATA_DIR}}#$DATA_PATH#g" config/loki/*.yaml
\cp -rf config/loki $LOKI_PATH/conf

echo -e "\033[32m Loki目录权限更新... \033[0m"
chown -R loki.loki $LOKI_PATH $DATA_PATH

echo -e "\033[32m Loki服务脚本初始化... \033[0m"
cat >/usr/lib/systemd/system/loki.service<<EOF
[Unit]
Description=Loki service
After=network.target

[Service]
Type=simple
User=loki
Group=loki
ExecStart=$LOKI_PATH/loki-linux-amd64 -config.file $LOKI_PATH/conf/loki-local-config.yaml
SyslogIdentifier=[Loki]

[Install]
WantedBy=multi-user.target
EOF

echo -e "\033[32m Loki服务启动... \033[0m"
systemctl daemon-reload;systemctl enable loki;systemctl start loki;

echo -e "\033[32m Loki服务安装完成... \033[0m"
}

grafana_deploy(){
echo -e "\033[32m 初始化grafana用户... \033[0m"
id srv &>/dev/null;[ $? != 0 ] && { groupadd srv;useradd srv -M -g srv -s /sbin/nologin; } || { echo "用户srv已创建"; }
! id grafana &>/dev/null && { groupadd grafana;useradd grafana -g grafana -s /sbin/nologin -M; } || { echo "grafana用户已存在..."; }

echo -e "\033[32m 初始化目录... \033[0m"
GRAFANA_PATH='/usr/local/grafana'
DATA_PATH='/data/grafana'
LOG_PATH='/data/logs/grafana'
# [ ! -d $GRAFANA_PATH ] && { mkdir -p $GRAFANA_PATH; }
[ ! -d $DATA_PATH ] && { mkdir -p $DATA_PATH; }
[ ! -d $LOG_PATH ] && { mkdir -p $LOG_PATH /var/run/grafana; }

echo -e "\033[32m 安装grafana... \033[0m"
# wget -O grafana.tgz https://github.com/grafana/grafana/archive/refs/tags/v8.1.2.tar.gz
[ ! -f grafana-enterprise-8.1.2.linux-amd64.tar.gz ] && { wget https://dl.grafana.com/enterprise/release/grafana-enterprise-8.1.2.linux-amd64.tar.gz; }
tar xf grafana-*.linux-amd64.tar.gz -C /usr/local/
mv /usr/local/grafana-* $GRAFANA_PATH

echo -e "\033[32m grafana配置文件更新... \033[0m"
sed -i "s#{{GRAFANA_DIR}}#$GRAFANA_PATH#g;s#{{LOG_DIR}}#$LOG_PATH#g;s#{{DATA_DIR}}#$DATA_PATH#g;" config/grafana/*.ini init.d/grafana/*
\cp -rf config/grafana/* $GRAFANA_PATH/conf/
\cp -rf init.d/grafana/grafana.service /lib/systemd/system/grafana.service
\cp init.d/grafana/grafana-log /etc/logrotate.d/grafana

echo -e "\033[32m grafana文件夹权限更新... \033[0m"
chown -R grafana.grafana $GRAFANA_PATH $DATA_PATH $LOG_PATH

echo -e "\033[32m grafana服务启动... \033[0m"
systemctl daemon-reload;systemctl enable grafana;systemctl start grafana;

echo -e "\033[32m grafana服务安装完成... \033[0m"
}

promtail_deploy(){
Init_Tools

echo -e "\033[32m promtail用户初始化... \033[0m"
id srv &>/dev/null;[ $? != 0 ] && { groupadd srv;useradd srv -M -g srv -s /sbin/nologin; } || { echo "用户srv已创建"; }
! id promtail &>/dev/null && { groupadd promtail;useradd promtail -g promtail -G srv -s /sbin/nologin -M; } || { echo "promtail用户已存在..."; }

echo -e "\033[32m 初始化目录... \033[0m"
PROMT_PATH='/usr/local/promtail'
[ ! -d $PROMT_PATH ] && { mkdir -p $PROMT_PATH; }

echo -e "\033[32m 安装promtail... \033[0m"
wget https://github.com/grafana/loki/releases/download/v2.3.0/promtail-linux-amd64.zip
unzip promtail-linux-amd64.zip -d $PROMT_PATH

echo -e "\033[32m promtail配置更新... \033[0m"
sed -i "s/{{LOKI_IP}}/$LOKI_IP/g;s/{{HOSTIP}}/$IP/g;s/{{HOSTNAME}}/$NAME/g;" config/promtail/*.yaml
\cp -rf config/promtail $PROMT_PATH/config

echo -e "\033[32m promtail目录权限更新... \033[0m"
chown -R promtail.promtail $PROMT_PATH

echo -e "\033[32m promtail服务脚本更新... \033[0m"
cat >/usr/lib/systemd/system/promtail.service<<EOF
[Unit]
Description=Promtail service
After=network.target

[Service]
Type=simple
User=promtail
Group=promtail
ExecStart=$PROMT_PATH/promtail-linux-amd64 -config.file $PROMT_PATH/config/promtail-local-config.yaml
SyslogIdentifier=[Promtail]

[Install]
WantedBy=multi-user.target
EOF

echo -e "\033[32m Promtail服务启动... \033[0m"
systemctl daemon-reload;systemctl enable promtail;systemctl start promtail;

echo -e "\033[32m Promtail服务安装完成... \033[0m"
}

manual(){
cat <<EOF
Usage:$0 [l|g|p]
l:Loki
g:Grafana
p:Promtail
EOF
}

case "$1" in
  l)
    loki_deploy
  ;;
  g)
    grafana_deploy
  ;;
  p)
    promtail_deploy
  ;;
  *)
    manual
  ;;
esac
