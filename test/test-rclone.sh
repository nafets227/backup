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
	if [ "$#" -lt 2 ] ; then
		printf "%s: Internal Error. Got %s parms (exp=2+)\n" \
			"$FUNCNAME" "$#"
		return 1
	fi

	local rclone_namepath="$1"
	local rclone_conf="$2"
	shift 2

	printf "Storing a file into %s at %s.\n" \
		"$rclone_namepath" "$rclone_conf"

	rclone \
		--config $rclone_conf \
		rcat $rclone_namepath <<-EOF
			TestFile on Cloud for testing of nafets227
			see https://github.com/nafets227/util
			$*
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

	cp "$RCLONE_CONF" "$TESTSETDIR/backup/rclone.conf"
	test_assert "$?" "copy rclone.conf" || return 1

	test_cleanRclone "$RCLONE_NAME" "$RCLONE_CONF"
	test_assert "$?" "clean rclone" || return 1

	# Wrong src, no ":"
	eval $(test_exec_backupdocker 1 \
		"backup rclone" \
		"mydummyname" \
		/backup/rclone \
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
	cp "$RCLONE_CONF" "$TESTSETDIR/backup/rclone-update.conf"
	test_assert "$?" "write rclone-update.conf" || return 1
	eval $(test_exec_backupdocker 0 \
		"backup rclone_unittest_updateconf" \
		"$RCLONE_NAME" \
		/backup/rclone \
		--srcsecret /backup/rclone-update.conf
		) &&
	test_exec_simple "fgrep '[rclone-unittest-dummy]' $TESTSETDIR/backup/rclone-update.conf"

	# Verify modifying conf - remote
	cp "$RCLONE_CONF" "$TESTSETDIR/backup/rclone-update.conf" &&
	test_assert "$?" "write rclone-update.conf" || return 1
	$exec_remote &&
	eval $(test_exec_backupdocker 0 \
		"backup rclone_unittest_updateconf" \
		"$RCLONE_NAME" \
		$my_ip:$TESTSETDIR/backup-rem/rclone \
		--srcsecret /backup/rclone-update.conf \
		--dstsecret /secrets/id_rsa
		) &&
	test_exec_simple "fgrep '[rclone-unittest-dummy]' $TESTSETDIR/backup/rclone-update.conf"

	# Store Testfiles
	test_putRclone "${RCLONE_NAME}test.txt" "$RCLONE_CONF"
	test_assert "$?" "put test.txt on rclone" || return 1
	test_putRclone "${RCLONE_NAME}testdir/testfile.txt" "$RCLONE_CONF"
	test_assert "$?" "put testdir/testfile.txt on rclone" || return 1

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

	test_cleanRclone "$RCLONE_NAME" "$RCLONE_CONF"
	test_assert "$?" "clean rclone" || return 1

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

##### Tests for rclone history ###############################################
function test_rclone_hist {
	if ! test_assert_vars "RCLONE_CONF" "RCLONE_NAME" ||
	   ! test_assert_files "$RCLONE_CONF" ||
	   ! test_assert_tools "rclone" ; then
		printf "\tSkipping rclone Tests.\n"
		return 0
	fi

	printf "Testing rclone history using \"%s\" in %s\n" "$RCLONE_NAME" "$RCLONE_CONF"

	cp "$RCLONE_CONF" "$TESTSETDIR/backup/rclone-hist.conf"
	test_assert "$?" "copy rclone.conf" || return 1

	test_cleanRclone "$RCLONE_NAME" "$RCLONE_CONF"
	test_assert "$?" "clean rclone" || return 1

	# Time 1+2: Empty Cloud
	eval $(test_exec_backupdocker  0 \
		"backup rclone" \
		--hist \
		--histdate "2022-03-01" \
		"$RCLONE_NAME" \
		/backup/rclone-hist \
		--srcsecret /backup/rclone-hist.conf \
		)
	eval $(test_exec_backupdocker  0 \
		"backup rclone" \
		--hist \
		--histdate "2022-03-02" \
		"$RCLONE_NAME" \
		/backup/rclone-hist \
		--srcsecret /backup/rclone-hist.conf \
		)

	# Time 10+11: Added file
	test_putRclone "${RCLONE_NAME}test.txt" "$RCLONE_CONF" "rclone-hist-1"
	test_assert "$?" "put test.txt on rclone" || return 1
	test_putRclone "${RCLONE_NAME}testdir/testfile.txt" "$RCLONE_CONF" "rclone-hist-1"
	test_assert "$?" "put testdir/testfile.txt on rclone" || return 1
	eval $(test_exec_backupdocker  0 \
		"backup rclone" \
		--hist \
		--histdate "2022-03-10" \
		"$RCLONE_NAME" \
		/backup/rclone-hist \
		--srcsecret /backup/rclone-hist.conf \
		)
	eval $(test_exec_backupdocker  0 \
		"backup rclone" \
		--hist \
		--histdate "2022-03-11" \
		"$RCLONE_NAME" \
		/backup/rclone-hist \
		--srcsecret /backup/rclone-hist.conf \
		)

	# Time 20+21: modified file
	test_putRclone "${RCLONE_NAME}test.txt" "$RCLONE_CONF" "rclone-hist-2"
	test_assert "$?" "put test.txt on rclone" || return 1
	test_putRclone "${RCLONE_NAME}testdir/testfile.txt" "$RCLONE_CONF" "rclone-hist-2"
	test_assert "$?" "put testdir/testfile.txt on rclone" || return 1
	eval $(test_exec_backupdocker  0 \
		"backup rclone" \
		--hist \
		--histdate "2022-03-20" \
		"$RCLONE_NAME" \
		/backup/rclone-hist \
		--srcsecret /backup/rclone-hist.conf \
		)
	eval $(test_exec_backupdocker  0 \
		"backup rclone" \
		--hist \
		--histdate "2022-03-21" \
		"$RCLONE_NAME" \
		/backup/rclone-hist \
		--srcsecret /backup/rclone-hist.conf \
		)

	# Time 30: deleted file
	test_cleanRclone "$RCLONE_NAME" "$RCLONE_CONF"
	test_assert "$?" "clean rclone" || return 1
	eval $(test_exec_backupdocker  0 \
		"backup rclone" \
		--hist \
		--histdate "2022-03-30" \
		"$RCLONE_NAME" \
		/backup/rclone-hist \
		--srcsecret /backup/rclone-hist.conf \
		)

	# Finally check:
	test_expect_files "backup/rclone-hist/2022/03/01" 0
	test_expect_files "backup/rclone-hist/2022/03/02" 0

	test_expect_files "backup/rclone-hist/2022/03/10" 2
	test_expect_files "backup/rclone-hist/2022/03/11" 2
	test_expect_linkedfiles \
		"backup/rclone-hist/2022/03/10/test.txt" \
		"backup/rclone-hist/2022/03/11/test.txt"
	test_expect_linkedfiles \
		"backup/rclone-hist/2022/03/10/testdir/testfile.txt" \
		"backup/rclone-hist/2022/03/11/testdir/testfile.txt"
	test_expect_file_contains \
		"backup/rclone-hist/2022/03/10/test.txt" \
		rclone-hist-1
	test_expect_file_contains \
		"backup/rclone-hist/2022/03/10/testdir/testfile.txt" \
		rclone-hist-1
	test_expect_file_contains \
		"backup/rclone-hist/2022/03/11/test.txt" \
		rclone-hist-1
	test_expect_file_contains \
		"backup/rclone-hist/2022/03/11/testdir/testfile.txt" \
		rclone-hist-1

	test_expect_files "backup/rclone-hist/2022/03/20" 2
	test_expect_files "backup/rclone-hist/2022/03/21" 2
	test_expect_linkedfiles \
		"backup/rclone-hist/2022/03/20/test.txt" \
		"backup/rclone-hist/2022/03/21/test.txt"
	test_expect_linkedfiles \
		"backup/rclone-hist/2022/03/20/testdir/testfile.txt" \
		"backup/rclone-hist/2022/03/21/testdir/testfile.txt"
	test_expect_file_contains \
		"backup/rclone-hist/2022/03/20/test.txt" \
		rclone-hist-2
	test_expect_file_contains \
		"backup/rclone-hist/2022/03/20/testdir/testfile.txt" \
		rclone-hist-2
	test_expect_file_contains \
		"backup/rclone-hist/2022/03/21/test.txt" \
		rclone-hist-2
	test_expect_file_contains \
		"backup/rclone-hist/2022/03/21/testdir/testfile.txt" \
		rclone-hist-2

	test_expect_files "backup/rclone-hist/2022/03/30" 0

	return 0
}

##### Main ###################################################################
# do nothing
