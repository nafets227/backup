#!/usr/bin/env bash
#
# Backup in Docker container
#
# (C) 2017-2020 Stefan Schallenberg
#
# Test script for IMAP

##### Tests for IMAP #########################################################
function test_imap {
	printf "Testing IMAP using Mail Address \"%s\"\n" "$TESTIMAP_SRC"

	local mail_smtpsrv=${TESTIMAP_URL%%:*}
	cat >"$TESTSET_DIR/backup/imap_wrongpassword.password" <<<"wrongpassword"

	cp "$TESTIMAP_SECRET" \
		"$TESTSET_DIR/backup/imap_password.password"

	test_cleanImap "$TESTIMAP_SRC" "$(cat "$TESTIMAP_SECRET")" "$mail_smtpsrv"

	# No password and default does not exist
	test_exec_backupdocker 1 \
		"backup imap" \
		"$TESTIMAP_SRC" \
		/backup/imap \
		"$TESTIMAP_URL"

	# Not existing password file
	test_exec_backupdocker 1 \
		"backup imap" \
		"$TESTIMAP_SRC" \
		/backup/imap \
		"$TESTIMAP_URL" \
		--srcsecret "filedoesnotexist"

	# IMAP Wrong password
	test_exec_backupdocker 1 \
		"backup imap" \
		"$TESTIMAP_SRC" \
		/backup/imap \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_wrongpassword.password

	# IMAP Wrong password - remote backup dest
	test_exec_backupdocker 1 \
		"backup imap" \
		"$TESTIMAP_SRC" \
		"$my_ip:$TESTSET_DIR/backup-rem/imap" \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_wrongpassword.password \
		--dstsecret /secrets/id_ed25519

	# IMAP OK with Empty Mailbox
	test_exec_backupdocker  0 \
		"backup imap" \
		"$TESTIMAP_SRC" \
		/backup/imap \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password
	test_expect_filecount "backup/imap/INBOX/new" 0
	test_expect_filecount "backup/imap/INBOX/cur" 0

	# IMAP OK with Empty Mailbox - remote backup dest
	test_exec_backupdocker 0 \
		"backup imap" \
		"$TESTIMAP_SRC" \
		"$my_ip:$TESTSET_DIR/backup-rem/imap" \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password \
		--dstsecret /secrets/id_ed25519
	test_expect_filecount "backup-rem/imap/INBOX/new" 0
	test_expect_filecount "backup-rem/imap/INBOX/cur" 0

	# IMAP KO without password
	test_exec_backupdocker 1 \
		"backup imap" \
		"$TESTIMAP_SRC" \
		/backup/imap \
		"$TESTIMAP_URL"

	# IMAP KO without password remote
	test_exec_backupdocker 1 \
		"backup imap" \
		"$TESTIMAP_SRC" \
		"$my_ip:$TESTSET_DIR/backup-rem/imap" \
		"$TESTIMAP_URL" \
		--dstsecret /secrets/id_ed25519

	# Store Testmail
	test_putImap "$TESTIMAP_SRC" "$(cat "$TESTIMAP_SECRET")" "$TESTIMAP_URL"

	# IMAP OK with one Mail
	test_exec_backupdocker 0 \
		"backup imap" \
		"$TESTIMAP_SRC" \
		/backup/imap \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password
	test_expect_filecount "backup/imap/INBOX/new" 0
	test_expect_filecount "backup/imap/INBOX/cur" 1
	# @TODO test content of file

	# IMAP OK with one Mail in subdirectory
	test_exec_backupdocker 0 \
		"backup imap" \
		"$TESTIMAP_SRC" \
		/backup/imap/testimapsubdir \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password
	test_expect_filecount "backup/imap/testimapsubdir/INBOX/new" 0
	test_expect_filecount "backup/imap/testimapsubdir/INBOX/cur" 1

	# IMAP OK with one Mail - remote backup dest
	test_exec_backupdocker 0 \
		"backup imap" \
		"$TESTIMAP_SRC" \
		"$my_ip:$TESTSET_DIR/backup-rem/imap" \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password \
		--dstsecret /secrets/id_ed25519
	test_expect_filecount "backup-rem/imap/INBOX/new" 0
	test_expect_filecount "backup-rem/imap/INBOX/cur" 1

	test_cleanImap "$TESTIMAP_SRC" "$(cat "$TESTIMAP_SECRET")" \
		"$TESTIMAP_URL"

	# IMAP OK with Empty Mailbox
	test_exec_backupdocker 0 \
		"backup imap" \
		"$TESTIMAP_SRC" \
		/backup/imap \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password
	test_expect_filecount "backup/imap/INBOX/new" 0
	test_expect_filecount "backup/imap/INBOX/cur" 0

	return 0
}

##### Main ###################################################################
# do nothing
: "${my_ip:=""}"
test_expect_vardefined \
	TESTIMAP_SRC \
	TESTIMAP_SECRET \
	TESTIMAP_URL
