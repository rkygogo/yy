#!/bin/bash
red='\033[0;31m'
bblue='\033[0;34m'
plain='\033[0m'
red(){ echo -e "\033[31m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
yellow(){ echo -e "\033[33m\033[01m$1\033[0m";}
white(){ echo -e "\033[37m\033[01m$1\033[0m";}
readp(){ read -p "$(yellow "$1")" $2;}
[[ $EUID -ne 0 ]] && yellow "请以root模式运行脚本" && exit 1
if [[ -f /etc/redhat-release ]]; then
release="Centos"
elif cat /etc/issue | grep -q -E -i "debian"; then
release="Debian"
elif cat /etc/issue | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
elif cat /proc/version | grep -q -E -i "debian"; then
release="Debian"
elif cat /proc/version | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
else 
red "不支持你当前系统，请选择使用Ubuntu,Debian,Centos系统" && exit 1
fi
vi=`systemd-detect-virt`
if [[ $vi = openvz ]]; then
TUN=$(cat /dev/net/tun 2>&1)
if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ '处于错误状态' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then 
red "检测到未开启TUN，现尝试添加TUN支持" && sleep 2
cd /dev
mkdir net
mknod net/tun c 10 200
chmod 0666 net/tun
TUN=$(cat /dev/net/tun 2>&1)
if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ '处于错误状态' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then
green "添加TUN支持失败，建议与VPS厂商沟通或后台设置开启" && exit 0
else
green "恭喜，添加TUN支持成功，现执行重启VPS自动开启TUN守护功能" && sleep 2
cat>/root/tun.sh<<-\EOF
#!/bin/bash
cd /dev
mkdir net
mknod net/tun c 10 200
chmod 0666 net/tun
EOF
chmod +x /root/tun.sh
grep -qE "^ *@reboot root bash /root/tun.sh >/dev/null 2>&1" /etc/crontab || echo "@reboot root bash /root/tun.sh >/dev/null 2>&1" >> /etc/crontab
green "重启VPS自动开启TUN守护功能已启动"
fi
fi
fi
[[ $(type -P yum) ]] && yumapt='yum -y' || yumapt='apt -y'
[[ $(type -P curl) ]] || (yellow "检测到curl未安装，升级安装中" && $yumapt update;$yumapt install curl)
$yumapt install lsof -y
if [[ -z $(grep 'DiG 9' /etc/hosts) ]]; then
v4=$(curl -s4m5 https://ip.gs -k)
if [ -z $v4 ]; then
echo -e nameserver 2a01:4f8:c2c:123f::1 > /etc/resolv.conf
fi
fi
yellow "关闭防火墙，开放所有端口规则"
systemctl stop firewalld.service >/dev/null 2>&1
systemctl disable firewalld.service >/dev/null 2>&1
setenforce 0 >/dev/null 2>&1
ufw disable >/dev/null 2>&1
iptables -P INPUT ACCEPT >/dev/null 2>&1
iptables -P FORWARD ACCEPT >/dev/null 2>&1
iptables -P OUTPUT ACCEPT >/dev/null 2>&1
iptables -t nat -F >/dev/null 2>&1
iptables -t mangle -F >/dev/null 2>&1
iptables -F >/dev/null 2>&1
iptables -X >/dev/null 2>&1
netfilter-persistent save >/dev/null 2>&1
systemctl stop apache2 >/dev/null 2>&1
systemctl disable apache2 >/dev/null 2>&1
lsof -i :80|grep -v "PID"|awk '{print "kill -9",$2}'|sh >/dev/null 2>&1
green "所有端口已开放"

systemctl stop hysteria-server >/dev/null 2>&1
systemctl disable hysteria-server >/dev/null 2>&1
rm -rf /usr/local/bin/hysteria
rm -rf /etc/hysteria
wget -N https://raw.githubusercontent.com/HyNetwork/hysteria/master/install_server.sh && bash install_server.sh 
openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/ca.key
openssl req -new -x509 -days 36500 -key /etc/hysteria/ca.key -out /etc/hysteria/ca.crt -subj "/CN=bing.com"
chmod +755 /etc/hysteria/ca.key
chmod +755 /etc/hysteria/ca.crt

green "hysteria的协议选择如下:"
yellow "1. udp(默认)"
yellow "2. wechat-video"
yellow "3. faketcp"
readp "选择hysteria的协议(回车跳过默认:1): " Protocol
case ${Protocol} in
1)
hysteria_protocol="udp";;
2)
hysteria_protocol="wechat-video";;
3)
hysteria_protocol="faketcp";;
*)
hysteria_protocol="udp"
esac
green "确定hysteria协议：${hysteria_protocol}"

readp "设置hysteria登录端口[1-65535]（回车跳过为2000-65535之间的随机端口）：" port
if [[ -z $port ]]; then
port=$(shuf -i 2000-65535 -n 1)
until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]
do
[[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义hysteria端口:" port
done
else
until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]
do
[[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义hysteria端口:" port
done
fi
green "确定hysteria登录端口：${port}"

readp "设置hysteria混淆密码obfs（回车跳过为随机6位字符）：" obfs
if [[ -z ${obfs} ]]; then
obfs=`date +%s%N |md5sum | cut -c 1-6`
fi
green "确定hysteria混淆密码obfs：${obfs}"

readp "设置最大上传速度/Mbps(默认:100): " hysteria_up_mbps
[[ -z "${hysteria_up_mbps}" ]] && hysteria_up_mbps=100
green "确定最大上传速度$(hysteria_up_mbps)Mbps"
readp "设置最大下载速度/Mbps(默认:100): " hysteria_down_mbps
[[ -z "${hysteria_down_mbps}" ]] && hysteria_down_mbps=100
green "确定最大下载速度$(hysteria_down_mbps)Mbps"

if [[ ! $vi =~ lxc|openvz ]]; then
sysctl -w net.core.rmem_max=4000000
sysctl -p
fi

if [[ -z $v4 ]]; then
rpip=6
else
rpip=46
fi
cat <<EOF > /etc/hysteria/config.json
{
"listen": ":${port}",
"protocol": "${hysteria_protocol}",
"up_mbps": ${hysteria_up_mbps},
"down_mbps": ${hysteria_down_mbps},
"obfs": "${obfs}",
"resolve_preference": "${rpip}",
"cert": "/etc/hysteria/ca.crt",
"key": "/etc/hysteria/ca.key"
}
EOF

systemctl enable hysteria-server >/dev/null 2>&1
systemctl start hysteria-server >/dev/null 2>&1
systemctl restart hysteria-server >/dev/null 2>&1

hysteriastatus(){
if [[ -n $(systemctl status hysteria-server 2>/dev/null | grep "active") ]]; then
status=$(green "hysteria运行中")
else
status=$(red "hysteria未运行")
fi
}

uninstall(){
systemctl stop hysteria-server >/dev/null 2>&1
systemctl disable hysteria-server >/dev/null 2>&1
rm -rf /usr/local/bin/hysteria
rm -rf /etc/hysteria
green "hysteria卸载完成！"
}

changeip(){
if [ ! -f "/etc/hysteria/config.json" ]; then
red "未正常安装hysteria!" && exit
fi
fip=$(curl ip.gs)
if [[ -n $(echo $fip | grep ":") ]]; then
green "当前IPV6优先"



else


green "当前IPV4优先"
fi


切换IPV6优先
sed -i 's/"resolve_preference": "46"/"resolve_preference": "64"/g' /etc/hysteria/config.json
systemctl restart hysteria-server

纯V6卸载warp,切换纯IPV6状态
sed -i 's/"resolve_preference": "46"/"resolve_preference": "6"/g' /etc/hysteria/config.json
systemctl restart hysteria-server

纯V6卸载warp,切换纯IPV6状态
sed -i 's/"resolve_preference": "64"/"resolve_preference": "6"/g' /etc/hysteria/config.json
systemctl restart hysteria-server

切换IPV4优先
sed -i 's/"resolve_preference": "64"/"resolve_preference": "46"/g' /etc/hysteria/config.json
systemctl restart hysteria-server

切换IPV6优先
sed -i 's/"resolve_preference": "6"/"resolve_preference": "64"/g' /etc/hysteria/config.json
systemctl restart hysteria-server

切换IPV4优先
sed -i 's/"resolve_preference": "6"/"resolve_preference": "46"/g' /etc/hysteria/config.json
systemctl restart hysteria-server
}


clear
green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"           
echo -e "${bblue} ░██     ░██      ░██ ██ ██         ░█${plain}█   ░██     ░██   ░██     ░█${red}█   ░██${plain}  "
echo -e "${bblue}  ░██   ░██      ░██    ░░██${plain}        ░██  ░██      ░██  ░██${red}      ░██  ░██${plain}   "
echo -e "${bblue}   ░██ ░██      ░██ ${plain}                ░██ ██        ░██ █${red}█        ░██ ██  ${plain}   "
echo -e "${bblue}     ░██        ░${plain}██    ░██ ██       ░██ ██        ░█${red}█ ██        ░██ ██  ${plain}  "
echo -e "${bblue}     ░██ ${plain}        ░██    ░░██        ░██ ░██       ░${red}██ ░██       ░██ ░██ ${plain}  "
echo -e "${bblue}     ░█${plain}█          ░██ ██ ██         ░██  ░░${red}██     ░██  ░░██     ░██  ░░██ ${plain}  "
green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
white "甬哥Gitlab项目  ：gitlab.com/rwkgyg"
white "甬哥blogger博客 ：ygkkk.blogspot.com"
white "甬哥YouTube频道 ：www.youtube.com/c/甬哥侃侃侃kkkyg"
yellow "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
bblue " WARP-WGCF/SOCKS5安装脚本：2022.3.24更新 Beta 8 版本"  
yellow " 切记：安装WARP成功后，进入脚本快捷方式：cf  其他说明：cf h"
white " ========================================================================================"
green "  1. 安装Wgcf-WARP:虚拟IPV4"      
green "  2. 安装Wgcf-WARP:虚拟IPV6"      
green "  3. 安装Wgcf-WARP:虚拟IPV4+IPV6" 
[[ $cpu != AMD64 ]] && red "  4. 提示：当前VPS的CPU并非AMD64架构，目前不支持安装Socks5-WARP(+)" || green "  4. 安装Socks5-WARP：IPV4本地Socks5代理"
white " -------------------------------------------------------------------------------------------"    
green "  5. WARP账户升级：WARP+账户与WARP+Teams账户"
green "  6. WARPR解锁NF奈飞：自动识别WARP配置环境" 
green "  7. WARP开启、停止、卸载"
green "  0. 退出脚本 "
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
white " VPS系统信息如下："
white " VPS操作系统: $(blue "$op") \c" && white " 内核版本: $(blue "$version") \c" && white " CPU架构 : $(blue "$cpu") \c" && white " 虚拟化类型: $(blue "$vi") \c" && white " TCP算法: $(blue "$bbr")"
echo
readp "请输入数字:" Input
case "$Input" in     
 1 ) WGCFv4;;
 2 ) WGCFv6;;
 3 ) WGCFv4v6;;
 4 ) [[ $cpu = AMD64 ]] && SOCKS5ins || bash CFwarp.sh;; 
 5 ) WARPupre;;
 6 ) REnfwarp;;	
 7 ) WARPOC;;
 * ) exit 
esac
}

if [ $# == 0 ]; then
start
start_menu
fi

