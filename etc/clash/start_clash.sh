#!/bin/sh

/etc/clash/clash -d /etc/clash >/dev/null &
PID=$!

# create a ipv4 ipset for cn routes
ipset create chnroutes4 hash:net
cat /etc/clash/chnroutes4 | while read -r cidr; do ipset add chnroutes4 $cidr; done

# setup packet marking
iptables -t mangle -N CLASH
iptables -t mangle -F CLASH
iptables -t mangle -A CLASH -d 0.0.0.0/8 -j RETURN
iptables -t mangle -A CLASH -d 10.0.0.0/8 -j RETURN
iptables -t mangle -A CLASH -d 127.0.0.0/8 -j RETURN
iptables -t mangle -A CLASH -d 169.254.0.0/16 -j RETURN
iptables -t mangle -A CLASH -d 172.16.0.0/12 -j RETURN
iptables -t mangle -A CLASH -d 192.168.0.0/16 -j RETURN
iptables -t mangle -A CLASH -d 224.0.0.0/4 -j RETURN
iptables -t mangle -A CLASH -d 240.0.0.0/4 -j RETURN
iptables -t mangle -A CLASH -m set --match-set chnroutes4 dst -j RETURN
iptables -t mangle -A CLASH -j MARK --set-xmark 129

# redirect traffic where ports < 8192
iptables -t mangle -F PREROUTING
iptables -t mangle -A PREROUTING -p udp -m udp --dport 8192:65535 -j RETURN
iptables -t mangle -A PREROUTING -p tcp -m tcp --dport 8192:65535 -j RETURN
iptables -t mangle -A PREROUTING -j CLASH

# redirect dns
iptables -t nat -I PREROUTING -p tcp --dport 53 -j REDIRECT --to 1053
iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to 1053
ip6tables -t nat -I PREROUTING -p tcp --dport 53 -j REDIRECT --to 1053
ip6tables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to 1053

# add firewall rules
iptables -I FORWARD -o utun -j ACCEPT
iptables -I FORWARD -i utun -j ACCEPT

# setup routes for marked packets
ip route add default dev utun table 129
ip rule add fwmark 129 lookup 129

wait $PID
