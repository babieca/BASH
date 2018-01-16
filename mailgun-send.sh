#!/bin/bash
#requires: date,sendmail

set -e

function fappend {
    echo "$2">>$1;
}

YYYYMMDD=`date +%Y%m%d`
 
# DON'T CHANGE ANYTHING BELOW

if [ "$#" -ge 1 ]; then
    TO=$1;
else
    TO="";
fi


if [ "$#" -ge 2 ]; then
    FROM=$2;
else
    FROM="";
fi
REPLY=$FROM;

if [ "$#" -ge 3 ]; then
    SUBJECT=$3;
else
    SUBJECT="Daily Backup - $YYYYMMDD";
fi

if [ "$#" -ge 4 ]; then
    MSG=$4;
else
    MSG="This is your daily backup notice";
fi

# make a unique temporary filename
TMP=`mktemp`
 
rm -rf $TMP;
fappend $TMP "From: $FROM";
fappend $TMP "To: $TO";
fappend $TMP "Reply-To: $REPLY";
fappend $TMP "Subject: $SUBJECT";
fappend $TMP "";
fappend $TMP "$MSG";
fappend $TMP "";
fappend $TMP "";
cat $TMP|sendmail -t;
rm $TMP;
