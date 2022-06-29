#!/bin/sh
rm -f /usr/bin/hysteria
rm -rf /root/Hysteria
mkdir /root/Hysteria
mkdir /etc/Hysteria
version=`wget -qO- -t1 -T2 --no-check-certificate "https://api.github.com/repos/HyNetwork/hysteria/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g'`
	echo -e "The Latest hysteria version:"`echo "${version}"`"\nDownload..."
    get_arch=`arch`
    if [ $get_arch = "x86_64" ];then
        wget -N https://github.com/rkygogo/yy/blob/main/hysteria-tun-linux-amd64 -O /usr/bin/hysteria
	
    else
        wget -N --no-check-certificate https://github.com/HyNetwork/hysteria/releases/download/${version}/hysteria-linux-arm64 -O /usr/bin/hysteria
fi
chmod +x /usr/bin/hysteria

openssl ecparam -genkey -name prime256v1 -out /root/hysteria/ca.key
openssl req -new -x509 -days 36500 -key /root/hysteria/ca.key -out /root/Hysteria/ca.crt -subj "/CN=baidu.com"

cat <<EOF > /etc/hysteria/server.json
{
    "listen": "[::]:9527",
    "cert": "/root/hysteria/ca.crt",
    "key": "/root/hysteria/ca.key",
    "obfs": "123"
}
EOF


nohup /root/hysteria -c /etc/hysteria/server.json server > /dev/null 2>&1 &

url="hysteria://$IP:9527?auth=123&upmbps=200&downmbps=1000&obfs=xplus&obfsParam=123"
echo $url
