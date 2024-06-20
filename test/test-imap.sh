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
	   ! test_assert_tools "curl" "$TEST_SNAIL" ; then
		printf "\tSkipping IMAP Tests.\n"
		return 0
	elif ! test_assert_tools "offlineimap" "jq" ; then
		printf "\tSkipping IMAP Remote Tests.\n"
		exec_remote=false
	elif [ -n "$my_ip" ] ; then
		exec_remote=true
	else
		test_assert "1" "Skipping IMAP Remote Tests (ip/ipconfig)"
		exec_remote=false
	fi

	printf "Testing IMAP using Mail Adress \"%s\"\n" "$MAIL_ADR"

	local mail_smtpsrv=${MAIL_SRV%%:*}
	cat >"$TESTSETDIR/backup/imap_wrongpassword.password" <<<"wrongpassword"
	test_assert "$?" "write imap_wrongpassword.password" || return 1

	cp "$MAIL_PW" \
		"$TESTSETDIR/backup/imap_password.password"
	test_assert "$?" "write imap_password.password" || return 1

	test_cleanImap "$MAIL_ADR" "$(cat "$MAIL_PW")" "$mail_smtpsrv"
	test_assert "$?" "clean IMAP" || return 1
	
	# No password and default does not exist
	eval "$(test_exec_backupdocker 1 \
		"backup imap" \
		"$MAIL_ADR" \
		/backup/imap \
		"$MAIL_SRV"
		)"

	# Not existing password file
	eval "$(test_exec_backupdocker 1 \
		"backup imap" \
		"$MAIL_ADR" \
		/backup/imap \
		"$MAIL_SRV" \
		--srcsecret "filedoesnotexist"
		)"

	# IMAP Wrong password
	eval "$(test_exec_backupdocker 1 \
		"backup imap" \
		"$MAIL_ADR" \
		/backup/imap \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_wrongpassword.password
		)"
	
	# IMAP Wrong password - remote backup dest
	$exec_remote &&
	eval "$(test_exec_backupdocker 1 \
		"backup imap" \
		"$MAIL_ADR" \
		"$my_ip:$TESTSETDIR/backup-rem/imap" \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_wrongpassword.password \
		--dstsecret /secrets/id_rsa
		)"

	# IMAP OK with Empty Mailbox
	eval "$(test_exec_backupdocker  0 \
		"backup imap" \
		"$MAIL_ADR" \
		/backup/imap \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password
		)" &&
	test_expect_files "backup/imap/INBOX/new" 0 &&
	test_expect_files "backup/imap/INBOX/cur" 0

	# IMAP OK with Empty Mailbox - remote backup dest
	$exec_remote &&
	eval "$(test_exec_backupdocker 0 \
		"backup imap" \
		"$MAIL_ADR" \
		"$my_ip:$TESTSETDIR/backup-rem/imap" \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password \
		--dstsecret /secrets/id_rsa
		)" &&
	test_expect_files "backup-rem/imap/INBOX/new" 0 &&
	test_expect_files "backup-rem/imap/INBOX/cur" 0

	# IMAP KO without password
	cp "$MAIL_PW" \
		"$TESTSETDIR/backup/$MAIL_ADR.password"
	test_assert "$?" "copy mail password" || return 1
	eval "$(test_exec_backupdocker 1 \
		"backup imap" \
		"$MAIL_ADR" \
		/backup/imap \
		"$MAIL_SRV"
		)"

	# IMAP KO without password remote
	$exec_remote &&
	eval "$(test_exec_backupdocker 1 \
		"backup imap" \
		"$MAIL_ADR" \
		"$my_ip:$TESTSETDIR/backup-rem/imap" \
		"$MAIL_SRV" \
		--dstsecret /secrets/id_rsa
		)"

	# Store Testmail
	test_putImap "$MAIL_ADR" "$(cat "$MAIL_PW")" "$MAIL_SRV"
	test_assert "$?" "store testmail" || return 1

	# IMAP OK with one Mail
	eval "$(test_exec_backupdocker 0 \
		"backup imap" \
		"$MAIL_ADR" \
		/backup/imap \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password
		)" &&
	test_expect_files "backup/imap/INBOX/new" 0 &&
	test_expect_files "backup/imap/INBOX/cur" 1
	# @TODO test content of file

	# IMAP OK with one Mail in subdirectory
	eval "$(test_exec_backupdocker 0 \
		"backup imap" \
		"$MAIL_ADR" \
		/backup/imap/testimapsubdir \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password
		)" &&
	test_expect_files "backup/imap/testimapsubdir/INBOX/new" 0 &&
	test_expect_files "backup/imap/testimapsubdir/INBOX/cur" 1

	# IMAP OK with one Mail - remote backup dest
	$exec_remote &&
	eval "$(test_exec_backupdocker 0 \
		"backup imap" \
		"$MAIL_ADR" \
		"$my_ip:$TESTSETDIR/backup-rem/imap" \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password \
		--dstsecret /secrets/id_rsa
		)" &&
	test_expect_files "backup-rem/imap/INBOX/new" 0 &&
	test_expect_files "backup-rem/imap/INBOX/cur" 1

	test_cleanImap "$MAIL_ADR" "$(cat "$MAIL_PW")" "$MAIL_SRV" || return 1

	# IMAP OK with Empty Mailbox
	eval "$(test_exec_backupdocker 0 \
		"backup imap" \
		"$MAIL_ADR" \
		/backup/imap \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password
		)" &&
	test_expect_files "backup/imap/INBOX/new" 0 &&
	test_expect_files "backup/imap/INBOX/cur" 0

	return 0
}

##### Main ###################################################################
# do nothing
