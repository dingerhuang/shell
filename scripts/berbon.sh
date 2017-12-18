#!/bin/bash

RED='\E[1;31m'
RES='\E[0m'
export javaHome=`which java`
######################获取程序路劲######################
function getBerbonPath()
{
    local l_berbonPath=`pwd`
    
    echo $l_berbonPath
    
    return "$?"
}

######################打印程序日志######################
function berbonLog()
{
    local l_logLine="$1"
    [ -z "$l_logLine" ] && l_logLine=""
    local l_berbonPath=`getBerbonPath`
    local l_logPath=`find $l_berbonPath -name "log*" -type d`
    local l_logName=`ls -lt "$l_logPath"/*.log|sed -n 1p|awk -F' ' '{print $NF}'`
    
    tail -"$l_logLine"f "$l_logName"
    
    return "0"
}

######################获取程序状态######################
function berbonStatus()
{
    local l_berbonPath=`getBerbonPath`
    
    cd $l_berbonPath
    #local l_berbonJarName=`ls -lt *.jar|sed -n 1p|awk -F' ' '{print $8}'|awk -F[-,-,_,,.] '{print $1}'`
    local l_berbonJarName=`ls -lt *.jar|sed -n 1p|awk -F' ' '{print $8}'`
    local l_jarStartCount=`ps -ef |grep $l_berbonJarName |grep -v grep|wc -l`
    local l_starttime=`ps -ef |grep $l_berbonJarName |grep -v grep|awk -F' ' '{print $5}'`
    showBerbonStatus "$l_jarStartCount" "$l_starttime"
    
    return "$?"
}

######################打印程序状态######################
function showBerbonStatus()
{
    local l_berbonStatus="$1"
    local l_starttime="$2"
    
    case $l_berbonStatus in
    0)
        echo "JarStatus is Stopped";;
    1)
        echo "JarStatus is Running"" since ""$l_starttime";;
    *)
        echo "The program is running at least twice";;
    esac

    return "$?"
}

######################后台启动程序######################
function berbonStart()
{
    local l_berbonStatus=`berbonStatus`
    local l_berbonPath=`getBerbonPath`
    
    cd $l_berbonPath
    local l_berbonJarName=`ls -lt *.jar|sed -n 1p|awk -F' ' '{print $8}'`
    local l_berbonStatusFlag=`echo "$l_berbonStatus"|awk -F' ' '{print $NF}'`
    if [ "$l_berbonStatusFlag" = "Stopped" ];then
        nohup $javaHome -jar $l_berbonJarName > /dev/null 2>&1 &
        [ "$?" -ne "0" ] && echo "Start program failed!"
    elif [ "$l_berbonStatusFlag" = "Running" ];then
        local l_jarStartCount=`ps -ef |grep $l_berbonJarName |grep -v grep|wc -l`
        if [ "$l_jarStartCount" -eq "1" ];then
            echo "JarStatus is Running!" && return 0
        else
            berbonStop && berbonStart && return 0
        fi
    else
        berbonStop && berbonStart && return 0
    fi
    
    [ "$?" -eq "0" ] && echo "Now the program is running!"
    
    return "$?"
}

######################前台启动程序######################
function berbonStartpro()
{
    local l_berbonStatus=`berbonStatus`
    local l_berbonPath=`getBerbonPath`
    
    cd $l_berbonPath
    local l_berbonJarName=`ls -lt *.jar|sed -n 1p|awk -F' ' '{print $8}'`
    local l_berbonStatusFlag=`echo "$l_berbonStatus"|awk -F' ' '{print $NF}'`
    if [ "$l_berbonStatusFlag" = "Stopped" ];then
        $javaHome -jar $l_berbonJarName
        [ "$?" -ne "0" ] && echo "Start program failed!"
    elif [ "$l_berbonStatusFlag" = "Running" ];then
        local l_jarStartCount=`ps -ef |grep $l_berbonJarName |grep -v grep|wc -l`
        if [ "$l_jarStartCount" -eq "1" ];then
            echo "JarStatus is Running!" && return 0
        else
            berbonStop && berbonStartpro
        fi
    else
        berbonStop && berbonStartpro
    fi
    
    [ "$?" -eq "0" ] && echo "Now the program is stopped!"
    
    return "$?"
}

######################停止所有程序######################
function berbonStop()
{
    local l_berbonPath=`getBerbonPath`
    cd $l_berbonPath
    local l_berbonJarName=`ls -lt *.jar|sed -n 1p|awk -F' ' '{print $8}'|awk -F[-,-,_,,.] '{print $1}'`
    local l_jarStartCount=`ps -ef |grep $l_berbonJarName |grep -v grep|wc -l`
        
    if [ "$l_jarStartCount" -eq "0" ];then
        echo "JarStatus is Stopped!"
    else
        ps -ef |grep $l_berbonJarName |grep -v grep|
        while read eachprocess
        do
            local l_processId=`echo $eachprocess|awk -F' ' '{print $2}'`
            [ -n "$l_processId" ] && sudo kill -9 $l_processId
        done
    fi
    
    [ "$?" -eq "0" ] && echo "Now the program is stopped!"
    
    return "$?"
}

######################重新启动程序######################
function berbonRestart()
{
    berbonStop
    berbonStart
    
    [ "$?" -eq "0" ] && echo "Now the program is restart!"
    
    return "$?"
}

######################入口函数######################
function berbon()
{
    local berbonParameter="$1"
    
    case $berbonParameter in
    -h)
        echo -e "${RED}[berbon -h]${RES}"
        echo "ex:berbon -h"
        echo
  echo -e "${RED}[berbon -log]${RES}"
        echo "ex1:berbon -log or berbonLog,which means tail -f ***.log"
        echo "ex2:berbon -log 100 or berbonLog 100,which means tail -100f ***.log"
        echo
  echo -e "${RED}[berbon -status]${RES}"
        echo "ex:berbon -status or berbonStatus,which means ps -ef|grep ***.jar"
        echo
  echo -e "${RED}[berbon -start]${RES}"
        echo "ex:berbon -start or berbonStart,which means nohup java -jar ***.jar &"
        echo
  echo -e "${RED}[berbon -startpro]${RES}"
        echo "ex:berbon -startpro or berbonStartpro,which means Start the program foreground"
        echo
  echo -e "${RED}[berbon -stop]${RES}"
        echo "ex:berbon -stop or berbonStop,which means stop the program background"
        echo
  echo -e "${RED}[berbon -restart]${RES}"
        echo "ex:berbon -restart or berbonRestart,which means Restart the program";;
    -log)
        berbonLog;;
    -start)
        berbonStart;;
    -startpro)
        berbonStartpro;;
    -stop)
        berbonStop;;
    -status)
        berbonStatus;;
    -restart)
        berbonRestart;;
    *)
        echo "please ininput berbon -h for help!"
    esac
    
    return "$?"
}
