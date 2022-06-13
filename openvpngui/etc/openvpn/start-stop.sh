#!/usr/bin/bash

#Входящие параметры
user="$1"
pass="$2"
stop="$3"

#Stop all OpenVPN sessions
while [[ -n $(/usr/bin/pidof openvpn) ]]; do /usr/bin/killall -QUIT openvpn; done

#Delete logfile
/usr/bin/rm -f /etc/openvpn/openvpn.log

#Off tun/tap interface
while [[ -n $(/usr/sbin/ifconfig | grep "tun0") ]]; do /usr/sbin/ifconfig tun0 down; done
while [[ -n $(/usr/sbin/ifconfig | grep "tap0") ]]; do /usr/sbin/ifconfig tap0 down; done

#DNS-Leak OFF (возвращаем /etc/resolv.conf по умолчанию)
test $(pidof NetworkManager) && systemctl restart NetworkManager || /usr/sbin/resolvconf -u

if [ "$stop" = "1" ]; then exit 0; fi

#---Start OpenVPN from OpenVPN-GUI---

#Разрешить сбрасывать tun/tap в момент переподключения при разрыве
sed -i 's/^persist-tun*/#persist-tun/' /etc/openvpn/client.conf

#Если ключу требуются юзер и пароль, но они не заданы - даём ложные, чтобы избежать зависания
if [[ -n $(/usr/bin/grep "^auth-user-pass" /etc/openvpn/client.conf) ]]; then
   if [ -z "$user" -o -z "$pass" ]; then  user="1"; pass='2'; fi
#Start OpenVPN with password
    /usr/sbin/openvpn --daemon \
    --mute-replay-warnings \
    --cd /etc/openvpn --config /etc/openvpn/client.conf \
    --log /etc/openvpn/openvpn.log \
    --auth-user-pass <(/usr/bin/echo -e "$user\n$pass") \
    --script-security 2 \
    --up /etc/openvpn/update-resolv-conf.sh; else
#Start OpenVPN without password
    /usr/sbin/openvpn --daemon \
    --mute-replay-warnings \
    --cd /etc/openvpn --config /etc/openvpn/client.conf \
    --log /etc/openvpn/openvpn.log \
    --script-security 2 \
    --up /etc/openvpn/update-resolv-conf.sh
fi;

chown root:root /etc/openvpn/*
chmod 600 /etc/openvpn/client.conf
chmod 604 /etc/openvpn/openvpn.log

exit 0
