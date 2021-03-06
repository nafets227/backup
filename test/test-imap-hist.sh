#!/bin/bash
#
# Backup in Docker container
#
# (C) 2017-2020 Stefan Schallenberg
#
# Test script for IMAP with history

##### Tests for IMAP with history ############################################
function test_imap_hist {
	if ! test_assert_vars "MAIL_ADR" "MAIL_PW" "MAIL_SRV" ||
	   ! test_assert_tools "curl" "mailx" ; then
		printf "\tSkipping IMAP History Tests.\n"
		return 0
	elif ! test_assert_tools "offlineimap" "jq" ; then
		printf "\tSkipping IMAP Remote Tests.\n"
		exec_remote=false
	elif [ ! -z "$my_ip" ] ; then
		exec_remote=true
	else
		printf "\tSkipping IMAP Remote Tests (ip/ipconfig).\n"
		exec_remote=false
	fi

	printf "Testing IMAP History using Mail Adress \"%s\"\n" "$MAIL_ADR"

	local mail_smtpsrv=${MAIL_SRV%%:*}
	cp "$MAIL_PW" \
		$TESTSETDIR/backup/imap_password.password \
	       || return 1

	test_cleanImap "$MAIL_ADR" "$(cat $MAIL_PW)" "$mail_smtpsrv" || return 1

	# IMAP OK with Empty Mailbox 2020-06-15
	eval $(test_exec_backupdocker  0 \
		"backup imap" \
		--hist \
		--histdate "2020-06-15" \
		"$MAIL_ADR" \
		/backup/imap-hist \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password
		) &&
	test_expect_files "backup/imap-hist/2020/06/15/INBOX/new" 0 &&
	test_expect_files "backup/imap-hist/2020/06/15/INBOX/cur" 0

	# IMAP OK with Empty Mailbox 2020-06-15 - remote backup dest
	$exec_remote &&
	eval $(test_exec_backupdocker 0 \
		"backup imap" \
		--hist \
		--histdate "2020-06-15" \
		"$MAIL_ADR" \
		$my_ip:$TESTSETDIR/backup-rem/imap-hist \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password \
		--dstsecret /secrets/id_rsa
		) &&
	test_expect_files "backup-rem/imap-hist/2020/06/15/INBOX/new" 0 &&
	test_expect_files "backup-rem/imap-hist/2020/06/15/INBOX/cur" 0

	# Store Testmail
	test_putImap "$MAIL_ADR" "$(cat $MAIL_PW)" "$MAIL_SRV" \
		|| return 1

	# IMAP OK with 1 Mail overwrite 2020-06-15
	eval $(test_exec_backupdocker  0 \
		"backup imap" \
		--hist \
		--histdate "2020-06-15" \
		"$MAIL_ADR" \
		/backup/imap-hist \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password
		) &&
	test_expect_files "backup/imap-hist/2020/06/15/INBOX/new" 0 &&
	test_expect_files "backup/imap-hist/2020/06/15/INBOX/cur" 1

	# IMAP OK with 1 Mail overwrite 2020-06-15 - remote backup dest
	$exec_remote &&
	eval $(test_exec_backupdocker 0 \
		"backup imap" \
		--hist \
		--histdate "2020-06-15" \
		"$MAIL_ADR" \
		$my_ip:$TESTSETDIR/backup-rem/imap-hist \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password \
		--dstsecret /secrets/id_rsa
		) &&
	test_expect_files "backup-rem/imap-hist/2020/06/15/INBOX/new" 0 &&
	test_expect_files "backup-rem/imap-hist/2020/06/15/INBOX/cur" 1

	# IMAP OK with 1 Mail 2020-06-16
	eval $(test_exec_backupdocker  0 \
		"backup imap" \
		--hist \
		--histdate "2020-06-16" \
		"$MAIL_ADR" \
		/backup/imap-hist \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password
		) &&
	test_expect_files "backup/imap-hist/2020/06/16/INBOX/new" 0 &&
	test_expect_files "backup/imap-hist/2020/06/16/INBOX/cur" 1 &&
	test_expect_linkedfiles \
		"backup/imap-hist/2020/06/16/INBOX/cur/*" \
		"backup/imap-hist/2020/06/15/INBOX/cur/*"

	# IMAP OK with 1 Mail 2020-06-16 - remote backup dest
	$exec_remote &&
	eval $(test_exec_backupdocker 0 \
		"backup imap" \
		--hist \
		--histdate "2020-06-16" \
		"$MAIL_ADR" \
		$my_ip:$TESTSETDIR/backup-rem/imap-hist \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password \
		--dstsecret /secrets/id_rsa
		) &&
	test_expect_files "backup-rem/imap-hist/2020/06/16/INBOX/new" 0 &&
	test_expect_files "backup-rem/imap-hist/2020/06/16/INBOX/cur" 1 &&
	test_expect_linkedfiles \
		"backup-rem/imap-hist/2020/06/16/INBOX/cur/*" \
		"backup-rem/imap-hist/2020/06/15/INBOX/cur/*"

	# IMAP OK with 1 Mail 2020-07-15
	eval $(test_exec_backupdocker  0 \
		"backup imap" \
		--hist \
		--histdate "2020-07-15" \
		"$MAIL_ADR" \
		/backup/imap-hist \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password
		) &&
	test_expect_files "backup/imap-hist/2020/07/15/INBOX/new" 0 &&
	test_expect_files "backup/imap-hist/2020/07/15/INBOX/cur" 1 &&
	test_expect_linkedfiles \
		"backup/imap-hist/2020/07/15/INBOX/cur/*" \
		"backup/imap-hist/2020/06/16/INBOX/cur/*" \
		"backup/imap-hist/2020/06/15/INBOX/cur/*"

	# IMAP OK with 1 Mail 2020-07-15 - remote backup dest
	$exec_remote &&
	eval $(test_exec_backupdocker 0 \
		"backup imap" \
		--hist \
		--histdate "2020-07-15" \
		"$MAIL_ADR" \
		$my_ip:$TESTSETDIR/backup-rem/imap-hist \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password \
		--dstsecret /secrets/id_rsa
		) &&
	test_expect_files "backup-rem/imap-hist/2020/07/15/INBOX/new" 0 &&
	test_expect_files "backup-rem/imap-hist/2020/07/15/INBOX/cur" 1 &&
	test_expect_linkedfiles \
		"backup-rem/imap-hist/2020/07/15/INBOX/cur/*" \
		"backup-rem/imap-hist/2020/06/16/INBOX/cur/*" \
		"backup-rem/imap-hist/2020/06/15/INBOX/cur/*"

	# IMAP OK with one Mail 2021-01-15
	eval $(test_exec_backupdocker  0 \
		"backup imap" \
		--hist \
		--histdate "2021-01-15" \
		"$MAIL_ADR" \
		/backup/imap-hist \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password
		) &&
	test_expect_files "backup/imap-hist/2021/01/15/INBOX/new" 0 &&
	test_expect_files "backup/imap-hist/2021/01/15/INBOX/cur" 1 &&
	test_expect_linkedfiles \
		"backup/imap-hist/2021/01/15/INBOX/cur/*" \
		"backup/imap-hist/2020/07/15/INBOX/cur/*" \
		"backup/imap-hist/2020/06/16/INBOX/cur/*" \
		"backup/imap-hist/2020/06/15/INBOX/cur/*"

	# IMAP OK with one Mail 2021-01-15 - remote backup dest
	$exec_remote &&
	eval $(test_exec_backupdocker 0 \
		"backup imap" \
		--hist \
		--histdate "2021-01-15" \
		"$MAIL_ADR" \
		$my_ip:$TESTSETDIR/backup-rem/imap-hist \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password \
		--dstsecret /secrets/id_rsa
		) &&
	test_expect_files "backup-rem/imap-hist/2021/01/15/INBOX/new" 0 &&
	test_expect_files "backup-rem/imap-hist/2021/01/15/INBOX/cur" 1 &&
	test_expect_linkedfiles \
		"backup-rem/imap-hist/2021/01/15/INBOX/cur/*" \
		"backup-rem/imap-hist/2020/07/15/INBOX/cur/*" \
		"backup-rem/imap-hist/2020/06/16/INBOX/cur/*" \
		"backup-rem/imap-hist/2020/06/15/INBOX/cur/*"

	# clear Emails
	test_cleanImap "$MAIL_ADR" "$(cat $MAIL_PW)" "$mail_smtpsrv" || return 1

	# IMAP OK with Empty Mailbox 2021-01-16
	eval $(test_exec_backupdocker  0 \
		"backup imap" \
		--hist \
		--histdate "2021-01-16" \
		"$MAIL_ADR" \
		/backup/imap-hist \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password
		) &&
	test_expect_files "backup/imap-hist/2021/01/16/INBOX/new" 0 &&
	test_expect_files "backup/imap-hist/2021/01/16/INBOX/cur" 0

	# IMAP OK with Empty Mailbox 2021-01-16 - remote backup dest
	$exec_remote &&
	eval $(test_exec_backupdocker 0 \
		"backup imap" \
		--hist \
		--histdate "2021-01-16" \
		"$MAIL_ADR" \
		$my_ip:$TESTSETDIR/backup-rem/imap-hist \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password \
		--dstsecret /secrets/id_rsa
		) &&
	test_expect_files "backup-rem/imap-hist/2021/01/16/INBOX/new" 0 &&
	test_expect_files "backup-rem/imap-hist/2021/01/16/INBOX/cur" 0

	# IMAP KO with date before last backup 2021-01-07
	eval $(test_exec_backupdocker  1 \
		"backup imap" \
		--hist \
		--histdate "2021-01-07" \
		"$MAIL_ADR" \
		/backup/imap-hist \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password
		) &&
	test_expect_files "backup/imap-hist/2021/01" 2

	# IMAP KO with date before last backup 2021-01-07 - remote backup dest
	$exec_remote &&
	eval $(test_exec_backupdocker 1 \
		"backup imap" \
		--hist \
		--histdate "2021-01-07" \
		"$MAIL_ADR" \
		$my_ip:$TESTSETDIR/backup-rem/imap-hist \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password \
		--dstsecret /secrets/id_rsa
		) &&
	test_expect_files "backup-rem/imap-hist/2021/01" 2

	# IMAP OK with Empty Mail and default date=today
	datedir="$(date +%Y/%m/%d)"
	eval $(test_exec_backupdocker  0 \
		"backup imap" \
		--hist \
		"$MAIL_ADR" \
		/backup/imap-hist \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password
		) &&
	test_expect_files "backup/imap-hist/$datedir/INBOX/new" 0 &&
	test_expect_files "backup/imap-hist/$datedir/INBOX/cur" 0

	# IMAP OK with Empty Mail and default date=today - remote backup dest
	datedir="$(date +%Y/%m/%d)"
	eval $(test_exec_backupdocker 0 \
		"backup imap" \
		--hist \
		"$MAIL_ADR" \
		$my_ip:$TESTSETDIR/backup-rem/imap-hist \
		"$MAIL_SRV" \
		--srcsecret /backup/imap_password.password \
		--dstsecret /secrets/id_rsa
		) &&
	test_expect_files "backup-rem/imap-hist/$datedir/INBOX/new" 0 &&
	test_expect_files "backup-rem/imap-hist/$datedir/INBOX/cur" 0

	return 0
}

##### Main ###################################################################
# do nothing
