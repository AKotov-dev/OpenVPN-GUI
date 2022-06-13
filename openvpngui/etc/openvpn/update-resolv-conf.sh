#!/usr/bin/bash

#DNS-Leak ON
echo "#OpenVPN-GUI + OpenDNS..." > /etc/resolv.conf
echo "nameserver 208.67.222.222" >> /etc/resolv.conf
echo "nameserver 208.67.220.220" >> /etc/resolv.conf

exit 0
