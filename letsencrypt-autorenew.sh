#!/usr/bin/env bash


_domain="domain.com"
_certbot=/usr/bin/certbot
_systemctl=/usr/bin/systemctl
_sendmail=/usr/bin/sendmail

test -x $_certbot || exit 0
test -x $_systemctl || exit 0
test -x $_sendmail || exit 0

# 'set -e' causes the shell to exit if any subcommand or pipeline returns a non-zero status.
set -e

# check if we are root. Otherwise exit!
if [ "$(id -u)" != "0" ]
then
	echo "This script must be run as root!" 1>&2
	exit 1
fi

_from=""
_to=""
_subject=""

_logfile=~/letsencrypt-autorenew.log

#----------------------------------------------------------------

exec >> $_logfile 2>&1

echo ""
echo "#########################################################################"
date
echo ""
echo ""

#----------------------------------------------------------------

echo "   Checking if it is needed to renew certificates..."
$_certbot renew --quiet --agree-tos

# Check for an altered certificate (means there was a renew)
_file="/etc/letsencrypt/live/"$_domain"/fullchain.pem"

if test `find $_file -mmin -2`     # file last time modified was 2 min ago or less
then
    echo "   restarting httpd/postfix/dovecot"
    # Reload appache
    $_systemctl restart httpd
    # Reload postfix
    $_systemctl restart postfix
    # Restart dovecot
    $_systemctl restart dovecot

    sleep 10

    _content="   Let's Encrypt certificates have been renewed!"
else
    _content="   No need to renew Let's Encrypt certificates"
fi


# https://github.com/leemunroe/responsive-html-email-template
# For an API like Mailgun you need to put the CSS inline. You can use Premailer to do this automatically.
_var2=$(</home/atreyu/templates/email_letsencrypt-autorenew.inline)


_var2=$(echo $_var2 | sed -e "s/??VAR1??/$_content/g")
_var2=$(echo $_var2 | sed -e "s/??VAR2??/https:\/\/copernicuscg.com/g")
_var2=$(echo $_var2 | sed -e "s/??VAR3??/Copernicus CG/g")
_var2=$(echo $_var2 | sed -e "s/??VAR4??/https:\/\/copernicuscg.com/g")

_text=$(cat <<END_HEADERS
From: $_from
To: $_to
Subject: $_subject
MIME-Version: 1.0;
Content-Type: text/html;

$_var2
END_HEADERS
)

$_sendmail -t <<< "$_text"

echo ""
exit 0
