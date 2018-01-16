#!/usr/bin/env bash
#
# Block IPs
# Extract IP addresses for the iptables logs
# connecting to port 22 to block

set -e

# check if we are root. Otherwise exit!
if [ "$(id -u)" != "0" ]
then
	echo "This script must be run as root!" 1>&2
	exit 1
fi

_blockedIP_lst="/root/blockips/blockedIP.list"
_blockedIP_tmp="/tmp/blockedIP.tmp"

find /var/log/ -type f -name ipt_SSH.log* | xargs grep -r "DPT=22" | sed 's/  */ /g' |     \
    cut -d ' ' -f 10 |          \
    sed s/SRC=// |              \
    sed '/192.168.1.40/d' |     \
    sed '/192.168.1.94/d' |     \
    sort | uniq > "$_blockedIP_tmp"

if [ ! -f "$_blockedIP_lst" ];
then
    sort -u "$_blockedIP_tmp" -o "$_blockedIP_lst"
else
    sort -u "$_blockedIP_lst" "$_blockedIP_tmp" -o "$_blockedIP_lst"
    rm -f "$_blockedIP_tmp"
fi

# turn off error crash (if iptables -C does not find the rule, it fires an error)
set +e


# -------------------------------------------------------------------------------
# using ipset
# -------------------------------------------------------------------------------

# add new IPs in the set 'BLOCKIP' if it does not exist
_set="BLOCKIP"
# chech if set already exist. If it does not, create it.
ipset list | grep -q ${_set}
if [ $? -ne 0 ]; then
    ipset create ${_set} hash:net
fi

while IFS= read -r ip; do
    # chech if ip is already in the set. If it is, skip it.
    if grep ${ip} /etc/ipset.conf; then continue; fi
    ipset add  ${_set} ${ip}
done < "$_blockedIP_lst"

# save latest ips
ipset save > /etc/ipset.conf


# -------------------------------------------------------------------------------
# using iptables
# -------------------------------------------------------------------------------

# Add new IPs in the *IPTABLES* rule 'droplist' if it does not exist
#
#while IFS= read -r ip; do
#    iptables -C droplist -i eth0 -s $ip -j DROP > /dev/null 2>&1
#    if [ $? -ne 0 ];
#    then
#        iptables -A droplist -i eth0 -s $ip -j DROP
#    fi
#done < "$_blockedIP_lst"
