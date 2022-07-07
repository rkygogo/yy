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
wget -N https://raw.githubusercontent.com/HyNetwork/hysteria/master/install_server.sh && bash install_server.sh 
openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/ca.key
openssl req -new -x509 -days 36500 -key /etc/hysteria/ca.key -out /etc/hysteria/ca.crt -subj "/CN=bing.com"
chmod +755 /etc/hysteria/ca.key
chmod +755 /etc/hysteria/ca.crt
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
green "hysteria登录端口：${port}"

readp "设置hysteria混淆密码obfs（回车跳过为随机6位字符）：" obfs
if [[ -z ${obfs} ]]; then
obfs=`date +%s%N |md5sum | cut -c 1-6`
fi
green "hysteria混淆密码obfs：${obfs}"
sysctl -w net.core.rmem_max=4000000
sysctl -p

if [ -z $v4 ]; then
cat <<EOF > /etc/hysteria/config.json
{
"listen": ":${port}",
"obfs": "${obfs}",
"resolve_preference": "6",
"cert": "/etc/hysteria/ca.crt",
"key": "/etc/hysteria/ca.key"
}
EOF
else
cat <<EOF > /etc/hysteria/config.json
{
"listen": ":${port}",
"obfs": "${obfs}",
"resolve_preference": "46",
"cert": "/etc/hysteria/ca.crt",
"key": "/etc/hysteria/ca.key"
}
EOF
fi

systemctl enable hysteria-server
systemctl start hysteria-server
systemctl restart hysteria-server

hysteriastatus(){
if [[ -n $(systemctl status hysteria-server 2>/dev/null | grep "active") ]]; then
status=$(green "hysteria运行中")
else
status=$(red "hysteria未运行")
fi
}

uninstall(){
systemctl stop hysteria-server
systemctl disable hysteria-server
rm -rf /usr/local/bin/hysteria
rm -rf /etc/hysteria
green "hysteria卸载完成！"
}

sed -i 's/"resolve_preference": "46"/"resolve_preference": "46"/g' /etc/hysteria/config.json
systemctl restart hysteria-server

