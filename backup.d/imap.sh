#!/bin/sh
#
# Backup Files
#
# (C) 2013 Stefan Schallenberg
#

##### backup_imap ############################################################
function backup_imap {
local email="${1,,}" # converto to lowercase
local password="$2"
local emailuser="${email%%@*}"
local emaildomain="${email##*@}"
local imapcfg="$(mktemp -t .offlineimaprc.${emailuser}-XXXXXXXXXX)"

if [ x"$DEBUG" == x1 ] ; then
	printf "DEBUG: %s %s\n" "$FUNCNAME" "$*"
fi

if [ "$#" -ge 3 ]; then
    server="${3%%:*}"
    port=${3:$((${#server} + 1))}
    port=${port:-993}
    if [ "$port" == "143" ] ; then
	    ssl="no"
    else
	    ssl="yes"
    fi
else case "$emaildomain" in
    1und1.de | nafets.de | stevro.de )
        server="imap.1und1.de"
	port="993"
	ssl="yes"
        ;;
    intranet.nafets.de | nafets.dyndns.eu )
        server="nafets.dyndns.eu"
	port="143"
	ssl="no"
        ;;
    gmail.com | googlemail.com )
        server="imap.gmail.com"
	port="993"
	ssl="no"
        ;;
    * )
        printf "Error: Server not given and domain \"%s\" unknown\n" \
            "$emaildomain"
        return -1
    esac
fi


cat >$imapcfg <<-EOF
	# OfflineIMAP configuration
	#
	# (C) 2012-2015 Stefan Schallenberg
	# Generated by ${BASH_SOURCE##*/}

	[general]
	accounts = $emailuser 

	[Account $emailuser]
	localrepository = ${emailuser}Local
	remoterepository = ${emailuser}Remote

	[Repository ${emailuser}Local]
	type = Maildir
	localfolders = /srv/backup/data.imap/$email

	[Repository ${emailuser}Remote]
	type = IMAP
	readonly = True
	remotehost = $server
	remoteport = $port
	ssl = $ssl
	remoteuser = $email
	remotepass = $password
	subscribedonly = no
	EOF

offlineimap -c $imapcfg || return 1

return 0
}

