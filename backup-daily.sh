#!/usr/bin/env bash
#
# Shell script to create incremental backups with rsync.
# The shebang specifies Bash explicitly because this script relies on brace expansion.
# http://stackoverflow.com/q/10376206
#
# Use a timestamp in the ISO 8601 basic date and time format.  The precision is reduced to
# minutes.  The time is given in UTC (Coordinated Universal Time), which is indicated by
# adding a trailing Z to the timestamp.
# http://programmers.stackexchange.com/q/61683

# 'set -e' causes the shell to exit if any subcommand or pipeline returns a non-zero status
#set -e

formatsec() {
    ((h=${1}/3600))
    ((m=(${1}%3600)/60))
    ((s=${1}%60))
    printf "%02d:%02d:%02d\n" $h $m $s
}

STARTTIME=$(date +%s)

#defaults
src="/"
dst="/mnt/backups"
mailgun="/usr/local/bin/mailgun-send.sh"
TO="copernicuscg@gmail.com"
FROM="admin@copernicuscg.com"
YYYYMMDD=`date +%Y%m%d-%H%M%S`
SUB="Daily backup - error - $YYYYMMDD"

# check if we are root. Otherwise exit!
if [ "$(id -u)" != "0" ]
then
    MSG="This script must be run as root!"
    $mailgun "$TO" "$FROM" "$SUB" "$MSG"
    exit 1
fi

# check if source folder exists
if [ ! -d "$src" ]; then
    MSG="$src does not exist."
    $mailgun "$TO" "$FROM" "$SUB" "$MSG"
    exit 1;
fi


## check if destination folder is mounted
if (! grep -qs "$dst" /proc/mounts); then
    MSG="$dst is not mounted."
    $mailgun "$TO" "$FROM" "$SUB" "$MSG"
    exit 0;
fi


pc=`cat /etc/hostname`
dst=${dst}/${pc}_backup/

# check if destination folder exists or create it
if [ ! -d "$dst" ]
then
    MSG="$dst does not exist."
    $mailgun "$TO" "$FROM" "$SUB" "$MSG"
    exit 0;
fi

# --archive: recurse and preserve almost everything.
# --hard-links: preserve hard links (not enabled by --archive).
# --acls: update destination ACLs to be the same as source ACLs.
# --xattrs: update destination extended attributes to be the same as source ones.
# --info=progress2: output statistics based on the whole transfer.
# --human-readable: more readable numbers.
# --exclude: don't copy files matching these patterns.
# --link-dest: hard link unchanged files from here (make incremental backups).

rsync -v --archive --delete --hard-links --acls --xattrs --info=progress2 --human-readable \
       --exclude={"/boot/","/lib/","/opt/","/dev/","/proc/","/sys/","/tmp/","/run/","/mnt/","/media/","/lost+found","/var/","/bin/","/sbin/",".thumbnails/",".cache/",".local/share/",".git/",".mozilla/"} \
       --log-file=/tmp/rsync-job.log \
       $src $dst

#rsync -v --archive --delete --hard-links --acls --xattrs --info=progress2 --human-readable \
#       --exclude={"/boot/", "/lib/", "/opt/",  "/dev/","/proc/","/sys/","/tmp/","/run/","/mnt/","/media/","/lost+found"} \
#       --exclude="/var/cache/" \
#       --exclude=".thumbnails/" \
#       --exclude=".cache/" \
#       --exclude=".local/share/" \
#       --exclude=".git/" \
#       --exclude=".mozilla/" \
#       --log-file=/tmp/rsync-job.log \
#       $src $dst

pkt="$date"_packages.txt
pacman -Qqe | sort > /tmp/"$pkt"
if [ $? -ne 0 ]; then
    MSG="Something went wrong reading the packet list and sorting it."
    $mailgun "$TO" "$FROM" "$SUB" "$MSG"
    exit 1
fi
scp /tmp/"$pkt" "$dst"/"$date"
if [ $? -ne 0 ]; then
    MSG="Something went wrong coping the packet list to $dst."
    $mailgun "$TO" "$FROM" "$SUB" "$MSG"
    exit 1
fi
rm -f /tmp/"$pkt"
if [ $? -ne 0 ]; then
    MSG="Something went wrong deleting the packet list."
    $mailgun "$TO" "$FROM" "$SUB" "$MSG"
    exit 1
fi

ENDTIME=$(date +%s)
seconds=$(($ENDTIME - $STARTTIME))

elapsed=$(formatsec $seconds)

SUB="Daily backup - success - $YYYYMMDD"
MSG="Daily backup successfully executed!

Source: $src
Destination: $dst

Time elapsed $elapsed on $YYYYMMDD.

Bye!
"
$mailgun "$TO" "$FROM" "$SUB" "$MSG"

#echo "backup done in $seconds" | mail -s "daily backup - success" copernicuscg@gmail.com

exit 0;

