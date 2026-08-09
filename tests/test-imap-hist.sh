#!/usr/bin/env bash
#
# Backup in Docker container
#
# (C) 2017-2020 Stefan Schallenberg
#
# Test script for IMAP with history

##### Tests for IMAP with history ############################################
function test_imap_hist {

	printf "Testing IMAP History using Mail Address \"%s\"\n" "$TESTIMAP_SRC"

	local mail_smtpsrv=${TESTIMAP_URL%%:*}
	cp "$TESTIMAP_SECRET" \
		"$TESTSET_DIR/backup/imap_password.password"

	test_cleanImap "$TESTIMAP_SRC" "$(cat "$TESTIMAP_SECRET")" "$mail_smtpsrv"

	# IMAP OK with Empty Mailbox 2020-06-15
	test_exec_backupdocker  0 \
		"backup imap" \
		--hist \
		--histdate "2020-06-15" \
		"$TESTIMAP_SRC" \
		/backup/imap-hist \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password
	test_expect_filecount "backup/imap-hist/2020/06/15/INBOX/new" 0
	test_expect_filecount "backup/imap-hist/2020/06/15/INBOX/cur" 0

	# IMAP OK with Empty Mailbox 2020-06-15 - remote backup dest
	test_exec_backupdocker 0 \
		"backup imap" \
		--hist \
		--histdate "2020-06-15" \
		"$TESTIMAP_SRC" \
		"$my_ip:$TESTSET_DIR/backup-rem/imap-hist" \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password \
		--dstsecret /secrets/id_rsa
	test_expect_filecount "backup-rem/imap-hist/2020/06/15/INBOX/new" 0
	test_expect_filecount "backup-rem/imap-hist/2020/06/15/INBOX/cur" 0

	# Store Testmail
	test_putImap "$TESTIMAP_SRC" "$(cat "$TESTIMAP_SECRET")" "$TESTIMAP_URL"

	# IMAP OK with 1 Mail overwrite 2020-06-15
	test_exec_backupdocker  0 \
		"backup imap" \
		--hist \
		--histdate "2020-06-15" \
		"$TESTIMAP_SRC" \
		/backup/imap-hist \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password
	test_expect_filecount "backup/imap-hist/2020/06/15/INBOX/new" 0
	test_expect_filecount "backup/imap-hist/2020/06/15/INBOX/cur" 1

	# IMAP OK with 1 Mail overwrite 2020-06-15 - remote backup dest
	test_exec_backupdocker 0 \
		"backup imap" \
		--hist \
		--histdate "2020-06-15" \
		"$TESTIMAP_SRC" \
		"$my_ip:$TESTSET_DIR/backup-rem/imap-hist" \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password \
		--dstsecret /secrets/id_rsa
	test_expect_filecount "backup-rem/imap-hist/2020/06/15/INBOX/new" 0
	test_expect_filecount "backup-rem/imap-hist/2020/06/15/INBOX/cur" 1

	# IMAP OK with 1 Mail 2020-06-16
	test_exec_backupdocker  0 \
		"backup imap" \
		--hist \
		--histdate "2020-06-16" \
		"$TESTIMAP_SRC" \
		/backup/imap-hist \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password
	test_expect_filecount "backup/imap-hist/2020/06/16/INBOX/new" 0
	test_expect_filecount "backup/imap-hist/2020/06/16/INBOX/cur" 1
	test_expect_linkedfiles \
		"$TESTSET_DIR/backup/imap-hist/2020/06/16/INBOX/cur"/* \
		"$TESTSET_DIR/backup/imap-hist/2020/06/15/INBOX/cur"/*

	# IMAP OK with 1 Mail 2020-06-16 - remote backup dest
	test_exec_backupdocker 0 \
		"backup imap" \
		--hist \
		--histdate "2020-06-16" \
		"$TESTIMAP_SRC" \
		"$my_ip:$TESTSET_DIR/backup-rem/imap-hist" \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password \
		--dstsecret /secrets/id_rsa
	test_expect_filecount "backup-rem/imap-hist/2020/06/16/INBOX/new" 0
	test_expect_filecount "backup-rem/imap-hist/2020/06/16/INBOX/cur" 1
	test_expect_linkedfiles \
		"$TESTSET_DIR/backup-rem/imap-hist/2020/06/16/INBOX/cur"/* \
		"$TESTSET_DIR/backup-rem/imap-hist/2020/06/15/INBOX/cur"/*

	# IMAP OK with 1 Mail 2020-07-15
	test_exec_backupdocker  0 \
		"backup imap" \
		--hist \
		--histdate "2020-07-15" \
		"$TESTIMAP_SRC" \
		/backup/imap-hist \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password
	test_expect_filecount "backup/imap-hist/2020/07/15/INBOX/new" 0
	test_expect_filecount "backup/imap-hist/2020/07/15/INBOX/cur" 1
	test_expect_linkedfiles \
		"$TESTSET_DIR/backup/imap-hist/2020/07/15/INBOX/cur"/* \
		"$TESTSET_DIR/backup/imap-hist/2020/06/16/INBOX/cur"/* \
		"$TESTSET_DIR/backup/imap-hist/2020/06/15/INBOX/cur"/*

	# IMAP OK with 1 Mail 2020-07-15 - remote backup dest
	test_exec_backupdocker 0 \
		"backup imap" \
		--hist \
		--histdate "2020-07-15" \
		"$TESTIMAP_SRC" \
		"$my_ip:$TESTSET_DIR/backup-rem/imap-hist" \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password \
		--dstsecret /secrets/id_rsa
	test_expect_filecount "backup-rem/imap-hist/2020/07/15/INBOX/new" 0
	test_expect_filecount "backup-rem/imap-hist/2020/07/15/INBOX/cur" 1
	test_expect_linkedfiles \
		"$TESTSET_DIR/backup-rem/imap-hist/2020/07/15/INBOX/cur"/* \
		"$TESTSET_DIR/backup-rem/imap-hist/2020/06/16/INBOX/cur"/* \
		"$TESTSET_DIR/backup-rem/imap-hist/2020/06/15/INBOX/cur"/*

	# IMAP OK with one Mail 2021-01-15
	test_exec_backupdocker  0 \
		"backup imap" \
		--hist \
		--histdate "2021-01-15" \
		"$TESTIMAP_SRC" \
		/backup/imap-hist \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password
	test_expect_filecount "backup/imap-hist/2021/01/15/INBOX/new" 0
	test_expect_filecount "backup/imap-hist/2021/01/15/INBOX/cur" 1
	test_expect_linkedfiles \
		"$TESTSET_DIR/backup/imap-hist/2021/01/15/INBOX/cur"/* \
		"$TESTSET_DIR/backup/imap-hist/2020/07/15/INBOX/cur"/* \
		"$TESTSET_DIR/backup/imap-hist/2020/06/16/INBOX/cur"/* \
		"$TESTSET_DIR/backup/imap-hist/2020/06/15/INBOX/cur"/*

	# IMAP OK with one Mail 2021-01-15 - remote backup dest
	test_exec_backupdocker 0 \
		"backup imap" \
		--hist \
		--histdate "2021-01-15" \
		"$TESTIMAP_SRC" \
		"$my_ip:$TESTSET_DIR/backup-rem/imap-hist" \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password \
		--dstsecret /secrets/id_rsa
	test_expect_filecount "backup-rem/imap-hist/2021/01/15/INBOX/new" 0
	test_expect_filecount "backup-rem/imap-hist/2021/01/15/INBOX/cur" 1
	test_expect_linkedfiles \
		"$TESTSET_DIR/backup-rem/imap-hist/2021/01/15/INBOX/cur"/* \
		"$TESTSET_DIR/backup-rem/imap-hist/2020/07/15/INBOX/cur"/* \
		"$TESTSET_DIR/backup-rem/imap-hist/2020/06/16/INBOX/cur"/* \
		"$TESTSET_DIR/backup-rem/imap-hist/2020/06/15/INBOX/cur"/*

	# clear Emails
	test_cleanImap "$TESTIMAP_SRC" "$(cat "$TESTIMAP_SECRET")" "$mail_smtpsrv"

	# IMAP OK with Empty Mailbox 2021-01-16
	test_exec_backupdocker  0 \
		"backup imap" \
		--hist \
		--histdate "2021-01-16" \
		"$TESTIMAP_SRC" \
		/backup/imap-hist \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password
	test_expect_filecount "backup/imap-hist/2021/01/16/INBOX/new" 0
	test_expect_filecount "backup/imap-hist/2021/01/16/INBOX/cur" 0

	# IMAP OK with Empty Mailbox 2021-01-16 - remote backup dest
	test_exec_backupdocker 0 \
		"backup imap" \
		--hist \
		--histdate "2021-01-16" \
		"$TESTIMAP_SRC" \
		"$my_ip:$TESTSET_DIR/backup-rem/imap-hist" \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password \
		--dstsecret /secrets/id_rsa
	test_expect_filecount "backup-rem/imap-hist/2021/01/16/INBOX/new" 0
	test_expect_filecount "backup-rem/imap-hist/2021/01/16/INBOX/cur" 0

	# IMAP KO with date before last backup 2021-01-07
	test_exec_backupdocker  1 \
		"backup imap" \
		--hist \
		--histdate "2021-01-07" \
		"$TESTIMAP_SRC" \
		/backup/imap-hist \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password
	test_expect_filecount "backup/imap-hist/2021/01" 2

	# IMAP KO with date before last backup 2021-01-07 - remote backup dest
	test_exec_backupdocker 1 \
		"backup imap" \
		--hist \
		--histdate "2021-01-07" \
		"$TESTIMAP_SRC" \
		"$my_ip:$TESTSET_DIR/backup-rem/imap-hist" \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password \
		--dstsecret /secrets/id_rsa
	test_expect_filecount "backup-rem/imap-hist/2021/01" 2

	# IMAP OK with Empty Mail and default date=today
	datedir="$(date +%Y/%m/%d)"
	test_exec_backupdocker  0 \
		"backup imap" \
		--hist \
		"$TESTIMAP_SRC" \
		/backup/imap-hist \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password
	test_expect_filecount "backup/imap-hist/$datedir/INBOX/new" 0
	test_expect_filecount "backup/imap-hist/$datedir/INBOX/cur" 0

	# IMAP OK with Empty Mail and default date=today - remote backup dest
	datedir="$(date +%Y/%m/%d)"
	test_exec_backupdocker 0 \
		"backup imap" \
		--hist \
		"$TESTIMAP_SRC" \
		"$my_ip:$TESTSET_DIR/backup-rem/imap-hist" \
		"$TESTIMAP_URL" \
		--srcsecret /backup/imap_password.password \
		--dstsecret /secrets/id_rsa
	test_expect_filecount "backup-rem/imap-hist/$datedir/INBOX/new" 0
	test_expect_filecount "backup-rem/imap-hist/$datedir/INBOX/cur" 0

	return 0
}

##### Main ###################################################################
# do nothing
: "${my_ip:=""}"
