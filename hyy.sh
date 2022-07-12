#!/bin/bash
red='\033[0;31m'
bblue='\033[0;34m'
plain='\033[0m'
blue(){ echo -e "\033[36m\033[01m$1\033[0m";}
red(){ echo -e "\033[31m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
yellow(){ echo -e "\033[33m\033[01m$1\033[0m";}
white(){ echo -e "\033[37m\033[01m$1\033[0m";}
readp(){ read -p "$(yellow "$1")" $2;}
[[ $EUID -ne 0 ]] && yellow "请以root模式运行脚本" && exit 1
yellow " 请稍等3秒……正在扫描vps类型及参数中……"
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
red "不支持你当前系统，请选择使用Ubuntu,Debian,Centos系统。" && exit 1
fi
vsid=`grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1`
sys(){
[ -f /etc/os-release ] && grep -i pretty_name /etc/os-release | cut -d \" -f2 && return
[ -f /etc/lsb-release ] && grep -i description /etc/lsb-release | cut -d \" -f2 && return
[ -f /etc/redhat-release ] && awk '{print $0}' /etc/redhat-release && return;}
op=`sys`
version=`uname -r | awk -F "-" '{print $1}'`
main=`uname  -r | awk -F . '{print $1}'`
minor=`uname -r | awk -F . '{print $2}'`
bit=`uname -m`
[[ $bit = x86_64 ]] && cpu=AMD64
[[ $bit = aarch64 ]] && cpu=ARM64
vi=`systemd-detect-virt`

start(){
if [[ $vi = openvz ]]; then
TUN=$(cat /dev/net/tun 2>&1)
if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ '处于错误状态' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then 
red "检测到未开启TUN，现尝试添加TUN支持" && sleep 4
cd /dev
mkdir net
mknod net/tun c 10 200
chmod 0666 net/tun
TUN=$(cat /dev/net/tun 2>&1)
if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ '处于错误状态' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then 
green "添加TUN支持失败，建议与VPS厂商沟通或后台设置开启" && exit 0
else
green "恭喜，添加TUN支持成功，现添加防止重启VPS后TUN失效的TUN守护功能" && sleep 4
cat>/root/tun.sh<<-\EOF
#!/bin/bash
cd /dev
mkdir net
mknod net/tun c 10 200
chmod 0666 net/tun
EOF
chmod +x /root/tun.sh
grep -qE "^ *@reboot root bash /root/tun.sh >/dev/null 2>&1" /etc/crontab || echo "@reboot root bash /root/tun.sh >/dev/null 2>&1" >> /etc/crontab
green "TUN守护功能已启动"
fi
fi
fi
[[ $(type -P yum) ]] && yumapt='yum -y' || yumapt='apt -y'
[[ $(type -P curl) ]] || (yellow "检测到curl未安装，升级安装中" && $yumapt update;$yumapt install curl)
[[ $(type -P lsof) ]] || (yellow "检测到curl未安装，升级安装中" && $yumapt update;$yumapt install lsof)
if [[ -z $(grep 'DiG 9' /etc/hosts) ]]; then
v4=$(curl -s4m5 https://ip.gs -k)
if [ -z $v4 ]; then
echo -e nameserver 2a01:4f8:c2c:123f::1 > /etc/resolv.conf
fi
fi
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
if [[ -n $(apachectl -v 2>/dev/null) ]]; then
systemctl stop httpd.service >/dev/null 2>&1
systemctl disable httpd.service >/dev/null 2>&1
service apache2 stop >/dev/null 2>&1
systemctl disable apache2 >/dev/null 2>&1
fi
}

inshy(){
systemctl stop hysteria-server >/dev/null 2>&1
systemctl disable hysteria-server >/dev/null 2>&1
rm -rf /usr/local/bin/hysteria
rm -rf /etc/hysteria
wget -N https://raw.githubusercontent.com/HyNetwork/hysteria/master/install_server.sh && bash install_server.sh

green "hysteria证书申请方式选择如下:"
yellow "1. 自签证书(默认)"
yellow "2. ACME一键申请证书"
yellow "0. 返回上一层"
readp "选择证书申请方式(回车跳过默认:1): " ca
case ${ca} in
1)
openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/private.key
openssl req -new -x509 -days 36500 -key /etc/hysteria/private.key -out /etc/hysteria/cert.crt -subj "/CN=bing.com";;
2)
wget -N https://raw.githubusercontent.com/rkygogo/1-acmecript/main/acme.sh && bash acme.sh;;
0)
start_menu;;
*)
red "输入错误，请重新选择" && changeip
esac


}
inspr(){
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
}
insport(){
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
}
insobfs(){
readp "设置hysteria验证密码（回车跳过为随机6位字符）：" pswd
if [[ -z ${pswd} ]]; then
pswd=`date +%s%N |md5sum | cut -c 1-6`
fi
green "确定hysteria验证密码：${pswd}"

#readp "设置最大上传速度/Mbps(默认:100): " hysteria_up_mbps
#[[ -z "${hysteria_up_mbps}" ]] && hysteria_up_mbps=100
#green "确定最大上传速度$hysteria_up_mbps"
#readp "设置最大下载速度/Mbps(默认:100): " hysteria_down_mbps
#[[ -z "${hysteria_down_mbps}" ]] && hysteria_down_mbps=100
#green "确定最大下载速度$hysteria_down_mbps"
}

insconfig(){
v4=$(curl -s4m5 https://ip.gs -k)
if [[ -z $v4 ]]; then
rpip=64
else
rpip=46
fi
cat <<EOF > /etc/hysteria/config.json
{
"listen": ":${port}",
"protocol": "${hysteria_protocol}",
"resolve_preference": "${rpip}",
"auth": {
"mode": "password",
"config": {
"password": "${pswd}"
}
},
"cert": "/etc/hysteria/cert.crt",
"key": "/etc/hysteria/private.key"
}
EOF
}

unins(){
systemctl stop hysteria-server.service >/dev/null 2>&1
systemctl disable hysteria-server.service >/dev/null 2>&1
rm -f /lib/systemd/system/hysteria-server.service /lib/systemd/system/hysteria-server@.service
rm -rf /usr/local/bin/hysteria /etc/hysteria /usr/bin/hy

green "hysteria卸载完成！"
}

uphysteriacore(){
if [[ -f '/usr/local/bin/hysteria' ]]; then
wget -N https://raw.githubusercontent.com/HyNetwork/hysteria/master/install_server.sh && bash install_server.sh
systemctl restart hysteria-server >/dev/null 2>&1
VERSION="$(/usr/local/bin/hysteria -v | awk 'NR==1 {print $3}')"
green "当前hysteria内核版本号：$VERSION"
else
red "未安装hysteria" && exit
fi
}

changepr(){
noprotocol=`cat /etc/hysteria/config.json 2>/dev/null | grep protocol | awk '{print $2}' | awk -F '"' '{ print $2}'`
green "当前使用协议为：$noprotocol"
echo
inspr
sed -i "s/$noprotocol/$hysteria_protocol/g" /etc/hysteria/config.json
systemctl restart hysteria-server 
}

changeip(){
if [ ! -f "/etc/hysteria/config.json" ]; then
red "未正常安装hysteria!" && exit
fi
green "切换IPV4/IPV6出站优先级选择如下:"
yellow "1. IPV4优先"
yellow "2. IPV6优先"
yellow "0. 返回上层"
readp "请选择: " rrpip
case ${rrpip} in
1)
rrpip="46";;
2)
rrpip="64";;
0)
start_menu;;
*)
red "输入错误，请重新选择" && changeip
esac
green "确定当前已更换的IP优先级：${rrpip}"
sed -i "4s/$rpip/$rrpip/g" /etc/hysteria/config.json
systemctl restart hysteria-server
}

inshysteria(){
start ; inshy ; inspr ; insport ; insobfs
if [[ ! $vi =~ lxc|openvz ]]; then
sysctl -w net.core.rmem_max=4000000
sysctl -p
fi
insconfig
systemctl enable hysteria-server >/dev/null 2>&1
systemctl start hysteria-server >/dev/null 2>&1
systemctl restart hysteria-server >/dev/null 2>&1
hysteriastatus
white " $status"
}

hysteriastatus(){
wgcfv6=$(curl -s6m6 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2) 
wgcfv4=$(curl -s4m6 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
wgcf=$(red "WARP关闭中")
else
wgcf=$(green "WARP运行中")
fi
if [[ -n $(systemctl status hysteria-server 2>/dev/null | grep -w active) ]]; then
noprotocol=`cat /etc/hysteria/config.json 2>/dev/null | grep protocol | awk '{print $2}' | awk -F '"' '{ print $2}'`
rpip=`cat /etc/hysteria/config.json 2>/dev/null | grep resolve_preference | awk '{print $2}' | awk -F '"' '{ print $2}'`
[[ $rpip = 64 ]] && v4v6="IPV6优先：$(curl -s6 ip.gs)" || v4v6="IPV4优先：$(curl -s4 ip.gs)"
status=$(white "hysteria运行状态：\c";green "运行中";white " hysteria运行协议：\c";green "$noprotocol";white " 当前优先出站IP：  \c";green "$v4v6";white " WARP运行状态：    \c";eval echo \$wgcf )
else
status=$(white "hysteria运行状态：\c";red "未启动";white " WARP运行状态：    \c";eval echo \$wgcf)
fi
}

start_menu(){
hysteriastatus
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
blue " WARP-WGCF/SOCKS5安装脚本：2022.3.24更新 Beta 8 版本"  
yellow " 切记：安装WARP成功后，进入脚本快捷方式：cf  其他说明：cf h"
white " ========================================================================================"
green "  1. 安装hysteria"      
green "  2. 修改当前协议类型"      
green "  3. 更新脚本"  
green "  4. 更新hysteria内核"
green "  5. 切换IPV4/IPV6出站优先级" 
green "  6. 卸载hysteria"
green "  0. 退出脚本 "
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
white " VPS系统信息如下："
white " 操作系统:         $(blue "$op")" && white " 内核版本:         $(blue "$version")" && white " CPU架构 :         $(blue "$cpu")" && white " 虚拟化类型:       $(blue "$vi")"
white " $status"
echo
readp "请输入数字:" Input
case "$Input" in     
 1 ) inshysteria;;
 2 ) changepr;;
 3 ) ;;
 4 ) uphysteriacore;; 
 5 ) changeip;;
 6 ) unins;;	
 * ) exit 
esac
}

if [[ -n $(systemctl status hysteria-server 2>/dev/null | grep -w active) ]]; then
chmod +x /root/hyy.sh 
ln -sf /root/hyy.sh /usr/bin/hy
fi


if [ $# == 0 ]; then
start
start_menu
fi

