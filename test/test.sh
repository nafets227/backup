#!/bin/bash
#
# Backup in Docker container
#
# (C) 2017 Stefan Schallenberg
#
# Test script


##### Test Executer ##########################################################
# Parameters:
#     1 - command in custom backup shell
#     2 - expected RC [default: 0]
function test_exec_backupdocker {
	cat >$TESTSETDIR/test_helper <<<"$1"  || return 100

	test_exec_simple \
		"docker run -v $TESTSETDIR/test_helper:/backup/backup nafets227/backup:test" \
		"$2" \
		"Backup Command \"$1\""

	return $?
}
	
##### Test Build #############################################################
function test_build {

	# Compile / Build docker
	test_exec_simple \
		"docker build -t nafets227/backup:test $BASEDIR/.." \
		0

	[ $TESTRC -eq 0 ] || return 1

	return 0
}

##### Test: no custom script #################################################
function test_runempty {
	test_exec_simple \
		"docker run nafets227/backup:test" \
		1
	
	return $?
}

##### Test: IMAP wrong password ##############################################
function test_imap {
	printf "Testing IMAP using Mail Adress \"%s\"\n" "$MAIL_ADR"
	test_exec_simple "[ ! -z \"$MAIL_ADR $MAIL_PW\" ]"
	if [ $TESTRC -eq 0 ] ; then
		# IMAP Wrong password
		test_exec_backupdocker  \
			 "backup_imap \"$MAIL_ADR\" 'wrongpassword'" \
			 1
		# IMAP OK
		test_exec_backupdocker  \
			 "backup_imap \"$MAIL_ADR\" \"$MAIL_PW\"" \
			 0
	fi

	return $?
}

##### Test x: remaining tests ################################################
function testx {
	mkdir $TESTSETDIR/test2
	cat >$TESTSETDIR/test2/backup <<-"EOF"
 		backup_imap "test-backup@nafets.dyndns.eu" "backup"

		backup_mysql "vSrv.dom.nafets.de" "dbFinance"
		backup_mysql_kube
 	
 		backup_rsync --hist "xen.intranet.nafets.de:/etc/libvirt" "/srv/backup/libvirt"
		backup_rsync "xen.intranet.nafets.de:/etc/libvirt" "/srv/backup/data.uncrypt/libvirt"

		backup_samba_domain "vDom.dom.nafets.de"
		backup_samba_conf "vDom.dom.nafets.de"
	
		EOF
 	
	docker run nafets227/backup:test -v $TESTSETDIR/test1/_backup:/backup/backup
	[ $? -eq 0 ] || return 1
	
	return 0
}

##### Main ###################################################################
BASEDIR=$(dirname $BASH_SOURCE)
. $BASEDIR/test-functions.sh || exit 1

testset_init || exit 1

if test_build ; then
	test_runempty
	test_imap
fi

testset_summary
exit $?
