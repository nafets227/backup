#!/bin/bash
#
# Backup in Docker container
#
# (C) 2017-2020 Stefan Schallenberg
#
# Test script for IMAP

function test_cleanRclone () {
	if [ "$#" -ne 2 ] ; then
		printf "%s: Internal Error. Got %s parms (exp=3)\n" \
			"$FUNCNAME" "$#"
		return 1
	fi

	local rclone_name="$1"
	local rclone_conf="$2"

	printf "Purging rclone %s from %s.\n" \
		"$rclone_name" "$rclone_conf"

	rclone \
		--config $rclone_conf \
		delete $rclone_name --rmdirs

	return $?
}

function test_putRclone () {
	if [ "$#" -ne 2 ] ; then
		printf "%s: Internal Error. Got %s parms (exp=3)\n" \
			"$FUNCNAME" "$#"
		return 1
	fi

	local rclone_namepath="$1"
	local rclone_conf="$2"

	printf "Storing a file into %s at %s.\n" \
		"$rclone_namepath" "$rclone_conf"

	rclone \
		--config $rclone_conf \
		rcat $rclone_namepath <<-EOF
			TestFile on Cloud for testing of nafets227
			see https://github.com/nafets227/util
			EOF

	return $?
}

##### Tests for rclone #######################################################
function test_rclone {
	if ! test_assert_vars "RCLONE_CONF" "RCLONE_NAME" ||
	   ! test_assert_files "$RCLONE_CONF" ||
	   ! test_assert_tools "rclone" ; then
		printf "\tSkipping rclone Tests.\n"
		return 0
	fi

	printf "Testing rclone using \"%s\" in %s\n" "$RCLONE_NAME" "$RCLONE_CONF"

	cp "$RCLONE_CONF" "$TESTSETDIR/backup/rclone.conf" &&
	test_cleanRclone "$RCLONE_NAME" "$RCLONE_CONF" &&
	true || return 1

	# Wrong src, no ":"
	eval $(test_exec_backupdocker 1 \
		"backup rclone" \
		"mydummyname" \
		/backup/rclone
		)

	# Wrong src, nothing after ":"
	eval $(test_exec_backupdocker 1 \
		"backup rclone" \
		"mydummyname:" \
		/backup/rclone \
		--srcsecret /backup/rclone.conf \
		)

	# Wrong src, nothing before ":"
	eval $(test_exec_backupdocker 1 \
		"backup rclone" \
		":mydummyname" \
		/backup/rclone \
		--srcsecret /backup/rclone.conf \
		)

	# No password
	eval $(test_exec_backupdocker 1 \
		"backup rclone" \
		"$RCLONE_NAME" \
		/backup/rclone \
		)

	# Not existing password file
	eval $(test_exec_backupdocker 1 \
		"backup rclone" \
		"$RCLONE_NAME" \
		/backup/rclone \
		--srcsecret "filedoesnotexist"
		)

	# rclone OK with Empty Cloud
	eval $(test_exec_backupdocker  0 \
		"backup rclone" \
		"$RCLONE_NAME" \
		/backup/rclone \
		--srcsecret /backup/rclone.conf \
		) &&
	test_expect_files "backup/rclone" 0

	# rclone OK with Empty Cloud - remote backup dest
	$exec_remote &&
	eval $(test_exec_backupdocker 0 \
		"backup rclone" \
		"$RCLONE_NAME" \
		$my_ip:$TESTSETDIR/backup-rem/rclone \
		--srcsecret /backup/rclone.conf \
		--dstsecret /secrets/id_rsa
		) &&
	test_expect_files "backup-rem/rclone" 0

	# Verify modifying conf
	cp "$RCLONE_CONF" "$TESTSETDIR/backup/rclone-update.conf" &&
	eval $(test_exec_backupdocker 0 \
		"backup rclone_unittest_updateconf" \
		"$RCLONE_NAME" \
		/backup/rclone \
		--srcsecret /backup/rclone-update.conf
		) &&
	test_exec_simple "fgrep '[rclone-unittest-dummy]' $TESTSETDIR/backup/rclone-update.conf"

	# Verify modifying conf - remote
	$exec_remote &&
	cp "$RCLONE_CONF" "$TESTSETDIR/backup/rclone-update.conf" &&
	eval $(test_exec_backupdocker 0 \
		"backup rclone_unittest_updateconf" \
		"$RCLONE_NAME" \
		$my_ip:$TESTSETDIR/backup-rem/rclone \
		--srcsecret /backup/rclone-update.conf \
		--dstsecret /secrets/id_rsa
		) &&
	test_exec_simple "fgrep '[rclone-unittest-dummy]' $TESTSETDIR/backup/rclone-update.conf"

	# Store Testfiles
	test_putRclone "${RCLONE_NAME}test.txt" "$RCLONE_CONF" &&
	test_putRclone "${RCLONE_NAME}testdir/testfile.txt" "$RCLONE_CONF" &&
	true || return 1

	# rclone OK with files
	eval $(test_exec_backupdocker 0 \
		"backup rclone" \
		"$RCLONE_NAME" \
		/backup/rclone \
		--srcsecret /backup/rclone.conf
		) &&
	test_expect_files "backup/rclone" 2 &&
	test_expect_files "backup/rclone/testdir" 1

	# rclone OK with files - remote backup dest
	$exec_remote &&
	eval $(test_exec_backupdocker 0 \
		"backup rclone" \
		"$RCLONE_NAME" \
		$my_ip:$TESTSETDIR/backup-rem/rclone \
		--srcsecret /backup/rclone.conf \
		--dstsecret /secrets/id_rsa
		) &&
	test_expect_files "backup-rem/rclone" 2 &&
	test_expect_files "backup-rem/rclone/testdir" 1

	test_cleanRclone "$RCLONE_NAME" "$RCLONE_CONF" || return 1

	# rclone OK with files deleted
	eval $(test_exec_backupdocker 0 \
		"backup rclone" \
		"$RCLONE_NAME" \
		/backup/rclone \
		--srcsecret /backup/rclone.conf
		) &&
	test_expect_files "backup/rclone" 0

	# rclone OK with files deleted - remote backup dest
	$exec_remote &&
	eval $(test_exec_backupdocker 0 \
		"backup rclone" \
		"$RCLONE_NAME" \
		$my_ip:$TESTSETDIR/backup-rem/rclone \
		--srcsecret /backup/rclone.conf \
		--dstsecret /secrets/id_rsa
		) &&
	test_expect_files "backup-rem/rclone" 0

	return 0
}

##### Main ###################################################################
# do nothing
