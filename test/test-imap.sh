#!/bin/bash
#
# Backup in Docker container
#
# (C) 2017-2020 Stefan Schallenberg
#
# Test script for IMAP

##### Tests for IMAP #########################################################
function test_imap {
	if ! test_assert_vars "MAIL_ADR" "MAIL_PW" "MAIL_SRV" ||
	   ! test_assert_tools "curl" "mailx" ; then
		printf "\tSkipping IMAP Tests.\n"
		return 0
	elif ! test_assert_tools "offlineimap" "jq" ; then
		printf "\tSkipping IMAP Remote Tests.\n"
		exec_remote=false
	elif which "ip" >/dev/null ; then
		my_ip="$USER@$(set -o pipefail
			ip -4 -j a show dev docker0 primary |
			jq '.[].addr_info[0].local')" &&
		my_ip=${my_ip//\"} &&
		exec_remote=true \
		|| return 1
	elif which "ipconfig" >/dev/null ; then
		my_ip="$USER@$(ipconfig getifaddr en0 en1)" &&
		test ! -z "$my_ip" &&
		exec_remote=true \
		|| return 1
	else
		printf "\tSkipping IMAP Remote Tests (ip/ipconfig).\n"
		exec_remote=false
	fi

	printf "Testing IMAP using Mail Adress \"%s\"\n" "$MAIL_ADR"

	local mail_smtpsrv=${MAIL_SRV%%:*}
	echo "wrongpassword" \
		>$TESTSETDIR/backup/imap_wrongpassword.password \
	       || return 1
	cp "$MAIL_PW" \
		$TESTSETDIR/backup/imap_password.password \
	       || return 1

	test_cleanImap "$MAIL_ADR" "$(cat $MAIL_PW)" "$mail_smtpsrv" || return 1

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
		--srcsecret /backup/imap_wrongpassword.password \
		--dstsecret /secrets/id_rsa

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
		--srcsecret /backup/imap_password.password \
		--dstsecret /secrets/id_rsa &&
	test_expect_files "backup-rem/INBOX/new" 0 &&
	test_expect_files "backup-rem/INBOX/cur" 0

	# IMAP KO without password
	cp "$MAIL_PW" \
		$TESTSETDIR/backup/$MAIL_ADR.password \
		|| return 1
	test_exec_backupdocker 1 \
		"backup imap" \
		"$MAIL_ADR" \
		/backup \
		"$MAIL_SRV"

	# IMAP KO without password remote
	$exec_remote &&
	test_exec_backupdocker 1 \
		"backup imap" \
		"$MAIL_ADR" \
		$my_ip:$TESTSETDIR/backup-rem \
		"$MAIL_SRV" \
		--dstsecret /secrets/id_rsa

	# Store Testmail
	test_putImap "$MAIL_ADR" "$(cat $MAIL_PW)" "$MAIL_SRV" \
		|| return 1

	# IMAP OK with one Mail
	test_exec_backupdocker 0 \
		"backup imap" \
		"$MAIL_ADR" \
		/backup \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password &&
	test_expect_files "backup/INBOX/new" 0 &&
	test_expect_files "backup/INBOX/cur" 1
	# @TODO test content of file

	# IMAP OK with one Mail in subdirectory
	test_exec_backupdocker 0 \
		"backup imap" \
		"$MAIL_ADR" \
		/backup/testimapsubdir \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password &&
	test_expect_files "backup/testimapsubdir/INBOX/new" 0 &&
	test_expect_files "backup/testimapsubdir/INBOX/cur" 1

	# IMAP OK with one Mail - remote backup dest
	$exec_remote &&
	test_exec_backupdocker 0 \
		"backup imap" \
		"$MAIL_ADR" \
		$my_ip:$TESTSETDIR/backup-rem \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password \
		--dstsecret /secrets/id_rsa &&
	test_expect_files "backup-rem/INBOX/new" 0 &&
	test_expect_files "backup-rem/INBOX/cur" 1

	test_cleanImap "$MAIL_ADR" "$(cat $MAIL_PW)" "$MAIL_SRV" || return 1

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
