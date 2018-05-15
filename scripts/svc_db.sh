#!/bin/bash
#检查文件目录是否存在

ROOT_DUMP_PATH="/home/oracle/dumpfile"
ROOT_MYSQL_PATH="/home/mysql/dumpfile"
function checkDumpfilePath()
{
	if [ ! -d $ROOT_DUMP_PATH ];then
		echo "dumpfile path did not exist!"
		mkdir -p $ROOT_DUMP_PATH
		#chown -R oracle:oinstall $ROOT_DUMP_PATH
	fi
}
function checkMysqlFilePath()
{
	if [ ! -d $ROOT_MYSQL_PATH ];then
		echo "dumpfile path did not exist!"
		mkdir -p $ROOT_MYSQL_PATH
	fi
}

#拷贝文件到本地目录并解压
function copyDumpfile(){
	#清空文件夹
	[ -d $ROOT_DUMP_PATH ] && rm -rf $ROOT_DUMP_PATH/*
	l_file_name=`getDumpFileName`
	scp -P52119 root@10.40.10.174:/home/yuanjianqiang/$l_file_name $ROOT_DUMP_PATH
	cd $ROOT_DUMP_PATH && tar -zxvf $l_file_name
	
	return "$?"
}
#拷贝mysql文件
function copyMysqlFile(){

	local l_db_name="$1"
	#清空文件夹
	[ -d $ROOT_MYSQL_PATH ] && rm -rf $ROOT_MYSQL_PATH/*
	l_file_name=`getMysqlFileName $l_db_name`
	scp -P52119 root@10.40.10.174:/home/yuanjianqiang/$l_file_name $ROOT_MYSQL_PATH
	cd $ROOT_MYSQL_PATH && tar -xvf $l_file_name
	
	return "$?"
}

#执行dump文件
function execDumpfile(){
	
	dumpfileName=`find /home/oracle/dumpfile -name pcl*.dmp|awk '{print $NF}'`
	su - oracle
	sqlplus "/as sysdba" << EOF
	create or replace directory dpdata1 as '/home/oracle/dumpfile';
	select * from dba_directories;
	grant read,write on directory dpdata1 to pcl;
	exit
EOF
	impdp  pcl/oo11220099oojjggrr55@"pcl" directory=dpdata1 dumpfile=$dumpfileName TABLE_EXISTS_ACTION=replace SCHEMAS=PCL
	
}
#执行mysql文件
function execMysqlFile(){

	local l_datadir="$1"
	local l_mysql_socket="$2"
	local l_mysqlFileName=`find $ROOT_MYSQL_PATH -name datacleaned_restore.sh|awk '{print $NF}'`
	sed -i 's#datadir="/data/mysqldata"#$l_datadir#g' $l_mysqlFileName
	sed -i 's#mysql_socket="/data/mysqldata/mysql.sock"#$l_mysql_socket#g' $l_mysqlFileName
	
	sh -x $l_mysqlFileName
	
	return "$?"
	
}
#获取dumpfile文件名
function getDumpFileName(){
    
    local l_file_name=`ssh -p52119 root@10.40.10.174 "ls /home/yuanjianqiang/pcl_201*.dmp.tar.gz -lt|sed -n 1p"|awk -F'/' '{print $NF}'`
	
	if [ "$l_file_name"=="" ];then
		echo "未获取到包名"
	fi
    
    echo $l_file_name
    
    return "$?"
}
#获取mysql文件名
function getMysqlFileName(){
	local l_db_name="$1"
	local l_file_name=`ssh -p52119 root@10.40.10.174 "ls /home/yuanjianqiang/$l_db_name*lasted.tar -lt|sed -n 1p"|awk -F'/' '{print $NF}'`
	if [ "$l_file_name"=="" ];then
		echo "未获取到包名"
	fi
	
	echo $l_file_name
	
	return "$?"
}


######################获取IP######################
function getIp()
{
    ip=`ifconfig | sed -n '2p'|awk -F "[: ]+" '{print $4}'`
    echo "$ip"

    return "$?"
}
####开始倒库########
function run(){
	#检查文件目录是否存在
	checkDumpfilePath
	#拷贝文件到本地目录
	copyDumpfile 
	#执行dump文件
	execDumpfile
}
#####开始导入mysql库####
function run_mysql(){
	local l_db_name="$1"
	local l_datadir="$2"
	local l_mysql_socket="$3"
	#检查文件目录是否存在
	checkMysqlFilePath
	#拷贝文件到本地目录
	copyMysqlFile "$l_db_name"
	#执行mysql文件
	execMysqlFile "$l_datadir" "$l_mysql_socket"
}
