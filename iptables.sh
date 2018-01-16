#!/usr/bin/env bash
#
# firewall	iptables based frewall script
#

IPT="/usr/sbin/iptables"

test -x $IPT || exit 0

# check if we are root. Otherwise exit!
if [ "$(id -u)" != "0" ]
then
    echo "This script must be run as root!" 1>&2
    exit 1
fi

#modprobe ip_conntrack
#modprobe ip_conntrack_ftp
#modprobe ip_nat_ftp

#echo 1 > /proc/sys/net/ipv4/conf/all/route_localnet                   # Allow redirect to local interface 'lo'
echo 1 > /proc/sys/net/ipv4/tcp_syncookies                              # enable syn cookies (prevent against the common 'syn flood attack')
echo 0 > /proc/sys/net/ipv4/ip_forward                                  # forward packets
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts                 # ignore all ICMP ECHO and TIMESTAMP requests sent to it via broadcast/multicast
echo 1 > /proc/sys/net/ipv4/conf/all/log_martians                       # log packets with impossible addresses to kernel log
echo 1 > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses           # disable logging of bogus responses to broadcast frames
echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter                          # do source validation by reversed path (Recommended option for single homed hosts)
echo 0 > /proc/sys/net/ipv4/conf/all/send_redirects                     # Do not send ICMP redirects
echo 0 > /proc/sys/net/ipv4/conf/all/accept_redirects                   # Do not accept ICMP redirect
echo 0 > /proc/sys/net/ipv4/conf/all/accept_source_route                # don't accept packets with SRR option
echo 0 > /proc/sys/net/ipv4/icmp_echo_ignore_all                        # Ignore all (incoming + outgoing) ICMP ECHO requests (i.e. disable PING).
																		# Usually not a good idea, as some protocols and users need/want this.
echo 0 > /proc/sys/net/ipv4/conf/all/proxy_arp                          # Disable proxy_arp. Should not be needed, usually.
echo 0 > /proc/sys/net/ipv4/conf/all/bootp_relay                        # Disable bootp_relay. Should not be needed, usually.
echo 1 > /proc/sys/net/ipv4/conf/all/secure_redirects                   # Enable secure redirects, i.e. only accept ICMP redirects for gateways
																		# listed in the default gateway list. Helps against MITM attacks.

_dir_ipv6="/proc/sys/net/ipv6/conf/all/disable_ipv6"
if [ -d $_dir_ipv6 ]; then
    echo 1 > $_dir_ipv6                                                 # Disable ipv6 for all interfaces
fi

if [ "eth0" == "$1" ]
then
    # Network - ETH0
    _ext_if="eth0"
    _ext_ip="x.x.x.x"
    _ext_net="x.x.x.x/24"
    _gw_ip="x.x.x.x"
elif [ "wlan0" == "$1" ]
then
    # Network - WLAN0
    _ext_if="wlan0"
    _ext_ip="x.x.x.x"
    _ext_net="x.x.x.x/24"
    _gw_ip="x.x.x.x"
else
    echo "Usage: <filename> eth0/wlan0"
    exit 0
fi

_blockedIP="/paht/to/file/blockedIP.list"

station1=
station2=
station3=
net1=
net1=
_dns_ip1=
_dns_ip2=

_smtp_port=
_smtps_port=
_imaps_port=
_http_port=
_https_port=
_ssh_port=
_mongodb=

#------------------------------------------------------------------------------------------------------------------------
# clean tables

$IPT -P INPUT   ACCEPT
$IPT -P FORWARD ACCEPT
$IPT -P OUTPUT  ACCEPT

# flush rules
$IPT -F
$IPT -t nat -F
$IPT -t raw -F
$IPT -t mangle -F

# delete all (non-builtin) user-defined chains
$IPT -X
$IPT -t nat -X
$IPT -t raw -X
$IPT -t mangle -X

# zero all packet and byte counters
$IPT -Z
$IPT -t nat -Z
$IPT -t raw -Z
$IPT -t mangle -Z

#------------------------------------------------------------------------------------------------------------------------
# default policy

$IPT -P INPUT   DROP
$IPT -P FORWARD DROP
$IPT -P OUTPUT  DROP

#------------------------------------------------------------------------------------------------------------------------
# custom chains

$IPT -N LOGSSH
$IPT -A LOGSSH -p tcp -s $station2,$station3 -j RETURN        # Do not log internal IP address
$IPT -A LOGSSH -p tcp -m state --state NEW -j LOG --log-prefix "IPT-SSH "

$IPT -N LOGHTTP
$IPT -A LOGHTTP -p tcp -s $station2,$station3 -j RETURN       # Do not log internal IP address
$IPT -A LOGHTTP -p tcp -m state --state NEW -j LOG --log-prefix "IPT-HTTP "

$IPT -N LOGMAIL
$IPT -A LOGMAIL -p tcp -s $station2,$station3 -j RETURN       # Do not log internal IP address
$IPT -A LOGMAIL -p tcp -m state --state NEW -j LOG --log-prefix "IPT-MAIL "

$IPT -N BLACKLIST
$IPT -A BLACKLIST -m recent --name blacklist --set
$IPT -A BLACKLIST -j DROP

$IPT -N MAILFILTER
$IPT -A MAILFILTER -m set --match-set MAILFILTER src -j RETURN
$IPT -A MAILFILTER -j DROP

#------------------------------------------------------------------------------------------------------------------------
##
## !! uncomment the following lines if I want to allow blockip using iptables and not ipset
## timer in: /etc/systemd/system/blockips.{service|timer}
## script in: /paht/to/file/blockips
##

# ### Setup our black list of IPs ###
# $IPT -N droplist
# if [ -f "$_blockedIP" ];
# then
#     # Filter out comments and blank lines
#     # store each ip or subnet in $ip
#     while IFS= read -r ip
#     do
#         # drop it
#         $IPT -A droplist -i $_ext_if -s $ip -j DROP
#     done < $_blockedIP
# fi
# # After creating a CHAIN we need to add a rule to pass traffic to it 
# $IPT -I INPUT -j droplist
# $IPT -I OUTPUT -j droplist
# $IPT -I FORWARD -j droplist

##
## ipset - block ips by country and individual ips showed on /var/logs/iptables.log DPT=22
## timer in: /etc/systemd/system/blockips.{service|timer}
## script in: /paht/to/file/blockips
## more: https://wiki.archlinux.org/index.php/Ipset
##

# add ipset to iptables
$IPT -I INPUT -m set --match-set BLOCKCOUNTRY src -j DROP > /dev/null 2>&1     # block range of ip by country
$IPT -I INPUT -m set --match-set BLOCKTOR src -j DROP > /dev/null 2>&1         # block TOR exit node
$IPT -I INPUT -m set --match-set BLOCKIP src -j DROP > /dev/null 2>&1          # block individual ips

# drop Bad Guys
#$IPT -A INPUT -m recent --rcheck --seconds 60 -m limit --limit 10/s -j LOG --log-prefix "IPT-BG "
#$IPT -A INPUT -m recent --update --seconds 60 -j DROP

# drop spoofed packets (i.e. packets with local source addresses coming from outside etc.), mark as Bad Guy
$IPT -A INPUT -i $_ext_if -s $net1,$net1  -m recent --set -j DROP

# drop silently well-known virus/port scanning attempts
$IPT -A INPUT  -i $_ext_if -m multiport -p tcp --dports 53,113,135,137,139,445 -j DROP
$IPT -A INPUT  -i $_ext_if -m multiport -p udp --dports 53,113,135,137,139,445 -j DROP
$IPT -A INPUT  -i $_ext_if -p udp --dport 1026 -j DROP
$IPT -A INPUT  -i $_ext_if -m multiport -p tcp --dports 1433,4899 -j DROP

# drop invalid packets
$IPT -A INPUT -i $_ext_if -m state --state INVALID                     -j DROP     # DROP INVALID
$IPT -A INPUT -i $_ext_if -p tcp ! --syn -m state --state NEW          -j DROP     # FIRST PACKET HAS TO BE TCP SYN
$IPT -A INPUT -i $_ext_if -f                                           -j DROP     # DROP FRAGMENTS
$IPT -A INPUT -i $_ext_if -p tcp --tcp-flags ALL ALL                   -j DROP     # DROP XMAS
$IPT -A INPUT -i $_ext_if -p tcp --tcp-flags ALL NONE                  -j DROP     # DROP NULL PACKETS
$IPT -A INPUT -i $_ext_if -p tcp --tcp-flags SYN,FIN SYN,FIN           -j DROP     # DROP INVALID
$IPT -A INPUT -i $_ext_if -p tcp --tcp-flags SYN,RST SYN,RST           -j DROP     # DROP INVALID
$IPT -A INPUT -i $_ext_if -p tcp --tcp-flags SYN,URG SYN,URG           -j DROP     # DROP INVALID
$IPT -A INPUT -i $_ext_if -p tcp --tcp-flags ACK,FIN FIN               -j DROP     # DROP INVALID
$IPT -A INPUT -i $_ext_if -p tcp --tcp-flags ACK,PSH PSH               -j DROP     # DROP INVALID
$IPT -A INPUT -i $_ext_if -p tcp --tcp-flags ACK,URG URG               -j DROP     # DROP INVALID
$IPT -A INPUT -i $_ext_if -p tcp --tcp-flags FIN,RST FIN,RST           -j DROP     # DROP INVALID
$IPT -A INPUT -i $_ext_if -p tcp --tcp-flags ALL FIN,PSH,URG           -j DROP     # DROP INVALID
$IPT -A INPUT -i $_ext_if -p tcp --tcp-flags ALL SYN,FIN,PSH,URG       -j DROP     # DROP INVALID
$IPT -A INPUT -i $_ext_if -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG   -j DROP     # DROP INVALID

# drop excessive RST Packets to avoid Smurf-Attacks.
# See notes at the end of this script for limit and limit-burst
$IPT -A INPUT -i $_ext_if -p tcp --tcp-flags RST RST -m limit --limit 2/s --limit-burst 2 -j ACCEPT

# drop broadcast (do not log)
$IPT -A INPUT  -i $_ext_if -d 255.255.255.255 -j DROP
$IPT -A INPUT  -i $_ext_if -d 192.168.255.255 -j DROP
$IPT -A INPUT  -i $_ext_if -d 192.168.1.255   -j DROP
$IPT -A INPUT  -i $_ext_if -d 10.0.0.0/8      -j DROP
$IPT -A INPUT  -i $_ext_if -d 169.254.0.0/16  -j DROP

# drop rfc1918 packets
$IPT -A INPUT -i $_ext_if -s 10.0.0.0/8       -j DROP
$IPT -A INPUT -i $_ext_if -s 169.254.0.0/16   -j DROP
$IPT -A INPUT -i $_ext_if -s 172.16.0.0/12    -j DROP
$IPT -A INPUT -i $_ext_if -s 127.0.0.0/8      -j DROP

$IPT -A INPUT -i $_ext_if -s 224.0.0.0/4      -j DROP
$IPT -A INPUT -i $_ext_if -d 224.0.0.0/4      -j DROP
$IPT -A INPUT -i $_ext_if -s 240.0.0.0/5      -j DROP
$IPT -A INPUT -i $_ext_if -d 240.0.0.0/5      -j DROP
$IPT -A INPUT -i $_ext_if -s 0.0.0.0/8        -j DROP
$IPT -A INPUT -i $_ext_if -d 0.0.0.0/8        -j DROP
$IPT -A INPUT -i $_ext_if -d 239.255.255.0/24 -j DROP
$IPT -A INPUT -i $_ext_if -s 255.255.255.255  -j DROP

# Type 0 - icmp replay
# Type 8 - icmp request
# accept ICMP packets (ping et.al.)
#$IPT -A INPUT -p icmp -m limit --limit 10/second -j ACCEPT
#$IPT -A INPUT -p icmp -j DROP

###### DELETED SOME LINES FOR SECURITY REASONS... ########

# accept ICMP packets - limit 6/minute
$IPT -A INPUT  -m recent --name ICMP --update --seconds 60 --hitcount 6 -j DROP
$IPT -A INPUT  -p icmp -m recent --set --name ICMP -j ACCEPT

# accept ssh connections 
###### DELETED SOME LINES FOR SECURITY REASONS... ########

# accept everything from loopback
$IPT -A INPUT  -i lo -j ACCEPT
$IPT -A OUTPUT -o lo -j ACCEPT

$IPT -t nat -A POSTROUTING -d '!' $_ext_net -j MASQUERADE

#------------------------------------------------------------------------------------------------------------------------
# OUTPUT
#
$IPT -A OUTPUT -j ACCEPT


#------------------------------------------------------------------------------------------------------------------------
# INPUT
#
# 100 new connections (packet really) are allowed before the limit of 150 new connections (packets) per second is applied
$IPT -A INPUT -m conntrack --ctstate ESTABLISHED -m limit --limit 150/second --limit-burst 100 -j ACCEPT

# Allow SSH connections
$IPT -A INPUT -i $_ext_if -p tcp -m multiport --dports 22,$_ssh_port -m state --state NEW -j LOGSSH
$IPT -A INPUT -i $_ext_if -p tcp -m multiport --dports 22,$_ssh_port -m state --state NEW -m recent --set --name trackSSH
$IPT -A INPUT -i $_ext_if -p tcp -m multiport --dports 22,$_ssh_port -m state --state NEW -m recent --update --name trackSSH --seconds 60 --hitcount 2 -j BLACKLIST
###### DELETED SOME LINES FOR SECURITY REASONS... ########

# Allow HTTP/HTTPS connections
if ! netstat -tulpn | grep -q ":${_http_port}\|:{$_https_port}" ; then
    $IPT -A INPUT -p tcp -m multiport --dports $_http_port,$_https_port -j DROP
fi
$IPT -A INPUT -p tcp -m multiport --dports 80,443 -j DROP       # DROP packets that were not redirected
$IPT -A INPUT -i $_ext_if -p tcp -m multiport --dports $_http_port,$_https_port -m state --state NEW -m recent --set --name trackHTTP
$IPT -A INPUT -i $_ext_if -p tcp -m multiport --dports $_http_port,$_https_port -m state --state NEW -m recent --update --name trackHTTP --seconds 60 --hitcount 20 -j BLACKLIST
$IPT -A INPUT -i $_ext_if -p tcp -m multiport --dports $_http_port,$_https_port -m state --state NEW -j LOGHTTP
$IPT -A INPUT -i $_ext_if -p tcp --syn -m multiport --dports $_http_port,$_https_port -m connlimit --connlimit-above 15 --connlimit-mask 32 -j DROP        # Allow max 15 connections to port HTTP and HTTPS from the same ip
###### DELETED SOME LINES FOR SECURITY REASONS... ########

# Allow MAIL connections
if ! netstat -tulpn | grep -q ":${_smtp_port}\|:{$_smtps_port}" || ! netstat -tulpn | grep -q ":${_imaps_port}" ; then
    $IPT -A INPUT -p tcp -m multiport --dports $_smtp_port,$_smtps_port -j DROP
fi
$IPT -A INPUT -i $_ext_if -p tcp -m multiport --dports $_smtp_port,$_smtps_port,$_imaps_port -m state --state NEW -j MAILFILTER     # Allow only H3GUK network ips
$IPT -A INPUT -i $_ext_if -p tcp -m multiport --dports $_smtp_port,$_smtps_port,$_imaps_port -m state --state NEW -j LOGMAIL        # Log mail requests
$IPT -A INPUT -i $_ext_if -p tcp -m multiport --dports $_smtp_port,$_smtps_port,$_imaps_port -m state --state NEW -m recent --set --name trackMAIL
$IPT -A INPUT -i $_ext_if -p tcp -m multiport --dports $_smtp_port,$_smtps_port,$_imaps_port -m state --state NEW -m recent --update --name trackMAIL --seconds 240 --hitcount 4 -j BLACKLIST
###### DELETED SOME LINES FOR SECURITY REASONS... ########

# Allow other services
###### DELETED SOME LINES FOR SECURITY REASONS... ########

#------------------------------------------------------------------------------------------------------------------------
# Log
#
$IPT -A INPUT   -j LOG --log-prefix "IPT-IN "
$IPT -A FORWARD -j LOG --log-prefix "IPT-FW "

#------------------------------------------------------------------------------------------------------------------------
# Drop
#
$IPT -A OUTPUT  -j DROP
$IPT -A INPUT   -j DROP
$IPT -A FORWARD -j DROP

exit 0


## NOTES
#
# +-------------+
# | --tcp-flags |
# +-------------+
# Available flags are: SYN ACK FIN RST URG PSH ALL NONE
# The first argument mask is the flags which we should examine,
# written as a comma-separated list, and the second argument
# comp is a comma-separated list of flags which must be set.
#
# As an example, the argument --tcp-flags SYN,ACK,FIN,RST SYN
# will only match packets with the SYN flag set, and the ACK, FIN
# and RST flags unset.
#
# The rule: -p tcp --tcp-flags SYN,ACK,FIN,RST SYN -j DROP
# is saying: "Match if only the SYN flag is set from these four.
#
# The rule: -p tcp --tcp-flags ALL SYN -j DROP
# is saying: means check ALL flags and match those packets with
# nothing but SYN set
#
# +-----------------------------------+
# | Limit and limit burst in IPTABLES |
# +-----------------------------------+
# 
# The limit module sets a timer on how often the attached
# iptables rule is allowed to match a packet.
#
# The limit-burst parameter sets how many packets are allowed
# to match. The limit time sets how often the limit-burst
# restores itself.
#
# To boil it down, lets assume first that the burst bit doesn't
# exist (or is set to 1, amounts to same thing). The actual
# limit parameter specified simply sets the timer, for both the
# rule and the limit-burst. So setting it to 5/second would make
# the timer 1/5th of a second, and setting it to 4/hour would
# make the timer 15 minutes. No packet will match the rule while
# the timer is running (so if it's an ACCEPT target rule, no
# packet would be accepted for 1/5th of a second or 15 minutes,
# depending).
#
# So to complicate this... The limit-burst parameter acts like
# a packet counter. For every one packet that matches, the count
# goes down by one, and the timer starts (or restarts if its
# already running). The rule still matches anything that comes in.
# When the timer finishes, the count goes up by one. If the
# counter hits 0, the rule stops matching, until the timer
# finishes and the count goes back up to 1 again, and continues
# counting up by the timer until it gets back to the burst you set.
#
# So setting burst to 1 means you are very literally matching 1
# and only 1 packet per timer interval, and setting it higher means
# you are creating a buffer on that timer before it is strictly engaged.
#
# As a rough example, lets say you have a burst of 10 and a timer
# of 1/second, on an ACCEPT rule. Lets say you get 20 matching packets
# all within a second. The first ten match and are accepted, the
# rest do not. Ten seconds after that, the burst counter is back
# to maximum of 10. Now 5 matches come in (within a second), they
# all match no problem, counter would now be at 5. 2 seconds go by
# without matches, putting the counter at 7. Another 20 matches
# come in; the first 7 would match and accept, the rest not.
