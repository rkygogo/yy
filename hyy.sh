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
red "不支持你当前系统，请选择使用Ubuntu,Debian,Centos系统" && rm -rf acme.sh && exit 1
fi

[[ $(type -P yum) ]] && yumapt='yum -y' || yumapt='apt -y'
[[ $(type -P curl) ]] || (yellow "检测到curl未安装，升级安装中" && $yumapt update;$yumapt install curl)
[[ $(type -P socat) ]] || $yumapt install socat
$yumapt install lsof -y
v6=$(curl -s6m3 https://ip.gs -k)
v4=$(curl -s4m3 https://ip.gs -k)
if [[ -z $v4 ]]; then
echo -e nameserver 2a01:4f8:c2c:123f::1 > /etc/resolv.conf
sleep 2
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
wget -N https://raw.githubusercontent.com/HyNetwork/hysteria/master/install_server.sh && bash install_server.sh 
openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/ca.key
openssl req -new -x509 -days 36500 -key /etc/hysteria/ca.key -out /etc/hysteria/ca.crt -subj "/CN=bing.com"
chmod +755 /etc/hysteria/ca.key
chmod +755 /etc/hysteria/ca.crt
cat <<EOF > /etc/hysteria/config.json
{
"listen": ":$PORT",
"obfs": "$OBFS",
"resolve_preference": "6",
"cert": "/etc/hysteria/ca.crt",
"key": "/etc/hysteria/ca.key"
}
EOF
systemctl enable hysteria-server
systemctl start hysteria-server
systemctl restart hysteria-server
