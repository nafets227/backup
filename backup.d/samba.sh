#!/bin/sh
#
# Backup Files
# Base functions
#
# (C) 2014-2015 Stefan Schallenberg
#
#############################################################################

##### backup_samba_domain ###################################################
#####     Backup Domain Database (aka Active Directory )                #####
#############################################################################
function backup_samba_domain {
	if [ x"$DEBUG" == x1 ] ; then
		printf "DEBUG: %s %s\n" "$FUNCNAME" "$*"
	fi

	srv="$1"

	if [ -z "$1" ] ; then
		printf "Parameter 1 MUST be set.\n"
		return 1
	fi

	# Save Samba Domain Setup-Data
	echo "Dumping Samba Config-Data"
	ssh $srv <<-EOF
		##### Backup SAMBA Server ###################################################
		for ldb in \$(find /var/lib/samba/private -name "*.ldb"); do
			tdbbackup \$ldb 1>/dev/null
			if [ \$? -ne 0 ]; then
				echo "Error while backuping \$ldb" >2
				exit 1
			else
				echo "Successfully backuped \$ldb" >2
			fi
		done
		EOF
	backup_rsync --hist $srv:/var/lib/samba /srv/backup/samba.domain "--exclude=**/*.ldb"
	backup_rsync $srv:/var/lib/samba /srv/backup/data.uncrypt/samba.domain "--exclude=**/*.ldb"
}

##### backup_samba_conf #####################################################
#####     Backup Samba confirmation of single machine (smb.conf etc.)   #####
#############################################################################
function backup_samba_conf {
	if [ x"$DEBUG" == x1 ] ; then
		printf "DEBUG: %s %s\n" "$FUNCNAME" "$*"
	fi

	srv="$1"
	backup_rsync --hist $srv:/etc/samba /srv/backup/samba.$srv
	backup_rsync $srv:/etc/samba /srv/backup/data.uncrypt/samba.$srv
}
