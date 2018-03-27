#!/bin/bash
#
# battery status script
#

BAT="/sys/class/power_supply/BAT0"

BATSTATE=`cat $BAT/status`
CHARGE=`cat $BAT/capacity`
CHARGE="${CHARGE//%}"

NON='\033[00m'
BLD='\033[01m'
RED='\033[01;31m'
GRN='\033[01;32m'
YEL='\033[01;33m'

COLOUR="$RED"
case "${BATSTATE}" in
   'charged')
   BATSTT="$BLD=$NON"
   ;;
   'charging')
   BATSTT="$BLD+$NON"
   ;;
   'discharging')
   BATSTT="$BLD-$NON"
   ;;
esac

# prevent a charge of more than 100% displaying
if [ "$CHARGE" -gt "99" ]
then
   CHARGE=100
fi

if [ "$CHARGE" -gt "15" ]
then
   COLOUR="$YEL"
fi

if [ "$CHARGE" -gt "30" ]
then
   COLOUR="$GRN"
fi

#echo -e "${COLOUR}${CHARGE}%${NON}${BATSTT}"
echo -e "${CHARGE}%"

# end of file
