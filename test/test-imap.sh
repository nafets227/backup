#!/bin/bash
#
# Backup in Docker container
#
# (C) 2017-2020 Stefan Schallenberg
#
# Test script for IMAP


##### Send Test-Email to be backuped #########################################
function testimap_send_testmail {
	local mail_pwd mail_user mail_smtpsrv
	mail_user="$(mailx -# <<<"urlcodec encode $MAIL_ADR")" &&
	mail_pwd="$(mailx -# <<<"urlcodec encode $MAIL_PW")" &&
	mail_smtpsrv=${MAIL_SRV%%:*}
	test_exec_sendmail "smtp://$mail_user:$mail_pwd@$mail_smtpsrv" 0 \
		"$MAIL_ADR" "$MAIL_ADR" \
		"-S 'smtp-auth=plain' -S 'smtp-use-starttls'"
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

	local mail_smtpsrv=${MAIL_SRV%%:*}
	echo "wrongpassword" \
		>$TESTSETDIR/backup/imap_wrongpassword.password \
	       || return 1
	echo "$MAIL_PW" \
		>$TESTSETDIR/backup/imap_password.password \
	       || return 1

	test_cleanImap "$MAIL_ADR" "$MAIL_PW" "$mail_smtpsrv" || return 1

	# No password and default does not exist
	test_exec_backupdocker 1 \
		"backup imap" \
		"$MAIL_ADR" \
		/backup \
		"$MAIL_SRV"

	# Not existing password file
	test_exec_backupdocker 1 \
		"backup imap" \
		"$MAIL_ADR" \
		/backup \
		"$MAIL_SRV" \
		--srcsecret "filedoesnotexist"

	# IMAP Wrong password
	test_exec_backupdocker 1 \
		"backup imap" \
		"$MAIL_ADR" \
		/backup \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_wrongpassword.password
	
	# IMAP Wrong password - remote backup dest
	$exec_remote &&
	test_exec_backupdocker 1 \
		"backup imap" \
		"$MAIL_ADR" \
		$my_ip:$TESTSETDIR/backup-rem \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_wrongpassword.password

	# IMAP OK with Empty Mailbox
	test_exec_backupdocker  0 \
		"backup imap" \
		"$MAIL_ADR" \
		/backup \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password &&
	test_expect_files "backup/INBOX/new" 0 &&
	test_expect_files "backup/INBOX/cur" 0

	# IMAP OK with Empty Mailbox - remote backup dest
	$exec_remote &&
	test_exec_backupdocker 0 \
		"backup imap" \
		"$MAIL_ADR" \
		$my_ip:$TESTSETDIR/backup-rem \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password &&
	test_expect_files "backup-rem/INBOX/new" 0 &&
	test_expect_files "backup-rem/INBOX/cur" 0

	# IMAP OK with default password
	echo "$MAIL_PW" \
		>$TESTSETDIR/backup/$MAIL_ADR.password \
		|| return 1
	test_exec_backupdocker 0 \
		"backup imap" \
		"$MAIL_ADR" \
		/backup \
		"$MAIL_SRV"

	# IMAP OK with default password remote
	test_exec_backupdocker 0 \
		"backup imap" \
		"$MAIL_ADR" \
		$my_ip:$TESTSETDIR/backup-rem \
		"$MAIL_SRV"

	# Send Testmail
	testimap_send_testmail || return 1

	# IMAP OK with one Mail
	test_exec_backupdocker 0 \
		"backup imap" \
		"$MAIL_ADR" \
		/backup \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password &&
	test_expect_files "backup/INBOX/new" 1 &&
	test_expect_files "backup/INBOX/cur" 0
	# @TODO test content of file

	# IMAP OK with one Mail in subdirectory
	test_exec_backupdocker 0 \
		"backup imap" \
		"$MAIL_ADR" \
		/backup/testimapsubdir \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password &&
	test_expect_files "backup/testimapsubdir/INBOX/new" 1 &&
	test_expect_files "backup/testimapsubdir/INBOX/cur" 0

	# IMAP OK with one Mail - remote backup dest
	$exec_remote &&
	test_exec_backupdocker 0 \
		"backup imap" \
		"$MAIL_ADR" \
		$my_ip:$TESTSETDIR/backup-rem \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password &&
	test_expect_files "backup-rem/INBOX/new" 1 &&
	test_expect_files "backup-rem/INBOX/cur" 0

	test_cleanImap "$MAIL_ADR" "$MAIL_PW" "$MAIL_SRV" || return 1

	# IMAP OK with Empty Mailbox
	test_exec_backupdocker 0 \
		"backup imap" \
		"$MAIL_ADR" \
		/backup \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password &&
	test_expect_files "backup/INBOX/new" 0 &&
	test_expect_files "backup/INBOX/cur" 0

	return 0
}

##### Main ###################################################################
# do nothing
