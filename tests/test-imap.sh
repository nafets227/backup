#!/usr/bin/env bash
#
# Backup in Docker container
#
# (C) 2017-2020 Stefan Schallenberg
#
# Test script for IMAP

##### Tests for IMAP #########################################################
function test_imap {
	if \
		! test_is_cmdavail "curl" "$TEST_SNAIL"
	then
		printf "\tSkipping IMAP Tests.\n"
		return 0
	elif ! test_is_cmdavail "offlineimap" "jq" ; then
		printf "\tSkipping IMAP Remote Tests.\n"
		exec_remote=false
	elif [ -n "$my_ip" ] ; then
		exec_remote=true
	else
		test_expect_value "1" 0 "Skipping IMAP Remote Tests (ip/ipconfig)"
		exec_remote=false
	fi

	printf "Testing IMAP using Mail Address \"%s\"\n" "$TESTIMAP_SRC"

	local mail_smtpsrv=${TESTIMAP_URL%%:*}
	cat >"$TESTSET_DIR/backup/imap_wrongpassword.password" <<<"wrongpassword"

	cp "$TESTIMAP_SECRET" \
		"$TESTSET_DIR/backup/imap_password.password"

	test_cleanImap "$TESTIMAP_SRC" "$(cat "$TESTIMAP_SECRET")" "$mail_smtpsrv"

	# No password and default does not exist
	eval "$(test_exec_backupdocker 1 \
		"backup imap" \
		"$TESTIMAP_SRC" \
		/backup/imap \
		"$TESTIMAP_URL"
		)"

	# Not existing password file
	eval "$(test_exec_backupdocker 1 \
		"backup imap" \
		"$TESTIMAP_SRC" \
		/backup/imap \
		"$TESTIMAP_URL" \
		--srcsecret "filedoesnotexist"
		)"

	# IMAP Wrong password
	eval "$(test_exec_backupdocker 1 \
		"backup imap" \
		"$TESTIMAP_SRC" \
		/backup/imap \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_wrongpassword.password
		)"

	# IMAP Wrong password - remote backup dest
	if $exec_remote ; then
		eval "$(test_exec_backupdocker 1 \
			"backup imap" \
			"$TESTIMAP_SRC" \
			"$my_ip:$TESTSET_DIR/backup-rem/imap" \
			"$TESTIMAP_URL" \
			--srcsecret /backup/imap_wrongpassword.password \
			--dstsecret /secrets/id_rsa
			)"
	fi

	# IMAP OK with Empty Mailbox
	eval "$(test_exec_backupdocker  0 \
		"backup imap" \
		"$TESTIMAP_SRC" \
		/backup/imap \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password
		)"
	test_expect_filecount "backup/imap/INBOX/new" 0
	test_expect_filecount "backup/imap/INBOX/cur" 0

	# IMAP OK with Empty Mailbox - remote backup dest
	if $exec_remote ; then
		eval "$(test_exec_backupdocker 0 \
			"backup imap" \
			"$TESTIMAP_SRC" \
			"$my_ip:$TESTSET_DIR/backup-rem/imap" \
			"$TESTIMAP_URL" \
			--srcsecret /backup/imap_password.password \
			--dstsecret /secrets/id_rsa
			)"
		test_expect_filecount "backup-rem/imap/INBOX/new" 0
		test_expect_filecount "backup-rem/imap/INBOX/cur" 0
	fi

	# IMAP KO without password
	eval "$(test_exec_backupdocker 1 \
		"backup imap" \
		"$TESTIMAP_SRC" \
		/backup/imap \
		"$TESTIMAP_URL"
		)"

	# IMAP KO without password remote
	if $exec_remote ; then
		eval "$(test_exec_backupdocker 1 \
			"backup imap" \
			"$TESTIMAP_SRC" \
			"$my_ip:$TESTSET_DIR/backup-rem/imap" \
			"$TESTIMAP_URL" \
			--dstsecret /secrets/id_rsa
			)"
	fi

	# Store Testmail
	test_putImap "$TESTIMAP_SRC" "$(cat "$TESTIMAP_SECRET")" "$TESTIMAP_URL"

	# IMAP OK with one Mail
	eval "$(test_exec_backupdocker 0 \
		"backup imap" \
		"$TESTIMAP_SRC" \
		/backup/imap \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password
		)"
	test_expect_filecount "backup/imap/INBOX/new" 0
	test_expect_filecount "backup/imap/INBOX/cur" 1
	# @TODO test content of file

	# IMAP OK with one Mail in subdirectory
	eval "$(test_exec_backupdocker 0 \
		"backup imap" \
		"$TESTIMAP_SRC" \
		/backup/imap/testimapsubdir \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password
		)"
	test_expect_filecount "backup/imap/testimapsubdir/INBOX/new" 0
	test_expect_filecount "backup/imap/testimapsubdir/INBOX/cur" 1

	# IMAP OK with one Mail - remote backup dest
	if $exec_remote ; then
		eval "$(test_exec_backupdocker 0 \
			"backup imap" \
			"$TESTIMAP_SRC" \
			"$my_ip:$TESTSET_DIR/backup-rem/imap" \
			"$TESTIMAP_URL" \
			--srcsecret /backup/imap_password.password \
			--dstsecret /secrets/id_rsa
			)"
		test_expect_filecount "backup-rem/imap/INBOX/new" 0
		test_expect_filecount "backup-rem/imap/INBOX/cur" 1
	fi

	test_cleanImap "$TESTIMAP_SRC" "$(cat "$TESTIMAP_SECRET")" \
		"$TESTIMAP_URL"

	# IMAP OK with Empty Mailbox
	eval "$(test_exec_backupdocker 0 \
		"backup imap" \
		"$TESTIMAP_SRC" \
		/backup/imap \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password
		)"
	test_expect_filecount "backup/imap/INBOX/new" 0
	test_expect_filecount "backup/imap/INBOX/cur" 0

	return 0
}

##### Main ###################################################################
# do nothing
