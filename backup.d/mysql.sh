#!/bin/sh
#
# Backup Files
#
# (C) 2014-2015 Stefan Schallenberg
#
#############################################################################

##### backup_mysql ##########################################################
#############################################################################
function backup_mysql {

if [ $# -ne 2 ]; then
    printf "%s backup_mysql ERROR: Wrong number of parameters" "$0"
    return -1
    fi

local srv="$1"
local db="$2"

#NB: Dumping to /tmp or /var/tmp does not work, maybe a bug in mariadb
#    anyhow, all directories in the path need to be writeable to user
#    mysql, so we use /var/lib.
local readonly DUMPDIR="/var/lib/mysqldump.$(date +%Y%m%d)"
ssh $srv <<-EOF
	# This script will be executed on the DB Server
	mkdir -p $DUMPDIR
	chown mysql:mysql $DUMPDIR
	mysqldump --skip-comments -T$DUMPDIR $db 
EOF

backup_rsync --hist $srv:$DUMPDIR /srv/backup/mysql.$db.$srv "--ignore-times"
backup_rsync $srv:$DUMPDIR /srv/backup/data.uncrypt/mysql.$db.$srv "--ignore-times"

ssh $srv <<-EOF
	rm -rf $DUMPDIR
EOF

}

##### backup_mysql_docker ####################################################
function backup_mysql_docker {

if [ $# -ne 2 ]; then
    printf "%s backup_mysql ERROR: Wrong number of parameters" "$0"
    return -1
    fi

local srv="$1"
local cnt="$2"

#NB: Dumping to /tmp or /var/tmp does not work, maybe a bug in mariadb
#    anyhow, all directories in the path need to be writeable to user
#    mysql, so we use /var/lib.
local readonly DUMPDIR_CNT="/var/lib/mysqldump.$(date +%Y%m%d)"
local readonly DUMPDIR="/var/lib/mysqldump.$cnt.$(date +%Y%m%d)"
ssh $srv <<-EOSSH
	# This script will be executed on the DB Server
	docker exec -i $cnt /bin/bash <<-EODOCK
		# This script will be executed in the container on the DB Server
		mkdir -p $DUMPDIR_CNT
		chown mysql:mysql $DUMPDIR_CNT
		mysqldump -uroot -p"\\\$MYSQL_ROOT_PASSWORD" \
			--skip-comments \
			-T$DUMPDIR_CNT \
			\\\$MYSQL_DATABASE
		EODOCK
	mkdir $DUMPDIR
	docker cp $cnt:$DUMPDIR_CNT $DUMPDIR
	docker exec -i $cnt /bin/bash <<-EODOCK
		rm -rf $DUMPDIR_CNT
		EODOCK
	EOSSH

backup_rsync --hist $srv:$DUMPDIR /srv/backup/mysql.$cnt.$srv "--ignore-times"
backup_rsync $srv:$DUMPDIR /srv/backup/data.uncrypt/mysql.$cnt.$srv "--ignore-times"

ssh $srv <<-EOF
	rm -rf $DUMPDIR
	EOF

}

##### restore_mysql_docker ###################################################
# restore to MySQL in docker image
# prerequisites:
#    - Backup files need to be available in Docker image in path $dir=$3
#    - script must be running on docker host machine
function restore_mysql_docker {
if [ $# -ne 3 ]; then
    printf "%s restore_mysql_docker ERROR: Wrong number of parameters" "$0"
    return -1
    fi

local container="$1"
local db="$2"
local dir="$3"

#local readonly cmd_docker="cat"
local readonly cmd_docker="docker exec -i $container bash"

$cmd_docker <<-EOF
	#This script will be executed inside docker container
	cat >~/.my.cnf <<-EOFMY
		[client]
		password=\$MYSQL_ROOT_PASSWORD
		EOFMY
	echo "Creating Database $db if not exists."
	mysql -e "CREATE DATABASE IF NOT EXISTS $db;"
	for f in $dir/*.sql ; do 
	    echo "Executing \$f."
	    mysql $db <\$f
	done
	for f in $dir/*.txt ; do
	    echo "Loading Data from \$f."
	    mysql $db -e "LOAD DATA INFILE '\$f' INTO TABLE \$(basename \$f .txt);"
	done
	EOF

}

##### backup_mysql_kube ######################################################
function backup_mysql_kube {

#if [ $# -ne 2 ]; then
#    printf "%s backup_mysql ERROR: Wrong number of parameters" "$0"
#    return -1
#    fi

head=0;

kubectl --kubeconfig /root/.kube/config get -n prod pod -l svc=mariadb \
	-o custom-columns=NAME:.metadata.name,NAMEID:.spec.containers[].name \
	| while read pod name ; do
	if [ $head -eq 0 ] ; then
		head=1
		continue
	fi

	printf "Searching MySQl databases in Kubernetes POD %s (%s)\n" "$name" "$pod"

	dbs=$(kubectl --kubeconfig /root/.kube/config exec -i -n prod $pod /bin/bash <<-EOKUBE
		mysql -uroot -p"\$MYSQL_ROOT_PASSWORD" \
			 --skip-column-names \
		       	-e "show databases"
		EOKUBE
		)

	for db in $dbs ; do 
		case "$db" in
			information_schema|mysql|performance_schema)
			continue
		esac
		printf "Backing up MySQl databases %s in Kubernetes POD %s (%s)\n" "$db" "$name" "$pod"

		#NB: Dumping to /tmp or /var/tmp does not work, maybe a bug in mariadb
		#    anyhow, all directories in the path need to be writeable to user
		#    mysql, so we use /var/lib.
		local readonly DUMPDIR_CNT="/var/lib/mysqldump.$(date +%Y%m%d)"
		local readonly DUMPDIR="/var/lib/mysqldump.$(date +%Y%m%d)"
		kubectl --kubeconfig /root/.kube/config exec -i -n prod $pod /bin/bash <<-EOKUBE
			set -x
			# This script will be executed in the DB-container
			mkdir -p $DUMPDIR_CNT
			chown mysql:mysql $DUMPDIR_CNT
			mysqldump -uroot -p"\$MYSQL_ROOT_PASSWORD" \
				--skip-comments \
				-T$DUMPDIR_CNT \
				$db
			EOKUBE
		kubectl --kubeconfig /root/.kube/config cp prod/$pod:$DUMPDIR_CNT $DUMPDIR
		kubectl --kubeconfig /root/.kube/config exec -i -n prod $pod -- /bin/rm -rf $DUMPDIR_CNT

		backup_rsync --hist $DUMPDIR /srv/backup/mysql.$name.$db "--ignore-times"
		backup_rsync $DUMPDIR /srv/backup/data.uncrypt/mysql.$name.$db "--ignore-times"

		rm -rf $DUMPDIR
	done

done

}
