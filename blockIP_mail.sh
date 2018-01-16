#!/usr/bin/env bash
#
# Allow only IPs from a list of range

# check if we are root. Otherwise exit!
if [ "$(id -u)" != "0" ]
then
    echo "This script must be run as root!" 1>&2
    exit 1
fi

file="/root/blockips/mail-ips.txt"       # ip in the form of CIDR allowed to request mail

# -------------------------------------------------------------------------------
# using ipset
# -------------------------------------------------------------------------------

# add new IPs in the set 'BLOCKIP' if it does not exist
_set="MAILFILTER"
# chech if set already exist. If it does not, create it.
ipset list | grep -q ${_set}
if [ $? -ne 0 ]; then
    ipset create ${_set} hash:net
fi

# loop over the list of ips
# exclude comments (#) and empty lines
grep -v '^$\|^\s*\#' "${file}" | while read -r _cidr; do
    # add each IP address to the new set, silencing the warnings that have already been added
    ipset -q -A ${_set} "${_cidr}"
done

# save latest ips
ipset save > /etc/ipset.conf

exit 0
