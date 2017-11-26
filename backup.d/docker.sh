#!/bin/sh
#
# Backup Docker containers
#
# (C) 2016 Stefan Schallenberg
#
#############################################################################

##### backup_docker #########################################################
#############################################################################
function backup_docker {

if [ $# -ne 1 ]; then
    printf "%s backup_docker ERROR: Wrong number of parameters" "$0"
    return -1
    fi

local srv="$1"

#NB: Dumping to /tmp or /var/tmp does not work, maybe a bug in mariadb
#    anyhow, all directories in the path need to be writeable to user
#    mysql, so we use /var/lib.
local readonly DUMPDIR="/var/lib/docker.$(date +%Y%m%d)"
ssh $srv <<-EOF
	# This script will be executed on the Docker host (=Server)
	mkdir $DUMPDIR
	docker images --no-trunc >$DUMPDIR/images
EOF

backup_rsync --hist $srv:$DUMPDIR /srv/backup/docker.$srv "--ignore-times"
backup_rsync $srv:$DUMPDIR /srv/backup/data.uncrypt/docker.$srv "--ignore-times"

ssh $srv <<-EOF
	rm -rf $DUMPDIR
EOF

}

