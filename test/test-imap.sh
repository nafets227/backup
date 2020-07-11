#!/bin/bash
#
# Backup in Docker container
#
# (C) 2017-2020 Stefan Schallenberg
#
# Test script for IMAP


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

##### Main ###################################################################
# do nothing
