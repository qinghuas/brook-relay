# brook-relay
可能是东半球最好用的 brook 中转管理脚本

# 优点

+ 干净。代码简洁，便于二次开发
+ 轻量。功能实现仅需 400 余行代码
+ 易用。对于 debian/ubuntu 用户来说，会自动配置运行所需的各项组件
+ 贴心。对于性能较差的 nat 服务器，在连续创建多条任务时，可能出错。可设置执行延时规避
+ 灵活。借助 screen 命令，在需要终止（配置文件中移除了某条规则时）或重启（ddns 域名解析 ip 发生变动时）某一中转任务时，不会影响其他任务

# 缺点
+ 不支持 centos
+ 不支持流量统计
+ 成为一个保姆级脚本并不是本项目的目标。请自行处理中转机上的 iptables / firewall / ufw 规则

# 使用
## 安装
```
wget "https://cdn.jsdelivr.net/gh/qinghuas/brook-relay@main/relay.sh"
bash relay.sh start
```
+ 安装后，执行 `relay` 与执行 `bash relay.sh` 等价
+ 考虑到该脚本往往运行在位于中国大陆的服务器上，从 github 获取文件的链接均使用了可靠的镜像站点
## 服务管理

#### 启动
```
relay start
```
#### 停止
```
relay stop
```
#### 重启
```
relay restart
```
#### 更新
```
relay update
```
与 github 上的版本同步
## 使用教程

#### 智能处理
执行 `relay auto`
+ 若删除了多条规则，执行此命令将终止相关任务
+ 若添加了多条规则，执行此命令将创建相关任务
+ 若修改了多条规则，执行此命令将先终止相关任务，然后重新创建

脚本会添加一个每 3 分钟执行一次的定时任务自动处理上述事宜
#### 添加
执行 `relay add` 并按提示设置各项参数
#### 删除
执行 `relay del` 并按提示输入本地端口
#### 查询
执行 `relay list` 即可。查询特定关键词请配合 `grep` 使用。例：`relay list | grep keyword`
#### 修改
执行 `relay edit` 即可。将调用 `vim` 命令编辑配置文件 `/root/relay.conf`
#### 停用
将对应规则后的 `1` 修改为 `0` 即可
#### 延时创建
在创建任务时，若需设置时间间隔为 0.5s，则执行
```
relay delay 0.5
```

## 卸载
```
relay uninstall
```
