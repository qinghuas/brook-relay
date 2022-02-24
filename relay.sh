#!/bin/bash

conf='/root/relay.conf'
method='brook'
delay='0'

green_color='\033[32m'
yellow_color='\033[33m'
color_end='\033[0m'

green()
{
    echo -e "\033[32m[info]\033[0m"
}

red()
{
    echo -e "\033[31m[warn]\033[0m"
}

yellow()
{
    echo -e "\033[33m[note]\033[0m"
}

blue()
{
    echo -e "\033[34m[input]\033[0m"
}

public()
{
    brook_download_url='https://github.com.cnpmjs.org/txthinking/brook/releases/download/v20210701/brook_linux_amd64'
    update_source='https://cdn.jsdelivr.net/gh/qinghuas/brook-relay@main/relay.sh'
}

private()
{
    brook_download_url=''
    update_source=''
}

public
#private

command()
{
    if [[ ! -e "/usr/bin/nslookup" ]];then
        apt-get -y install dnsutils
    fi
    if [[ ! -e "/usr/bin/curl" ]];then
        apt-get -y install curl
    fi
    if [[ ! -e "/usr/bin/screen" ]];then
        apt-get -y install screen
    fi
    if [[ ! -e "/usr/bin/nload" ]];then
        apt-get -y install nload
    fi
    if [[ ! -e "/usr/bin/column" ]];then
        apt-get -y install bsdmainutils
    fi
    if [[ ! -e "/usr/bin/socat" ]];then
        apt-get -y install socat
    fi
    if [[ ! -e "/usr/bin/brook" ]];then
        wget -O /usr/bin/brook ${brook_download_url}
        chmod 755 /usr/bin/brook
    fi
    if [[ ! -e "/usr/bin/relay" ]];then
        echo "#!/bin/bash" > /usr/bin/relay
        echo "bash /root/relay.sh \$1 \$2" >> /usr/bin/relay
        chmod 755 /usr/bin/relay
    fi
    # crontab
    crontab -l | grep "relay.sh" > /dev/null
    if [[ $? != "0" ]];then
        crontab -l > /root/crontab.now
        echo "*/3 * * * * /bin/bash /root/relay.sh auto" >> /root/crontab.now
        crontab /root/crontab.now
        rm -rf /root/crontab.now
    fi
}

checkConfig()
{
    if [[ -e ${conf} ]];then
        line=$(wc -l ${conf} | awk '{print $1}')

        for (( i=1; i <= ${line}; i++ ))
        do
            getConfig
            if [[ $(cat ${conf} | awk '{print $1}' | grep -w ${local_port} | wc -l) -gt "1" ]];then
                echo -e "$(red) The configuration file exists on the same port."
                echo -e "$(red) Related ports: ${local_port}"
                exit
            fi
        done
    fi
}

checkStart()
{
    if [[ ! -e ${conf} ]];then
        echo -e "$(red) The configuration file was not found. Execute [relay add] to add rule."
        exit
    fi

    file_line=$(wc -l ${conf} | awk '{print $1}')
    if [[ ${file_line} == "0" ]];then
        echo -e "$(red) There is no valid forwarding rule, execute [relay add] to add rule."
        exit
    fi

    screen -ls | grep "relay_" > /dev/null
    if [[ $? == "0" ]];then
        echo "$(yellow) There is a forwarding running. Execute [relay stop] to stop them, or [relay restart] to rerun."
        exit
    fi
}

getIp()
{
    parameter=$1
    echo ${parameter} | perl -ne 'exit 1 unless /\b(?:(?:(?:[01]?\d{1,2}|2[0-4]\d|25[0-5])\.){3}(?:[01]?\d{1,2}|2[0-4]\d|25[0-5]))\b/'
    if [[ $? == "0" ]];then
        remote_target=${parameter}
    else
        remote_target=$(nslookup ${parameter} | grep Address | cut -d " " -f 2 | grep -v Address | sed -n 1p)
    fi
}

getIpApi()
{
    parameter=$1
    echo ${parameter} | perl -ne 'exit 1 unless /\b(?:(?:(?:[01]?\d{1,2}|2[0-4]\d|25[0-5])\.){3}(?:[01]?\d{1,2}|2[0-4]\d|25[0-5]))\b/'
    if [[ $? == "0" ]];then
        nslookup_remote_target=${parameter}
    else
        nslookup_remote_target=$(nslookup ${parameter} | grep Address | cut -d " " -f 2 | grep -v Address | sed -n 1p)
    fi

    echo "${parameter} ${nslookup_remote_target}"
}

getConfig()
{
    local_port=$(sed -n ${i}p ${conf} | awk '{print $1}')
    remote_host=$(sed -n ${i}p ${conf} | awk '{print $2}')
    remote_port=$(sed -n ${i}p ${conf} | awk '{print $3}')
    enable_switch=$(sed -n ${i}p ${conf} | awk '{print $4}')
}

submitTask()
{
    screen_name="relay_${local_port}"
    echo "$(date +%s) relay_${local_port} ${remote_host} ${remote_target} ${remote_port}" >> /root/.relay.log

    screen -ls | grep ${screen_name} > /dev/null
    is_exist=$?

    if [[ ${is_exist} != "0" ]];then
        # create screen
        screen -dmS ${screen_name}
        sleep ${delay}
        # send command
        if [[ ${method} == 'brook' ]];then
            screen -x -S ${screen_name} -p 0 -X stuff "brook relay -f :${local_port} -t ${remote_target}:${remote_port}"
        fi
        sleep ${delay}
        if [[ ${method} == 'socat' ]];then
            screen -x -S ${screen_name} -p 0 -X stuff "socat -d TCP4-LISTEN:${local_port},reuseaddr,fork TCP4:${remote_target}:${remote_port}"
        fi
        # excute command
        sleep ${delay}
        screen -x -S ${screen_name} -p 0 -X stuff $'\n'
    fi
}

createTask()
{
    line=$(wc -l ${conf} | awk '{print $1}')
    for (( i=1; i <= ${line}; i++ ))
    do
        getConfig
        getIp ${remote_host}
        if [[ ${enable_switch} == "1" ]];then
            if [[ ${remote_target} != "" ]];then
                echo "(${i}/${line}) ${local_port} -> ${remote_target}:${remote_port}"
                submitTask
            else
                echo "(${i}/${line}) Failed to resolve domain name -> ${remote_host}"
            fi
        else
            echo "(${i}/${line}) Skips disabled forwarding rules -> ${remote_host}"
        fi
    done

    echo -e "$(green) The transfer task has been created."
}

checkStop()
{
    screen -ls | grep "relay_" > /dev/null
    if [[ $? == "1" ]];then
        echo -e "$(yellow) There are no transit tasks running."
        exit
    fi
}

stopTask()
{
    pid=$(screen -ls | grep "relay_" | awk -F '.' '{print $1}' | tr "." "\n")

    for screen_id in $pid
    do
        screen -S ${screen_id} -X quit
    done

    echo -e "$(red) All transfer tasks have been terminated."
}

getStatus()
{
    relay_task_num=$(screen -ls | grep "relay_" | wc -l)
    screen -ls | grep "relay_"
    echo -e "$(green) Total running transit tasks: ${relay_task_num}"
}

setDelay()
{
    execution_delay=${parameter_2}
    sed -i "5c delay=\'${execution_delay}\'" /root/relay.sh
    echo -e "$(green) The execution waiting time has been set to -> ${execution_delay}s"
}

intelligent()
{
    createCache()
    {
        echo -e "$(green) Creating relay rule domain name resolution cache..."
        rm -rf /root/.relay.nslookup.cache

        counter='0'
        line=$(wc -l ${conf} | awk '{print $1}')
        for (( i=1; i <= ${line}; i++ ))
        do
            getConfig
            getIpApi ${remote_host} >> /root/.relay.nslookup.cache &
        done
    }
    getIpFromCache()
    {
        target=$1
        result=$(cat /root/.relay.nslookup.cache | grep -w ${target} | sed -n 1p | awk '{print $2}')
        echo ${result}
    }

    remove()
    {
        counter='0'
        conf_port=$(cat ${conf} | awk '{print $1}' | sed ":a;N;s/\n/ /g;ta")
        task_port=$(screen -ls | grep "relay_" | awk '{print $1}' | awk -F "." '{print $2}' | sed 's#relay_##g' | sed ":a;N;s/\n/ /g;ta")

        for screen_port in $task_port
        do
            echo ${conf_port} | grep -w ${screen_port} > /dev/null
            if [[ $? == "1" ]];then
                screen_id=$(screen -ls | grep -w "relay_${screen_port}" | awk '{print $1}' | awk -F "." '{print $1}')
                if [[ ${screen_id} != "" ]];then
                    counter=$(expr ${counter} + 1)
                    screen -S ${screen_id} -X quit
                    echo -e "$(red) Terminate forwarding task -> relay_${screen_port}"
                fi
            fi
        done

        if [[ ${counter} == "0" ]];then
            echo -e "$(green) There are no tasks to terminate."
        fi
    }
    new()
    {
        counter='0'
        relay_conf_port=$(cat ${conf} | awk '{print $1}' | sed ":a;N;s/\n/ /g;ta")
        for conf_port in $relay_conf_port
        do
            conf_line=$(cat -n ${conf} | awk '{print $1,$2}' | grep -w ${conf_port} | awk '{print $1}')
            local_port=$(sed -n ${conf_line}p ${conf} | awk '{print $1}')
            remote_host=$(sed -n ${conf_line}p ${conf} | awk '{print $2}')
            remote_port=$(sed -n ${conf_line}p ${conf} | awk '{print $3}')
            enable_switch=$(sed -n ${conf_line}p ${conf} | awk '{print $4}')

            screen -ls | grep "relay_${conf_port}" > /dev/null
            if [[ $? == "1" ]] && [[ ${enable_switch} == "1" ]];then
                counter=$(expr ${counter} + 1)
                local_port=${conf_port}
                submitTask
                echo -e "$(green) New task has been created -> relay_${local_port}"
            fi
        done

        if [[ ${counter} == "0" ]];then
            echo -e "$(green) There are no new tasks to create."
        fi
    }
    change()
    {
        counter='0'
        line=$(wc -l ${conf} | awk '{print $1}')
        for (( i=1; i <= ${line}; i++ ))
        do
            getConfig
            remote_target=$(getIpFromCache ${remote_host})

            history=$(tac /root/.relay.log | grep relay_${local_port} | grep -m 1 ${remote_host})
            history_target=$(echo ${history} | awk '{print $4}')
            history_port=$(echo ${history} | awk '{print $5}')

            if [[ ${remote_target} != ${history_target} ]] || [[ ${remote_port} != ${history_port} ]] && [[ ${enable_switch} == "1" ]];
            then
                if [[ ${remote_target} != "" ]] && [[ ${history_target} != "" ]] && [[ ${history_port} != "" ]];then
                    counter=$(expr ${counter} + 1)
                    screen_id=$(screen -ls | grep "relay_${local_port}" | awk -F '.' '{print $1}' | tr "." "\n")
                    screen -S ${screen_id} -X quit

                    content="[${remote_host}] ${history_target}:${history_port} -> ${remote_target}:${remote_port}"
                    echo -e "$(red) ${content}"
                    echo "$(date "+%Y-%m-%d %H:%M:%S") ${content}" >> /root/.relay.terminate.log

                    echo -e "$(yellow) relay_${local_port} has been terminated, waiting to be recreated."
                fi
            fi
        done

        if [[ ${counter} != "0" ]];then
            bash /root/relay.sh auto new
        else
            echo -e "$(green) Great! No tasks need to be changed."
        fi
    }

    if [[ ${parameter_2} == "new" ]];then
        new
    else
        createCache
        remove
        new
        change
    fi
}

update()
{
    wget -O /root/relay.remote.sh -q ${update_source}
    current=$(md5sum /root/relay.sh | awk '{print $1}')
    remote=$(md5sum /root/relay.remote.sh | awk '{print $1}')

    if [[ ${remote} == "" ]];then
        echo "$(red) Failed to get file from remote server."
        exit
    fi

    if [[ ${current} != ${remote} ]];then
        rm -rf /root/relay.sh
        mv /root/relay.remote.sh /root/relay.sh
        chmod 755 /root/relay.sh
        echo -e "$(green) The version has been synchronized with the remote server."
    else
        echo -e "$(green) It is the latest version."
    fi

    rm -rf /root/relay.remote.sh
}

uninstall()
{
    read -p "$(blue) This will remove all related files, Do you really want to uninstall? [y/n]:" reply
    if [[ ${reply} == "y" ]];then
        relay stop
        rm -rf /usr/bin/relay /usr/bin/brook /root/relay.sh
        rm -rf /root/.relay.log /root/.relay.nslookup.cache /root/.relay.terminate.log
        echo -e "$(green) All related files have been removed. Please remove the cron task manually."
        echo -e "$(green) If necessary, delete the file /root/relay.conf manually."
    fi
}

list()
{
    cat ${conf} | column -s ' ' -t
}

add()
{
    if [[ -e ${conf} ]];then
        line=$(wc -l ${conf} | awk '{print $1}')
        last_port=$(sed -n ${line}p ${conf} | awk '{print $1}')
        echo "$(green) The last port in the configuration file is: ${last_port}"
    fi

    read -p "$(blue) Please enter the local port:" local_port
    read -p "$(blue) Please enter the remote host:" remote_host
    read -p "$(blue) Please enter the remote port:" remote_port

    if [[ ${local_port} != "" ]] && [[ ${remote_host} != "" ]] && [[ ${remote_port} != "" ]];then
        echo "${local_port} ${remote_host} ${remote_port} 1" >> ${conf}
        echo "$(green) Added successfully, wait for restart to take effect..."
        sleep 1
        bash /root/relay.sh auto
    else
        echo "$(red) The necessary parameters are missing."
    fi
}

del()
{
    cat -n ${conf} | column -s ' ' -t
    echo;read -p "$(blue) Please enter the realy rule number:" line_number
    if [[ ${line_number} == "" ]];then
        echo -e "$(red) Input can not be empty."
        exit
    else
        echo -e "$(green) The rule has been removed and the service is being processed..."
        sed -i "${line}d" ${conf}
        bash /root/relay.sh auto
    fi
}

edit()
{
    vim ${conf}
    bash /root/relay.sh auto
}

search_config()
{
    port=$1

    relay list | grep ${port}
    relay status | grep ${port}
}

help()
{
    echo -e "${green_color}"
    echo -e "bash relay.sh {start|stop|restart} - service management"
    echo -e "bash relay.sh delay <time> - set create delay"
    echo -e "${color_end}"
    echo
    echo -e "${yellow_color}"
    echo -e "version -> 1.2.11"
    echo -e "release date -> 2022-02-24"
    echo -e "${color_end}"
}

switchMethod()
{
    echo -e "$(green) The method you are using is: ${yellow_color}${method}${color_end}"
    echo -e "$(green) Which of the following do you want to use:"
    read -p "$(blue) [1]brook [2]realm [3]socat:" reply
    if [[ ${reply} == '' ]];then
        echo -e "$(red) The selection cannot be empty, please enter the method name."
        exit
    fi
    if [[ ${reply} != 'brook' ]] && [[ ${reply} != 'socat' ]];then
        echo -e "$(red) Please enter the choice given."
        exit
    fi
    if [[ ${reply} == ${method} ]];then
        echo -e "$(green) You are using this way."
        exit
    fi
    sed -i "4c method=\'${reply}\'" /root/relay.sh

    echo -e "$(green) The mode change is complete."
    bash relay.sh restart
}

view_log()
{
    tail -n 15 /root/.relay.terminate.log
}

# 1.2.1 配置文件存在复用同一端口的情况时给出提示
# 1.2.2 开源项目
# 1.2.3 编辑配置文件后自动检测变动
# 1.2.4 个人配置
# 1.2.5 增加运行检测用于避免重复执行
# 1.2.6 移除运行检测，改为在创建screen任务时检测
# 1.2.7 增加配置搜索功能
# 1.2.8 (2022-02-13) 增加解析缓存功能
# 1.2.9 (2022-02-15) 修复可能频繁存在的错误终止问题
# 1.2.10 (2022-02-17) 增加socat中转方式
# 1.2.11 (2022-02-24) 优化结构

command
parameter_1=$1
parameter_2=$2

case "${parameter_1}" in
    start)
        checkConfig
        checkStart
        createTask;;
    stop)
        checkConfig
        checkStop
        stopTask;;
    restart)
        checkConfig
        checkStop
        stopTask
        createTask;;
    status)
        getStatus;;
    delay)
        setDelay;;
    auto)
        checkConfig
        intelligent;;
    update)
        update;;
    uninstall)
        uninstall;;
    switch)
        switchMethod;;
    list)
        list;;
    add)
        add;;
    del)
        del;;
    edit)
        edit;;
    search)
        search_config ${parameter_2};;
    log)
        view_log;;
    *)
        help;;
esac
