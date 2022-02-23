#!/bin/bash

write_log()
{
    timestamp=$(date '+%d-%m-%YT%H:%M:%S %Z')
    Level=$1
    FunctionName=$2
    Message=$3
    echo $timestamp '||' $Level '||' $FunctionName '||' $Message | tee -a ${log_file}
}

# check what version of python the user has
python_prereq_check()
{
    # check python
    write_log 'INFO' 'python_prereq_check' 'Checking Python version and module'
    PYTHON=""
    PY_VERSION=""

    if [ -x "$(command -v python2)" ]; then
        PYTHON="python2"

        # check if Python 2.6 or newer
        PY_VERSION=$((python2 --version) 2>&1)
        case $PY_VERSION in
            "Python 2.6"* | "Python 2.7"* )
                ;;
            * )
                write_log 'WARN' 'python_prereq_check' "Python version $PY_VERSION is not supported by most tools, please install python 2.6 or newer"
                return 1
                ;;
        esac

    elif [ -x "$(command -v python3)" ]; then
        PYTHON="python3"
        PY_VERSION=$((python3 --version) 2>&1)

    else
        write_log 'WARN' 'python_prereq_check' "No version of Python found on machine, please install python 2.6 or newer"
        return 1
    fi


    # check python packages
    success=0
    temp_pkgs="copy errno os platform re socket ssl subprocess"
    if [ $PYTHON = "python2" ]; then
        pkgs="$temp_pkgs urllib2"
        # add the urllib2 for 2
    else
        pkgs="$temp_pkgs urllib.request"
        # add the urllib.request for 3
    fi
    
    for pkg in $pkgs; do
        $PYTHON -c "import $pkg" 1> /dev/null 2> /dev/null
        if [ $? -ne 0 ]; then
            write_log 'WARN' 'python_prereq_check' "Python package '$pkg' not installed, please install python 2.6 or newer"
            success=1
        fi
    done
    
    return $success
}

isArc()
{
    imds1=$(curl "http://169.254.169.254/metadata/instance/compute?api-version=2021-02-01" -f -s -H "Metadata: true" --connect-timeout 1)
    imds2=$(curl "http://168.63.129.16/metadata/instance/compute?api-version=2021-02-01" -f -s -H "Metadata: true" --connect-timeout 1)
    if [[ -z $imds1 && -z $imds2 ]]; then
        write_log 'INFO' 'isArc' 'This is Arc server, will collect Arc GC logs'
        arc=1
    else
        write_log 'INFO' 'isArc' 'This is Azure VM, will collect Azure VM GC logs'
        arc=0
    fi
}

CollectExtensionLogs()
{
    extfolder=/var/lib/waagent/Microsoft.GuestConfiguration.ConfigurationforLinux-*
    cmd=`ls /var/lib/waagent | grep -i Microsoft.GuestConfiguration.ConfigurationforLinux`
    if [ -z "$cmd" ];then
        write_log 'WARN' 'CollectExtensionLogs' "Guest configuration extension installer folder does not exist. Path: $extfolder"
    else
        write_log 'INFO' 'CollectExtensionLogs' 'Collecting guest configuration installer logs'
        mkdir -p ./$output_path/config
        cp $extfolder/status/* ./$output_path/config
        cp $extfolder/config/* ./$output_path/config
    fi    

    agentlog=/var/log/waagent.log
    cmd=`ls /var/log | grep -i waagent.log`
    if [ -z "$cmd" ];then
        write_log 'WARN' 'CollectExtensionLogs' "Guest agent log does not exist. Path: $agentlog"
    else
        write_log 'INFO' 'CollectExtensionLogs' 'Collecting guest agent logs'
        cp $agentlog ./$output_path/
    fi

    gcfolder=/var/log/azure
    cmd=`ls /var/log/azure | grep -i guest`
    if [ -z "$cmd" ];then
        write_log 'WARN' 'CollectExtensionLogs' "Guest configuration extension folder does not exist under $gcfolder"
    else
        write_log 'INFO' 'CollectExtensionLogs' 'Collecting guest configuration extension logs'
        mkdir -p ./$output_path/guestconfig
        cp $gcfolder/Microsoft.GuestConfiguration.ConfigurationforLinux/*.log ./$output_path/guestconfig
        cp $gcfolder/guest-configuration/*.log ./$output_path/guestconfig
    fi 

    workerlog=/var/lib/GuestConfig/gc_agent_logs
    cmd=`ls /var/lib | grep -i GuestConfig`
    if [ -z "$cmd" ];then
        write_log 'WARN' 'CollectExtensionLogs' "Guest configuration worker folder does not exist under $workerlog"
    else
        write_log 'INFO' 'CollectExtensionLogs' 'Collecting guest configuration worker logs'
        mkdir -p ./$output_path/gc_agent_logs
        cp -R $workerlog/* ./$output_path/gc_agent_logs
    fi 
}

CollectArcGCLogs()
{
    arcagent=/var/opt/azcmagent
    cmd=`ls /var/opt | grep -i azcmagent`
    if [ -z "$cmd" ];then
        write_log 'WARN' 'CollectExtensionLogs' "Arc agent log does not exist under $arcagent"
    else
        write_log 'INFO' 'CollectExtensionLogs' 'Collecting arc agent logs'
        cp $arcagent/log/himds.log ./$output_path/
        cp $arcagent/log/azcmagent.log ./$output_path/
        cp $arcagent/agentconfig.json ./$output_path/
    fi

    extlog=/var/lib/GuestConfig
    cmd=`ls /var/lib | grep -i guest`
    if [ -z "$cmd" ];then
        write_log 'WARN' 'CollectExtensionLogs' "Guest configuration extension folder does not exist under $extlog"
    else
        write_log 'INFO' 'CollectExtensionLogs' 'Collecting guest configuration extension logs'
        mkdir -p ./$output_path/arc_policy_logs
        mkdir -p ./$output_path/gc_agent_logs
        mkdir -p ./$output_path/ext_mgr_logs
        cp -R $extlog/arc_policy_logs/* ./$output_path/arc_policy_logs
        cp -R $extlog/gc_agent_logs/* ./$output_path/gc_agent_logs
        cp -R $extlog/ext_mgr_logs/* ./$output_path/ext_mgr_logs
    fi 
}

CheckLogsForErrors()
{
    cmd=`grep -Ri error ./$output_path/* > ./$output_path/error.log`
    if [ -s ./$output_path/error.log ]; then
        write_log 'WARN' 'CheckLogsForErrors' "Found errors in logs, stored all error messages under path: /$output_path/error.log"
    else
        write_log 'INFO' 'CheckLogsForErrors' 'There is not error message found'
    fi
}

ArchiveLogs()
{
    write_log 'INFO' 'ArchiveLogs' 'Data collection completed'

    #analysis error in logs
    write_log 'INFO' 'ArchiveLogs' 'Analyzing collected logs for errors'
    CheckLogsForErrors

    tar -czf $output_path.tgz ./$output_path

    write_log 'INFO' 'ArchiveLogs' "Collected logs available at: /tmp/$output_path.tgz"

    rm -rf ./$output_path
}

#main
cd /tmp

if [[ -n $1 ]]; then
	output_path=$1
else
    output_path="GCLogCollector.$(date +%s).`hostname`"
fi
mkdir -p ./$output_path

log_file=./$output_path/Tool.log

echo '=================================================' | tee -a ${log_file}
echo 'Tool log data is being redirecting to /tmp/'$output_path | tee -a ${log_file}

# check python
python_prereq_check

arc=0
isArc
if [ $arc -eq 1 ]; then
    CollectArcGCLogs
else
    CollectExtensionLogs
fi

ArchiveLogs
