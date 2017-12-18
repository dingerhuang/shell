#!/bin/bash
WORKSPACE_ROOT=`cat /home/fubo/workspace/autoDeploy/config/commonConfig.cfg|grep "WORKSPACE_ROOT"|awk -F'=' '{print $2}'|sed 's#\r##g'|sed 's#\n##g'`
CONFIG_ROOT=`cat /home/fubo/workspace/autoDeploy/config/commonConfig.cfg|grep "CONFIG_ROOT"|awk -F'=' '{print $2}'|sed 's#\r##g'|sed 's#\n##g'`
LOGS_ROOT=`cat /home/fubo/workspace/autoDeploy/config/commonConfig.cfg|grep "LOGS_ROOT"|awk -F'=' '{print $2}'|sed 's#\r##g'|sed 's#\n##g'`
SCRIPTS_ROOT=`cat /home/fubo/workspace/autoDeploy/config/commonConfig.cfg|grep "SCRIPTS_ROOT"|awk -F'=' '{print $2}'|sed 's#\r##g'|sed 's#\n##g'`
BACKUP_ROOT=`cat /home/fubo/workspace/autoDeploy/config/commonConfig.cfg|grep "BACKUP_ROOT"|awk -F'=' '{print $2}'|sed 's#\r##g'|sed 's#\n##g'`
CODE_ROOT=`cat /home/fubo/workspace/autoDeploy/config/commonConfig.cfg|grep "CODE_ROOT"|awk -F'=' '{print $2}'|sed 's#\r##g'|sed 's#\n##g'`
WAR_PATH=`cat /home/fubo/workspace/autoDeploy/config/commonConfig.cfg|grep "WAR_PATH"|awk -F'=' '{print $2}'|sed 's#\r##g'|sed 's#\n##g'`
TOMCAT_ROOT=`cat /home/fubo/workspace/autoDeploy/config/commonConfig.cfg|grep "TOMCAT_ROOT"|awk -F'=' '{print $2}'|sed 's#\r##g'|sed 's#\n##g'`
PROJECT_ROOT=`cat /home/fubo/workspace/autoDeploy/config/commonConfig.cfg|grep "PROJECT_ROOT"|awk -F'=' '{print $2}'|sed 's#\r##g'|sed 's#\n##g'`
PROJECT_NAME=`echo "$TOMCAT_ROOT"|awk -F'/' '{print $NF}'|awk -F'[_-——]+' '{print $1}'|sed 's#\r##g'|sed 's#\n##g'`
#CODE_BRANCH="$1"
#if  [ ! -n "$CODE_BRANCH" ] ;then
#    echo "分支变量不能为空" && exit 1
#fi
##master分支代码已经手动拉下，后续拉代码无需更新
#备份原来war包

######################log######################
function logging()
{
    local info="$1"
    curday=`date +%Y-%m-%d`
    time=`date '+%Y-%m-%d %H:%M:%S'`
    printf "$time""\t""$info\r\n" >> "$LOGS_ROOT/$curday.log"
}
######################下载分支代码######################
function getBranceCode()
{
    logging "Begin merge code!"
    cd $CODE_ROOTd
    git checkout . && git checkout "$CODE_BRANCH"
    if [ "$?" -ne "0" ];then
        logging "Switch to ""$CODE_BRANCH"" failed!"
    fi
    #merge code
    git pull
    if [ "$?" -ne "0" ];then
        logging "Merge to ""$CODE_BRANCH""failed!"
    fi
}
######################备份原来war包######################
function backupWar()
{
    #备份上次war包
    local l_cur_time=`date '+%Y-%m-%d %H:%M:%S'`
    [ ! -d "${BACKUP_ROOT}" ] && mkdir -p "${BACKUP_ROOT}"
    if [ -d "$BACKUP_ROOT" -a -d "$WAR_PATH" ];then
        sudo mv ${WAR_PATH}/*.war "$BACKUP_ROOT/${PROJECT_NAME}.war"
        cd ${BACKUP_ROOT} && unzip -o ${PROJECT_NAME}.war -d ${PROJECT_NAME}
    fi
    
    return "$?"
}
######################修改配置######################
function modifyConfig()
{
    local l_project_config_root="${CONFIG_ROOT}/${PROJECT_NAME}"
    
    
    [ ! -d "$l_project_config_root" ] && exit 1 && logging "$l_project_config_root did not exist!"
    for each_file in `ls $l_project_config_root -l|grep "^-"|grep -v "commonConfig.cfg"|awk '{print $NF}'`
    do
        find "${BACKUP_ROOT}/${PROJECT_NAME}" -name "$each_file" > /dev/null 2>&1
        if [ "$?" -eq "0" -a `find "${BACKUP_ROOT}/${PROJECT_NAME}" -name "$each_file"|wc -l` -eq "1" ];then
            local l_file_path=`find "${BACKUP_ROOT}/${PROJECT_NAME}" -name "$each_file"`
            for each_line_new in `cat ${l_project_config_root}/$each_file|grep -v "^#"|sed "s#&#\\\\\\\&#g"`
            do
                if [ ! `echo ${each_file}|awk -F'.' '{print $NF}'` == "xml" ];then
                    local l_key=`echo "$each_line_new"|awk -F'=' '{print $1}'|sed s/[[:space:]]//g`"="
                else
                    local l_key=`echo "$each_line_new"|awk -F'>' '{print $1}'|sed s/[[:space:]]//g`
                fi
                
                if [ `cat "$l_file_path"|grep -v "^#"|sed s/[[:space:]]//g|grep "^${l_key}"` ];then
                    local l_each_line_old=`cat "$l_file_path"|grep -v "^#"|sed s/[[:space:]]//g|grep "^${l_key}"`
                    sed -i "s#$l_each_line_old#$each_line_new#g" "$l_file_path" && logging "Replace ${l_key} sucess!"
                else
                    logging "${l_key} did not find in $l_file_path" && exit 1
                fi
            done
        else
            logging "$each_file did not exist!" && exit 1
        fi
    done

    return "$?"
}
######################package######################
function packageUserCenter()
{
    logging "Begin backup package!"
    #local l_time=`date '+%Y-%m-%d %H:%M:%S'`
    logging "Begin package!"
    cd $CODE_ROOT
    mvn clean install -Dmaven.test.skip=true  -Pqa  -U
    if [ "$?" -ne "0" ];then
        #检查war包是否存在
        if [ -f "$WAR_PATH/*.WAR" ];then
            logging "End package!"
        else
            logging "Package failed!" && exit 1
        fi
    fi
    if [ -d "$BACKUP_ROOT" -a -d "$WAR_PATH" ];then
        mv ${WAR_PATH}/*.war "$BACKUP_ROOT/${PROJECT_NAME}.war" -f
        cd ${BACKUP_ROOT} && unzip -o ${PROJECT_NAME}.war -d ${PROJECT_NAME}
    fi
    
    cd -
    
    return "$?"
}

######################停服务######################
function stopProject()
{

    if [ -d "$TOMCAT_ROOT" ];then
        cd $TOMCAT_ROOT
        l_processCount=`ps -ef |grep "$PROJECT_NAME"|grep -v "grep"|awk '{print $2}'|wc -l`
        if [ "$l_processCount" -lt "1" ];then
            logging "$PROJECT_NAME"" did not starting!" && return "0"
        elif [ "$l_processCount" -eq "1" ];then
            l_process_num=`ps -ef |grep "$PROJECT_NAME"|grep -v "grep"|awk '{print $2}'`
            [ "$?" -eq "0" -a -n $"l_process_num" ] && kill -9 "$l_process_num"
            [ "$?" -eq "0" ] && logging "$PROJECT_NAME"" is stopped!"
        else
            for each_process_num in `ps -ef |grep "$PROJECT_NAME"|grep -v "grep"|awk '{print $2}'`
            do
                [ "$?" -eq "0" -a -n $"each_process_num" ] && kill -9 "$each_process_num"
            done
            logging "$PROJECT_NAME"" is stopped!"
        fi
    else
        return 0
    fi
    
    return "$?"
}

######################检查状态######################
function checkStatus()
{
    i="1"
    ip=`geIp`
    port=`getPort`
    while [ "$i" -lt "61" ]
    do
        > /tmp/telnet.log
        telnet "$ip" "$port" > /tmp/telnet.log << EOF
        sucess
EOF
        cat /tmp/telnet.log | grep "Escape character"  > /dev/null 2>&1
        if [ "$?" -ne "0"];then
            continue
        else
            echo "sucess"
        fi
        sleep 1
        i=`expr $i + 1`
    done
    
    return "$?"
}

######################获取IP######################
function getIp()
{
    ip=`ifconfig | sed -n '2p'|awk -F "[: ]+" '{print $4}'`
    echo "$ip"
    
    return "$?"
}

######################获取tomcat端口######################
function getPort()
{
    [ -f "$TOMCAT_ROOT/conf/server.xml" ] && port=`cat "$TOMCAT_ROOT/conf/server.xml"|grep "<Connector"|grep "URIEncoding"|awk -F'"' '{print $2}'`
    echo "$port"
    
    return "$?"
}
######################install######################
function installUserCenter()
{
    logging "Begin install!"
    logging "Begin stop peoject!"
    #停程序
    ssh -p端口号 ip地址 "source /etc/profile;ps -ef|grep ${PROJECT_NAME}|grep -v 'grep'|awk '{print \$2}'|xargs -i kill -9 {}"
    #删除目录
    ssh -p端口号 ip地址 "source /etc/profile;[ -d ${PROJECT_ROOT} ] && rm -rf /home/fubo/userCenter_tomcat/webapps/${PROJECT_NAME}/*"
    #备份日志
    #部署程序
    scp -P 端口号 -r ${BACKUP_ROOT}/${PROJECT_NAME}/* root@ip地址:${TOMCAT_ROOT}/"webapps/""$PROJECT_NAME"
    #启动程序
    #startProject
    ssh -p端口号 ip地址 "source /etc/profile;sh ${TOMCAT_ROOT}/bin/startup.sh"
    
    return "$?"
}
######################起服务######################
function startProject()
{
    logging "Starting $PROJECT_NAME ......"
    if [ -d "$TOMCAT_ROOT/""bin/" ];then
        cd "$TOMCAT_ROOT/bin" && sh ./startup.sh
    fi
    if [ "$?" -eq "0" ];then
        local l_flag=`checkStatus`
        if [ "$l_flag" == "sucess" ];then
            logging "$PROJECT_NAME started!" && return 0
        else
            logging "Failed to start $PROJECT_NAME" && exit 1
        fi
    fi

    return "$?"
}
######################部署######################
function deploy()
{
    packageUserCenter
    modifyConfig
    #package
    installUserCenter
    
    return "$?"
}

