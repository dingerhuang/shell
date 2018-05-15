#!/bin/bash
target_ip="$1"
source /home/fubo/workspace/autoDeploy/scripts/svc_profile.sh

if [ `getIp`=="10.40.10.171" ];then
	run
else
	scp -P52119 -r /home/fubo/workspace/autoDeploy/scripts/svc_db.sh root@$target_ip:/home/
	ssh -p52119 root@"$target_ip" "source /home/svc_db.sh;run"
fi


