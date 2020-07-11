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
	if [ "$#" -lt 1 ] ; then
		printf "Internal Error in %s - git %s parms (exp 1+)\n" \
			"$FUNCNAME" "$#"
		return 1
	elif [ ! -d $TESTSETDIR/backup ] ; then
		mkdir $TESTSETDIR/backup || return 1
	fi
	rc_exp="$1"
	shift

	cat >$TESTSETDIR/backup/backup <<<"$@"  || return 100

	local docker_cmd=""
	docker_cmd+="docker run"
	docker_cmd+=" -v $TESTSETDIR/backup:/backup"
	docker_cmd+=" -v ~/.ssh/id_rsa:/root/.ssh/id_rsa"
	docker_cmd+=" -e DEBUG=1"
	docker_cmd+=" nafets227/backup:test"

	test_exec_simple \
		"$docker_cmd" \
		"$rc_exp" \
		"Backup Command \"$*\""

	return $?
}

##### Send Test-Email to be backuped #########################################
function testimap_send_testmail {
	local mail_pwd mail_user
	mail_user="$(mailx -# <<<"urlcodec encode $MAIL_ADR")" &&
	mail_pwd="$(mailx -# <<<"urlcodec encode $MAIL_PW")" &&
	test_exec_sendmail "smtp://$mail_user:$mail_pwd@$MAIL_SRV" 0 \
		"$MAIL_ADR" "$MAIL_ADR" \
		"-S 'smtp-auth=plain' -S 'smtp-use-starttls'"

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

##### Tests for IMAP #########################################################
function test_imap {
	if ! test_assert_vars "MAIL_ADR" "MAIL_PW" "MAIL_SRV" ||
	   ! test_assert_tools "curl" "mailx" ; then
		printf "\tSkipping IMAP Tests.\n"
		return 0
	elif ! test_assert_tools "offlineimap" "ip" "jq" ; then
		printf "\tSkipping IMAP Remote Tests.\n"
		exec_remote=/bin/false
	else
		my_ip=$(ip -4 -j a show dev docker0 primary |
			jq '.[].addr_info[0].local')
		my_ip=${my_ip//\"}
		exec_remote=/bin/true
	fi

	printf "Testing IMAP using Mail Adress \"%s\"\n" "$MAIL_ADR"

	test_cleanImap "$MAIL_ADR" "$MAIL_PW" "$MAIL_SRV" || return 1

	# IMAP Wrong password
	test_exec_backupdocker 1 \
		"backup imap" \
		"$MAIL_ADR" \
		/backup \
		"$MAIL_SRV:143" \
		'wrongpassword'
	
	# IMAP OK with Empty Mailbox
	test_exec_backupdocker  0 \
		"backup imap" \
		"$MAIL_ADR" \
		/backup \
		"$MAIL_SRV:143" \
		"$MAIL_PW"
	test_expect_files "backup/INBOX/new" 0
	test_expect_files "backup/INBOX/cur" 0

	# IMAP OK with Empty Mailbox - remote backup target
	$exec_remote &&
	test_exec_backupdocker 0 \
		"backup imap" \
		"$MAIL_ADR" \
		$my_ip:$TESTSETDIR/backup-rem \
		"$MAIL_SRV:143" \
		"$MAIL_PW" &&
	test_expect_files "backup-rem/INBOX/new" 0 &&
	test_expect_files "backup-rem/INBOX/cur" 0

	# Send Testmail
	testimap_send_testmail || return 1

	# IMAP OK with one Mail
	test_exec_backupdocker 0 \
		"backup imap" \
		"$MAIL_ADR" \
		/backup \
		"$MAIL_SRV:143" \
		"$MAIL_PW"
	test_expect_files "backup/INBOX/new" 1
	test_expect_files "backup/INBOX/cur" 0
	# @TODO test content of file

	# IMAP OK with one Mail in subdirectory
	test_exec_backupdocker 0 \
		"backup imap" \
		"$MAIL_ADR" \
		/backup/testimapsubdir \
		"$MAIL_SRV:143" \
		"$MAIL_PW"
	test_expect_files "backup/testimapsubdir/INBOX/new" 1
	test_expect_files "backup/testimapsubdir/INBOX/cur" 0

	# IMAP OK with one Mail - remote backup target
	$exec_remote &&
	test_exec_backupdocker 0 \
		"backup imap" \
		"$MAIL_ADR" \
		$my_ip:$TESTSETDIR/backup-rem \
		"$MAIL_SRV:143" \
		"$MAIL_PW" &&
	test_expect_files "backup-rem/INBOX/new" 1 &&
	test_expect_files "backup-rem/INBOX/cur" 0

	test_cleanImap "$MAIL_ADR" "$MAIL_PW" "$MAIL_SRV" || return 1

	# IMAP OK with Empty Mailbox
	test_exec_backupdocker 0 \
		"backup imap" \
		"$MAIL_ADR" \
		/backup \
		"$MAIL_SRV:143" \
		"$MAIL_PW"
	test_expect_files "backup/INBOX/new" 0
	test_expect_files "backup/INBOX/cur" 0

	return 0
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
