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
		"docker run -v $TESTSETDIR/test_helper:/backup/backup -e DEBUG=1 nafets227/backup:test" \
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
	test_assert_tools "curl mailx" || return 1

	test_exec_simple "[ ! -z \"$MAIL_ADR $MAIL_PW\" ]"
	if [ $TESTRC -eq 0 ] ; then
		test_cleanImap "$MAIL_ADR" "$MAIL_PW" "$MAIL_SRV" || return 1

		# IMAP Wrong password
		test_exec_backupdocker  \
			 "backup imap \"$MAIL_ADR\" /backup/imap/test1 \"$MAIL_SRV:143\" 'wrongpassword'" \
			 1
		# IMAP OK with Empty Mailbox
		test_exec_backupdocker  \
			 "backup imap \"$MAIL_ADR\" /backup/imap/test2  \"$MAIL_SRV:143\" \"$MAIL_PW\"" \
			 0

		local mail_pwd mail_user
		mail_user="$(mailx -# <<<"urlcodec encode $MAIL_ADR")"
		mail_pwd="$(mailx -# <<<"urlcodec encode $MAIL_PW")"
		test_exec_sendmail "smtp://$mail_user:$mail_pwd@$MAIL_SRV" 0 \
			"$MAIL_ADR" "$MAIL_ADR" \
			"-S 'smtp-auth=plain' -S 'smtp-use-starttls'"

		# IMAP OK with one Mail
		test_exec_backupdocker  \
			 "backup imap \"$MAIL_ADR\" /backup/imap/test3 \"$MAIL_SRV:143\" \"$MAIL_PW\"" \
			 0

	else
		printf "Skipping IMAP Tests because MAIL_ADR or MAIL_PW is not set.\n"
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
. $BASEDIR/../util/test-functions.sh || exit 1

testset_init || exit 1

if test_build ; then
	test_runempty
	test_imap
fi

testset_summary
exit $?
