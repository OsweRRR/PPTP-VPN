#!/bin/bash

if dpkg-query -W needrestart >/dev/null 2>&1; then
     sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf
fi

# Get the interface name for the WAN connection using ip a command
INTERFACE_NAME=$(ip a | awk '/state UP/ {print $2}' | tr -d ':')
if [[ $INTERFACE_NAME == *"w"* ]]
then
    # WLAN connection detected
    wan=$(ip -f inet -o addr show $INTERFACE_NAME|cut -d\  -f 7 | cut -d/ -f 1)
else
    # Ethernet connection detected
    wan=$(ip -f inet -o addr show $INTERFACE_NAME|cut -d\  -f 7 | cut -d/ -f 1)
fi

ppp1=$(/sbin/ip route | awk '/default/ { print $3 }')
ip=$(dig +short myip.opendns.com @resolver1.opendns.com)

# Installing pptpd
echo "Installing PPTPD"
apt-get install pptpd -y

# edit DNS
echo "Setting Google DNS"
echo "ms-dns 8.8.8.8" >> /etc/ppp/pptpd-options
echo "ms-dns 8.8.4.4" >> /etc/ppp/pptpd-options

# Edit PPTP Configuration
echo "Editing PPTP Configuration"
remote="$ppp1"
remote+="0-200"
echo "localip $ppp1" >> /etc/pptpd.conf
echo "remoteip $remote" >> /etc/pptpd.conf

# Enabling IP forwarding in PPTP server
echo "Enabling IP forwarding in PPTP server"
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# Tinkering in Firewall
echo "Tinkering in Firewall"
if [ -z "$wan" ]
	then
		iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE && iptables-save
		iptables --table nat --append POSTROUTING --out-interface ppp0 -j MASQUERADE
		$(" iptables -I INPUT -s $ip/8 -i ppp0 -j ACCEPT")
		iptables --append FORWARD --in-interface wlan0 -j ACCEPT
	else
		iptables -t nat -A POSTROUTING -o $INTERFACE_NAME -j MASQUERADE && iptables-save
		iptables --table nat --append POSTROUTING --out-interface ppp0 -j MASQUERADE
		$(" iptables -I INPUT -s $ip/8 -i ppp0 -j ACCEPT")
		iptables --append FORWARD --in-interface $INTERFACE_NAME -j ACCEPT
fi

clear

# Adding VPN Users
echo "Set username:"
read username
echo "Set Password:"
read password
echo "$username * $password *" >> /etc/ppp/chap-secrets

# Restarting Service 
service pptpd restart

echo "All done!"
