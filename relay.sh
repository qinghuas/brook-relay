#!/bin/bash

conf='/root/relay.conf'
delay='0'

green()
{
	echo -e "\033[32m[info]\033[0m"
}

red()
{
	echo -e "\033[31m[warning]\033[0m"
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
	if [[ ! -e "/usr/bin/brook" ]];then
		wget -O /usr/bin/brook "$brook_download_url"
		chmod 755 /usr/bin/brook
	fi
	if [[ ! -e "/usr/bin/relay" ]];then
		echo '#!/bin/bash' > /usr/bin/relay
		echo 'bash /root/relay.sh $1 $2' >> /usr/bin/relay
		chmod 755 /usr/bin/relay
	fi
	# crontab
	crontab -l | grep "relay.sh" > /dev/null
	if [[ "$?" != "0" ]];then
		crontab -l > /root/crontab.now
		echo "*/3 * * * * /bin/bash /root/relay.sh auto" >> /root/crontab.now
		crontab /root/crontab.now
		rm -rf /root/crontab.now
	fi
}

checkConfig()
{
    if [[ -e "$conf" ]];then
        line=$(wc -l ${conf} | awk '{print $1}')
        
        for (( i=1; i <= $line; i++ ))
        do
            getConfig
            if [[ $(cat ${conf} | awk '{print $1}' | grep $local_port | wc -l) -gt "1" ]];then
                echo -e "$(red) The configuration file has the problem of occupying the same port."
                echo -e "$(red) Related ports: ${local_port}"
                exit
            fi
        done
    fi
}

checkStart()
{
	if [[ ! -e "$conf" ]];then
		echo -e "$(red) The configuration file was not found. Execute [relay add] to add one."
		exit
	fi
	if [[ "$(wc -l ${conf} | awk '{print $1}')" = "0" ]];then
		echo -e "$(red) There is no valid forwarding rule, please check ${conf}."
		exit
	fi
	screen -ls | grep "relay_" > /dev/null
	if [[ "$?" = "0" ]];then
		echo "$(yellow) There is a forwarding running. Execute [relay stop] to stop them, or [relay restart] to rerun."
		exit
	fi
}

getIp()
{
	parameter=$1
	echo "$parameter" | perl -ne 'exit 1 unless /\b(?:(?:(?:[01]?\d{1,2}|2[0-4]\d|25[0-5])\.){3}(?:[01]?\d{1,2}|2[0-4]\d|25[0-5]))\b/'
	if [[ "$?" = "0" ]];then
		remote_target=$parameter
	else
		remote_target=$(nslookup $parameter | grep Address | cut -d " " -f 2 | grep  -v Address)
	fi
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
	echo "$(date +%s) relay_${local_port} $remote_host $remote_target $remote_port" >> /root/.relay.log
	
	screen -ls | grep $screen_name > /dev/null
	is_exist=$?
	
	if [[ "$delay" = "0" ]] && [[ "$is_exist" != "0" ]];then
		screen -dmS "${screen_name}"
		screen -x -S "${screen_name}" -p 0 -X stuff "brook relay -f :${local_port} -t ${remote_target}:${remote_port}"
		screen -x -S "${screen_name}" -p 0 -X stuff $'\n'
	fi
	
	if [[ "$delay" != "0" ]] && [[ "$is_exist" != "0" ]];then
		screen -dmS "${screen_name}"
		sleep $delay
		screen -x -S "${screen_name}" -p 0 -X stuff "brook relay -f :${local_port} -t ${remote_target}:${remote_port}"
		sleep $delay
		screen -x -S "${screen_name}" -p 0 -X stuff $'\n'
		sleep $delay
	fi
}

createTask()
{
	line=$(wc -l ${conf} | awk '{print $1}')
	for (( i=1; i <= $line; i++ ))
	do
		getConfig
		getIp $remote_host
		if [[ "$enable_switch" = "1" ]];then
			if [[ "$remote_target" != "" ]];then
				echo "(${i}/${line}) ${local_port} -> ${remote_target}:${remote_port}"
				submitTask
			else
				echo "(${i}/${line}) Failed to resolve domain name -> ${remote_host}"
			fi
		else
			echo "(${i}/${line}) Skip task -> ${remote_host}"
		fi
	done
	
	echo -e "$(green) The transfer task has been created."
}

checkStop()
{
	screen -ls | grep "relay_" > /dev/null
	if [[ "$?" = "1" ]];then
		echo -e "$(yellow) There are no transit tasks running."
		exit
	fi
}

stopTask()
{
	pid=$(screen -ls | grep "relay_" | awk -F '.' '{print $1}' | tr "." "\n")

	for screen_id in $pid
	do
		screen -S $screen_id -X quit
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
	execution_delay="$parameter_2"
	sed -i "4c delay=\'${execution_delay}\'" /root/relay.sh
	echo -e "$(green) The execution waiting time has been set to -> ${execution_delay}s"
}

intelligent()
{
	remove()
	{
		counter='0'
		conf_port=$(cat ${conf} | awk '{print $1}' | sed ":a;N;s/\n/ /g;ta")
		task_port=($(screen -ls | grep "relay_" | awk '{print $1}' | awk -F "." '{print $2}' | sed 's#relay_##g' | sed ":a;N;s/\n/ /g;ta"))
		task_port_number="${#task_port[@]}"
		
		for (( i=0; i < $task_port_number; i++ ))
		do
			screen_port="${task_port[${i}]}"
			echo $conf_port | grep -w $screen_port > /dev/null
			if [[ "$?" = "1" ]];then
				counter=$(expr $counter + 1)
				screen_id=$(screen -ls | grep "relay_${screen_port}" | awk '{print $1}' | awk -F "." '{print $1}')
				screen -S $screen_id -X quit
				echo -e "$(red) Terminate forwarding task -> relay_${screen_port}"
			fi
		done
		
		if [[ "$counter" = "0" ]];then
			echo -e "$(green) There are no tasks to terminate."
		fi
	}
	new()
	{
		counter='0'
		conf_port=$(cat ${conf} | awk '{print $1}' | sed ":a;N;s/\n/ /g;ta")
		conf_port_array=($(cat ${conf} | awk '{print $1}' | sed ":a;N;s/\n/ /g;ta"))
		conf_port_array_number="${#conf_port_array[@]}"
		for (( i=0; i < $conf_port_array_number; i++ ))
		do
			conf_port="${conf_port_array[${i}]}"
			conf_line=$(cat -n ${conf} | awk '{print $1,$2}' | grep -w ${conf_port} | awk '{print $1}')
			local_port=$(sed -n ${conf_line}p ${conf} | awk '{print $1}')
			remote_host=$(sed -n ${conf_line}p ${conf} | awk '{print $2}')
			remote_port=$(sed -n ${conf_line}p ${conf} | awk '{print $3}')
			enable_switch=$(sed -n ${conf_line}p ${conf} | awk '{print $4}')
			
			getIp $remote_host
			
			screen -ls | grep "relay_${conf_port}" > /dev/null
			if [[ "$?" = "1" ]] && [[ "$enable_switch" = "1" ]];then
				counter=$(expr $counter + 1)
				local_port="$conf_port"
				submitTask
				echo -e "$(green) New task has been created -> relay_${local_port}"
			fi
		done
		
		if [[ "$counter" = "0" ]];then
			echo -e "$(green) There are no new tasks to create."
		fi
	}
	change()
	{
		counter='0'
		line=$(wc -l ${conf} | awk '{print $1}')
		for (( i=1; i <= $line; i++ ))
		do
			getConfig
			getIp $remote_host
			history_target=$(tac /root/.relay.log | grep relay_${local_port} | grep -m 1 $remote_host | awk '{print $4}')
			history_port=$(tac /root/.relay.log | grep relay_${local_port} | grep -m 1 $remote_host | awk '{print $5}')

			if [[ "$remote_target" != "$history_target" ]] || [[ "$remote_port" != "$history_port" ]] && [[ "$enable_switch" = "1" ]];then
				counter=$(expr $counter + 1)
				screen_id=$(screen -ls | grep "relay_${local_port}" | awk -F '.' '{print $1}' | tr "." "\n")
				screen -S $screen_id -X quit
				echo -e "$(yellow) relay_${local_port} has been terminated, waiting to be recreated."
			fi
		done
		
		if [[ "$counter" != "0" ]];then
			bash /root/relay.sh auto new
		else
			echo -e "$(green) Great! No tasks need to be changed."
		fi
	}
	
	if [[ "$parameter_2" = "new" ]];then
		new
	else
		# auto check
		remove
		new
		change
	fi
}

update()
{
	wget -O /root/relay.remote.sh -q "$update_source"
	current=$(md5sum /root/relay.sh | awk '{print $1}')
	remote=$(md5sum /root/relay.remote.sh | awk '{print $1}')
	
	if [[ "$remote" = "" ]];then
		echo "$(red) Failed to get file from remote server."
		exit
	fi
	if [[ "$current" != "$remote" ]];then
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
	if [[ "$reply" = "y" ]];then
		relay stop
		rm -rf /usr/bin/relay /usr/bin/brook /root/relay.sh /root/.relay.log
		echo -e "$(green) All related files have been removed. Please remove the cron task manually."
		echo -e "$(green) If necessary, delete the file /root/relay.conf manually."
	fi
}

list()
{
	cat $conf | column -s ' ' -t
}

add()
{
	if [[ -e "$conf" ]];then
		line=$(wc -l ${conf} | awk '{print $1}')
		last_port=$(sed -n ${line}p ${conf} | awk '{print $1}')
		echo "$(green) The last port in the configuration file is: ${last_port}"
	fi
	
	enable_switch='1'
	read -p "$(blue) Please enter the local port:" local_port
	read -p "$(blue) Please enter the remote host:" remote_host
	read -p "$(blue) Please enter the remote port:" remote_port
	
	if [[ "$local_port" != "" ]] && [[ "$remote_host" != "" ]] && [[ "$remote_port" != "" ]];then
		echo "${local_port} ${remote_host} ${remote_port} ${enable_switch}" >> ${conf}
		echo "$(green) Added successfully, wait for restart to take effect..."
		sleep 1
		bash /root/relay.sh auto
	else
		echo "$(red) The necessary parameters are missing."
	fi
}

del()
{
    cat -n $conf | column -s ' ' -t
    echo;read -p "$(blue) Please enter the realy rule number:" line_number
    if [[ "$line_number" = "" ]];then
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

help()
{
	echo 'bash relay.sh {start|stop|restart} - Service management'
	echo 'bash relay.sh delay $time - Set creation delay'
	echo;echo 'version -> 1.2.6'
	echo 'release date -> 2021-12-01'
}

# 1.2.1 配置文件存在复用同一端口的情况时给出提示
# 1.2.2 开源项目
# 1.2.3 编辑配置文件后自动检测变动
# 1.2.4 私人配置
# 1.2.5 增加运行检测用于避免重复执行
# 1.2.6 移除运行检测，改为在创建screen任务时检测

command
parameter_1=$1
parameter_2=$2

case "$parameter_1" in
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
	list)
		list;;
	add)
		add;;
	del)
		del;;
	edit)
		edit;;
	*)
		help;;
esac
