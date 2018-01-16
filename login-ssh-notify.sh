#!/usr/bin/env bash

# Source
#  https://askubuntu.com/questions/179889/how-do-i-set-up-an-email-alert-when-a-ssh-login-is-successful

# Add in '/etc/pam.d/sshd' the following line
# session optional pam_exec.so seteuid /path/to/login-notify.sh
#
# The module above is include as 'optional'.
# If after a test, there is no problem, change 'optional' to 'required'
#

# Change these two lines:
sender=""
recepient=""

if [ "$PAM_TYPE" != "close_session" ]; then
    host="`hostname`"
    subject="SSH Login: $PAM_USER from $PAM_RHOST on $host"
    # Message to send, e.g. the current environment variables.
    message="`env`"
    echo "$message" | mailx -r "$sender" -s "$subject" "$recepient"
fi
