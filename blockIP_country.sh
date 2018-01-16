#!/usr/bin/env bash
#
# Block IPs by country
# http://www.ipdeny.com/ipblocks/data/countries/

# check if we are root. Otherwise exit!
if [ "$(id -u)" != "0" ]
then
	echo "This script must be run as root!" 1>&2
	exit 1
fi

_set="BLOCKCOUNTRY"
_url="http://www.ipdeny.com/ipblocks/data/countries/"
_folder="/root/blockips/"
_countries=( cn ua vn ru af ao az bg cy cz dz ee hu ge kz lv ma md me mm mt pl si ro rs ir iq )

iptables -D INPUT -m set --match-set ${_set} src -j DROP > /dev/null 2>&1

# delete the set named BLOCKCOUNTRY
ipset -q destroy ${_set}

# Create the ipset list
ipset -N ${_set} hash:net

for _country in ${_countries[@]}; do
    
    _czone="${_country}.zone"
    if [ -f ${_czone} ]; then rm -f ${_czone}; fi

    # Pull the latest IP set for that country
    wget -O ${_folder}${_czone} ${_url}${_czone} -q --show-progress

    # Add each IP address from the downloaded list into the ipset
    for _ip in $(cat ${_folder}${_czone} ); do ipset -A ${_set} ${_ip}; done
done

iptables -I INPUT -m set --match-set ${_set} src -j DROP

# save ipset
ipset save > /etc/ipset.conf

exit 0
