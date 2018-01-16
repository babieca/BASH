#!/usr/bin/env bash
#
# Block IPs
# Extract IP addresses for the iptables logs
# connecting to port 22 to block

# check if we are root. Otherwise exit!
if [ "$(id -u)" != "0" ]
then
    echo "This script must be run as root!" 1>&2
    exit 1
fi

_blockedIP_lst="/root/blockips/blockedIP.list"
_blockedIP_tmp="/tmp/blockedIP.tmp"

# -------------------------------------------------------------------------------
# using ipset
# -------------------------------------------------------------------------------

_myip=$(curl ipinfo.io/ip)
_tcpports=(22 25 587 993)
_torips=""

# add new IPs in the set 'BLOCKIP' if it does not exist
_set="BLOCKTOR"
# chech if set already exist. If it does not, create it.
ipset list | grep -q ${_set}
if [ $? -ne 0 ]; then
    ipset create ${_set} hash:ip,port
fi

# get a list of Tor exit nodes that can access $_myip
# loop over the ips that can reach the specific port.
for _port in "${_tcpports[@]}"
do
    _url="https://check.torproject.org/cgi-bin/TorBulkExitList.py?ip=${_myip}&port=${_port}"
    _torips=$(wget -qO- ${_url})
    # remove leading spaces, skip comments, skip empty lines and duplicated ips and read line by line
    echo -e "${_torips}" | sed -e 's/^[ \t]*//' | sed '/^$/d' | sed '/^#/d' | sort | uniq | while read _ip
    do 
        # add each IP address to the new set, silencing the warnings that have already been added
        ipset -q -A ${_set} "${_ip},${_port}"
    done
done

# save latest ips
ipset save > /etc/ipset.conf

exit 0
