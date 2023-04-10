#!/bin/bash

export LANG="zh_CN.UTF-8"
#--------------------------------
#
#业务服务监控
#author: hai
#data  : 2023-04-03
#
#--------------------------------
servPath=/data
date_time=`date +"%Y-%m-%d %H:%M"`
day_curr=`date +"%Y%m%d"`
p_name=葡京站点
printFile=$servPath/monitor/$day_curr/monitor-service.log
mkdir -p $servPath/monitor/$day_curr


	
ini_check(){
	servs_name=(eureka
				gateway
				nacos
				xxl-job-admin
				backend
				games
				jobs
				pay
				web
				im
				)
	for sname in ${servs_name[@]}
	do
		serv_name=$sname
		serv_file_name=""
	
        if [[ $serv_name == "eureka" ]]; then 	
			serv_file_name=video-eureka-2.2.5.RELEASE.jar	
			
		elif [[ $serv_name == "gateway" ]]; then 	
			serv_file_name=video-gateway-2.2.5.RELEASE.jar

		elif [[ $serv_name == "nacos" ]]; then 	
			serv_file_name=nacos-server-2.2.1

		elif [[ $serv_name == "xxl-job-admin" ]]; then 	
			serv_file_name=xxl-job-admin-2.4.0-SNAPSHOT.jar
			
		elif [[ $serv_name == "backend" ]]; then 	
			serv_file_name=video-backend-0.0.1-SNAPSHOT.jar
			
		elif [[ $serv_name == "games" ]]; then 	
			serv_file_name=video-games-0.0.1-SNAPSHOT.jar	

		elif [[ $serv_name == "jobs" ]]; then	
			serv_file_name=video-jobs-0.0.1-SNAPSHOT.jar	

		elif [[ $serv_name == "pay" ]]; then 	
			serv_file_name=pay-0.0.1-SNAPSHOT.jar		

		elif [[ $serv_name == "web" ]]; then  	
			serv_file_name=video-web-0.0.1-SNAPSHOT.jar			
									
		elif [[ $serv_name == "im" ]]; then			
			serv_file_name=video-im-0.0.1-SNAPSHOT.jar

		else
		   echo -e  "\e[32m $serv_name 未匹配 \e[0m"   >> ${printFile}  
		fi
     	echo " 参数：serv_name：$serv_name;serv_file_name:$serv_file_name"  		

		docheck $serv_name
	done
}

docheck(){
    serv_name=$1

    echo "docheck 函数接收 参数：serv_name：$serv_name"   >> ${printFile} 

    echo "-----------$serv_name服务检测开始----------"   >> ${printFile} 
	if [[ $serv_name == "nacos" ]]; then
		pid=$(netstat -tpln | grep 8848 | awk ' {print $7}' | awk -F/ '{print $1}')
		if [ ! -n "$pid" ]; then
		    echo  -e  "\e[31m $serv_name  was downed.\e[0m"   >> ${printFile} 
			a_c="$date_time $p_name $serv_name  was downed!!!"
			alarm_push "$a_c"
		else
		    echo  -e  "\e[32m $serv_name  is running.\e[0m"   >> ${printFile} 
			a_c="$date_time   $p_name $serv_name  is running."
			#alarm_push "$a_c"
        fi
		
	elif [[ $serv_name == "im" ]]; then
		#http端口 8600  8085 8084
		http_pid=$(netstat -tpln | grep 8600 | awk ' {print $7}' | awk -F/ '{print $1}')
		if [ ! -n "$http_pid" ]; then
		    echo  -e  "\e[31m $serv_name http port is not listening.\e[0m"    >> ${printFile}
		else
		    echo  -e  "\e[32m $serv_name http port is  listening.\e[0m"   >> ${printFile}
		fi
		ws_pid=$(netstat -tpln | grep 8085 | awk ' {print $7}' | awk -F/ '{print $1}')
		if [ ! -n "$ws_pid" ]; then
		    echo   -e  "\e[31m $serv_name  websocket port is not listening.\e[0m"    >> ${printFile}
		else
		    echo  -e  "\e[32m  $serv_name websocket port is  listening. \e[0m"    >> ${printFile}
		fi
		tcp_pid=$(netstat -tpln | grep 8084 | awk ' {print $7}' | awk -F/ '{print $1}')
		if [ ! -n "$tcp_pid" ]; then
		    echo  -e  "\e[31m $serv_name  tcp port is not listening.\e[0m"   >> ${printFile}
		else
		    echo  -e  "\e[32m $serv_name tcp port is  listening.\e[0m"   >> ${printFile}
		fi	
        if [[ -z "$http_pid" ]] || [[ -z "$ws_pid" ]] || [[ -z "$tcp_pid" ]]; then
			echo  -e  "\e[31m $serv_name  was  downed!!! \e[0m"   >> ${printFile} 
		    a_c="$date_time  $p_name $serv_name  was downed!!!"
			alarm_push "$a_c"
		else
		    echo  -e  "\e[32m $serv_name  is running.\e[0m"   >> ${printFile} 		
		fi
	else
		pid=$(ps -aux | grep $serv_name | grep -v grep| awk '{print $2}')
		if [ ! -n "$pid" ]; then
			echo  -e  "\e[31m $serv_name  was  downed!!! \e[0m"   >> ${printFile} 
			a_c="$date_time  $p_name $serv_name  was downed!!!"
			alarm_push "$a_c"
		else
			for i in  $pid
			do
			   echo   -e  "\e[32m $serv_name's is  running .It's pid $i \e[0m"   >> ${printFile} 
			done
			a_c="$date_time  $p_name $serv_name  is running."
			#alarm_push "$a_c"
		fi	
	fi

	echo "-----------$serv_name服务检测结束----------"   >> ${printFile} 
}

alarm_push(){

    alarm_content=$1
    bot_name=v_alarm_bot
	TOKEN=6004854749:AAHRCyaVPesHbNb0zMEo3KXqBO_miFsfuY0	#TG机器人token
	chat_ID=5662318517		#用户ID或频道、群ID
	message_text="【v_alarm】 $alarm_content"		#要发送的信息
	MODE='HTML'		#解析模式，可选HTML或Markdown
	URL="https://api.telegram.org/bot${TOKEN}/sendMessage"		#api接口
	echo   -e  "\e[36m bot推送内容：$alarm_content $i \e[0m"   >> ${printFile} 
	curl -s -X POST $URL -d chat_id=${chat_ID}  -d parse_mode=${MODE} -d text="${message_text}" 
}
		 
start(){
    serv_name=("${!1}")
    serv_file_name=("${!2}")
    echo "start 函数接收 参数：serv_name：$serv_name;serv_file_name:$serv_file_name"   >> ${printFile} 

    echo "-----------$serv_name服务检测开始----------"   >> ${printFile} 

    pid=$(ps -ef | grep $serv_name | grep -v grep | cut -c 9-15 )
    if [ ! -n "$pid" ]; then
		echo "$serv_name 已停止."   >> ${printFile} 
    else
		for i in  $pid
		do
		   kill -9 $i
		   echo "$serv_name's $i was killd."   >> ${printFile} 
		done
    fi
	ps -aux | grep $serv_name | grep -v grep| awk '{print $2}' | xargs kill -s 9
	echo "-----------$serv_name服务检测结束----------"   >> ${printFile} 
	echo "-----------准备启动$serv_name服务----------"   >> ${printFile} 
    # 在后台启动 eureka服务：
    nohup java  -Xms1024m -Xmx2024m  -jar /data/service/$serv_name/$serv_file_name   >/data/service/logs/$serv_name.log 2>&1 &
　　　　  
　　  echo "-----------完成启动$serv_name服务------------"   >> ${printFile} 
}

ini_check
#case $1 in

#start):
#  start
#;;

#stop):
#　  echo "--------------------stop...-------------------"
#;;
#esac

#xit 0
