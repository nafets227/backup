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
	if [ ! -d $TESTSETDIR/backup ] ; then
		mkdir $TESTSETDIR/backup || return 1
	fi
	cat >$TESTSETDIR/backup/backup <<<"$1"  || return 100

	local docker_cmd=""
	docker_cmd+="docker run"
	docker_cmd+=" -v $TESTSETDIR/backup:/backup"
	docker_cmd+=" -e DEBUG=1"
	docker_cmd+=" nafets227/backup:test"

	test_exec_simple \
		"$docker_cmd" \
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
	if [ -z "$MAIL_ADR" ] ||
	   [ -z "$MAIL_PW" ] ||
	   [ -z "$MAIL_SRV" ] ; then
		printf "Skipping IMAP Tests because %s is not set.\n" \
			"MAIL_ADR, MAIL_PW or MAIL_SRV"
		return 0
	fi

	printf "Testing IMAP using Mail Adress \"%s\"\n" "$MAIL_ADR"
	test_assert_tools "curl mailx" || return 1

	test_cleanImap "$MAIL_ADR" "$MAIL_PW" "$MAIL_SRV" || return 1

	# IMAP Wrong password
	test_exec_backupdocker  \
		 "backup imap \"$MAIL_ADR\" /backup \"$MAIL_SRV:143\" 'wrongpassword'" \
			 1
	# IMAP OK with Empty Mailbox
	test_exec_backupdocker  \
		 "backup imap \"$MAIL_ADR\" /backup \"$MAIL_SRV:143\" \"$MAIL_PW\"" \
			 0
	test_expect_files "backup/INBOX/new" 0
	test_expect_files "backup/INBOX/cur" 0

	local mail_pwd mail_user
	mail_user="$(mailx -# <<<"urlcodec encode $MAIL_ADR")"
	mail_pwd="$(mailx -# <<<"urlcodec encode $MAIL_PW")"
	test_exec_sendmail "smtp://$mail_user:$mail_pwd@$MAIL_SRV" 0 \
		"$MAIL_ADR" "$MAIL_ADR" \
		"-S 'smtp-auth=plain' -S 'smtp-use-starttls'"

	# IMAP OK with one Mail
	test_exec_backupdocker  \
		 "backup imap \"$MAIL_ADR\" /backup \"$MAIL_SRV:143\" \"$MAIL_PW\"" \
		 0
	test_expect_files "backup/INBOX/new" 1
	test_expect_files "backup/INBOX/cur" 0
	# @TODO test content of file

return 0
	# IMAP OK with one Mail in subdirectory
	test_exec_backupdocker  \
		 "backup imap \"$MAIL_ADR\" /backup/testimapsubdir \"$MAIL_SRV:143\" \"$MAIL_PW\"" \
			 0
	test_expect_files "backup/testimapsubdir/INBOX/new" 1
	test_expect_files "backup/testimapsubdir/INBOX/cur" 0

	test_cleanImap "$MAIL_ADR" "$MAIL_PW" "$MAIL_SRV" || return 1

	# IMAP OK with Empty Mailbox
	test_exec_backupdocker  \
		 "backup imap \"$MAIL_ADR\" /backup \"$MAIL_SRV:143\" \"$MAIL_PW\"" \
			 0
	test_expect_files "backup/INBOX/new" 0
	test_expect_files "backup/INBOX/cur" 0

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
