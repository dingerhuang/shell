#!/bin/bash
project_name="$1"
cur_path=$(cd `dirname $0`; pwd)
config_root="${cur_path}/../config/${project_name}"
if [ -f "$config_root/commonConfig.cfg" ];then
    cp "$config_root/commonConfig.cfg" "${cur_path}/../config" -r -f
fi
source /home/fubo/workspace/autoDeploy/scripts/svc_profile.sh

function run()
{
    set -x
    
    deploy
    
    set +x
    
    return "$?"
}

run
