#!/bin/bash
target_ip="$1"
db_name="$2"
datadir="$3"
mysql_socket="$4"
source /home/fubo/workspace/autoDeploy/scripts/svc_profile.sh

if [ `getIp`=="10.40.10.171" ];then
	run_mysql $db_name $datadir $mysql_socket
else
	scp -P52119 -r /home/fubo/workspace/autoDeploy/scripts/svc_db.sh root@$target_ip:/home/
	#$l_db_name $l_datadir $l_mysql_socket  变量是否可用
	ssh -p52119 root@"$target_ip" "source /home/svc_db.sh;run_mysql $db_name $datadir $mysql_socket"
fi


