#!/usr/bin/env bash
#
# Backup in Docker container
#
# (C) 2017-2020 Stefan Schallenberg
#
# Test script for IMAP

function test_rclone_execraw {
	# Execute rclone in a container
	# Executing on the OS we are running on failed due to outdated
	# rclone in GitHub Action Runner (Ubuntu) that had version 1.60.1+
	# where a bug has not yet been fixed
	# https://github.com/rclone/rclone/issues/7405 fixed in rclone 1.66.0
	local rclone_conf="$1"
	shift

	cp "$rclone_conf" "$TESTSET_DIR/backup/rcloneraw.conf"
	test_chown "$TESTSET_DIR/backup/rcloneraw.conf"

	cp ~/.ssh/id_ed25519 "$TESTSET_DIR/id_ed25519"
	test_chown "$TESTSET_DIR/id_ed25519"

	test_exec_cmd 0 "Backup Command $*" \
		docker run -i \
			-v "$TESTSET_DIR/backup:/backup" \
			-v "$TESTSET_DIR/id_ed25519:/secrets/id_ed25519:ro" \
			-e DEBUG=1 \
			--entrypoint /usr/lib/nafets227.backup/rclone \
			"$TESTIMG" \
			--config /backup/rcloneraw.conf \
			"$@"

	return 0
}

function test_cleanRclone () {
	if [ "$#" -ne 2 ] ; then
		printf "%s: Internal Error. Got %s params (exp=3)\n" \
			"${FUNCNAME[0]}" "$#"
		return 1
	fi

	local rclone_name="$1"
	local rclone_conf="$2"

	printf "Purging rclone %s from %s.\n" \
		"$rclone_name" "$rclone_conf"

	test_rclone_execraw "$rclone_conf" \
		delete "$rclone_name" --rmdirs \
		--exclude '/UnusedVault/**'

	return 0
}

function test_putRclone () {
	if [ "$#" -lt 2 ] ; then
		printf "%s: Internal Error. Got %s params (exp=2+)\n" \
			"${FUNCNAME[0]}" "$#"
		return 1
	fi

	local rclone_namepath="$1"
	local rclone_conf="$2"
	shift 2

	printf "Storing a file into %s at %s.\n" \
		"$rclone_namepath" "$rclone_conf"

	test_rclone_execraw "$rclone_conf" \
		rcat "$rclone_namepath" <<-EOF
			TestFile on Cloud for testing of nafets227
			see https://github.com/nafets227/util
			$*
			EOF

	return 0
}

function test_expect_rclone_files {
	TESTSET_LAST_CHECK_NR=$(( ${TESTSET_LAST_CHECK_NR-0} + 1))
	# not increasing TESTSET_LAST_TEST_NR
	local rclone_namepath="$1"
	local rclone_conf="$2"
	local testexpected="$3"
	shift 3

	# switch off tracing as it would produce additional output that
	# makes some tests fail.
	# make sure its reset to previous state on return
	if [ -o xtrace ] ; then
		set +x
		trap "set -x" RETURN
	fi

	test_rclone_execraw "$rclone_conf" \
		lsf "$rclone_namepath" "$@"

	testresult=$(
		set -o pipefail
		test_get_lastoutput |
		grep --count --invert-match "^#-----"  || [ "$?" == "1" ]
		)

	rc=$?

	if [ "$rc" != 0 ] ; then
		printf "\tCHECK %s FAILED. Cannot get files in '%s'\n" \
			"$TESTSET_LAST_CHECK_NR" "$rclone_namepath"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
	elif [ "$testresult" != "$testexpected" ] ; then
		# nr of files differ from expected
		printf "\tCHECK %s FAILED. nr of files in '%s' is %s (exp=%s)\n" \
			"$TESTSET_LAST_CHECK_NR" "$rclone_namepath" "$testresult" "$testexpected"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
	else
		printf "\tCHECK %s OK.\n" "$TESTSET_LAST_CHECK_NR"
		TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
	fi

	return 0
}


##### Tests for rclone2file ##################################################
function test_rclone2file {
	if [ ! -f "$TESTRCLONE_CONF" ]
	then
		printf "\tSkipping rclone Tests.\n"
		return 0
	fi

	if [ -n "$my_ip" ] ; then
		exec_remote=true
	else
		test_expect_value "1" 0 "Skipping rclone Remote Tests (ip/ipconfig)"
		exec_remote=false
	fi

	printf "Testing rclone2file using \"%s\" in %s\n" \
		"$TESTRCLONE_NAME" "$TESTRCLONE_CONF"

	cp "$TESTRCLONE_CONF" "$TESTSET_DIR/backup/rclone2file.conf"
	test_chown "$TESTSET_DIR/backup/rclone2file.conf"

	test_cleanRclone "$TESTRCLONE_NAME" "$TESTRCLONE_CONF"

	# rclone OK with Empty Cloud (compatibility "rclone")
	test_exec_backupdocker  0 \
		"backup rclone" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file \
		--srcsecret /backup/rclone2file.conf \
		--exclude '/UnusedVault/**'
	test_expect_filecount "backup/rclone2file" 0

	# Wrong src, no ":"
	test_exec_backupdocker 1 \
		"backup rclone2file" \
		"mydummyname" \
		/backup/rclone2file

	# Wrong src, nothing after ":"
	test_exec_backupdocker 1 \
		"backup rclone2file" \
		"mydummyname:" \
		/backup/rclone2file \
		--srcsecret /backup/rclone2file.conf

	# Wrong src, nothing before ":"
	test_exec_backupdocker 1 \
		"backup rclone2file" \
		":mydummyname" \
		/backup/rclone2file \
		--srcsecret /backup/rclone2file.conf

	# No password
	test_exec_backupdocker 1 \
		"backup rclone2file" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file

	# Not existing password file
	test_exec_backupdocker 1 \
		"backup rclone2file" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file \
		--srcsecret "filedoesnotexist"

	# rclone OK with Empty Cloud
	test_exec_backupdocker  0 \
		"backup rclone2file" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file \
		--srcsecret /backup/rclone2file.conf \
		--exclude '/UnusedVault/**'
	test_expect_filecount "backup/rclone2file" 0

	# rclone OK with Empty Cloud - remote backup dest
	if $exec_remote ; then
		test_exec_backupdocker 0 \
			"backup rclone2file" \
			"$TESTRCLONE_NAME" \
			"$my_ip:$TESTSET_DIR/backup-rem/rclone2file" \
			--srcsecret /backup/rclone2file.conf \
			--dstsecret /secrets/id_ed25519 \
			--exclude '/UnusedVault/**'
		test_expect_filecount "backup-rem/rclone2file" 0
	fi

	# Verify modifying conf
	cp "$TESTRCLONE_CONF" "$TESTSET_DIR/backup/rclone-update.conf"
	test_chown "$TESTSET_DIR/backup/rclone-update.conf"

	test_exec_backupdocker 0 \
		"backup rclone_unittest_updateconf" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file \
		--srcsecret /backup/rclone-update.conf
	test_exec_cmd "" "" \
		fgrep '[rclone-unittest-dummy]' "$TESTSET_DIR/backup/rclone-update.conf"

	# Verify modifying conf - remote
	cp "$TESTRCLONE_CONF" "$TESTSET_DIR/backup/rclone-update.conf"
	test_chown "$TESTSET_DIR/backup/rclone-update.conf"
	if $exec_remote ; then
		test_exec_backupdocker 0 \
			"backup rclone_unittest_updateconf" \
			"$TESTRCLONE_NAME" \
			"$my_ip:$TESTSET_DIR/backup-rem/rclone2file" \
			--srcsecret /backup/rclone-update.conf \
			--dstsecret /secrets/id_ed25519
		test_exec_cmd "" "" \
			fgrep '[rclone-unittest-dummy]' "$TESTSET_DIR/backup/rclone-update.conf"
	fi

	# Store Testfiles
	test_putRclone "${TESTRCLONE_NAME}test.txt" "$TESTRCLONE_CONF"
	test_putRclone "${TESTRCLONE_NAME}testdir/testfile.txt" "$TESTRCLONE_CONF"

	# rclone OK with files
	test_exec_backupdocker 0 \
		"backup rclone2file" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file \
		--srcsecret /backup/rclone2file.conf \
		--exclude '/UnusedVault/**'
	test_expect_filecount "backup/rclone2file" 2
	test_expect_filecount "backup/rclone2file/testdir" 1

	# rclone OK with files - remote backup dest
	if $exec_remote ; then
		test_exec_backupdocker 0 \
			"backup rclone2file" \
			"$TESTRCLONE_NAME" \
			"$my_ip:$TESTSET_DIR/backup-rem/rclone2file" \
			--srcsecret /backup/rclone2file.conf \
			--dstsecret /secrets/id_ed25519 \
			--exclude '/UnusedVault/**'
		test_expect_filecount "backup-rem/rclone2file" 2
		test_expect_filecount "backup-rem/rclone2file/testdir" 1
	fi

	test_cleanRclone "$TESTRCLONE_NAME" "$TESTRCLONE_CONF"

	# rclone OK with files deleted
	test_exec_backupdocker 0 \
		"backup rclone2file" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file \
		--srcsecret /backup/rclone2file.conf \
		--exclude '/UnusedVault/**'
	test_expect_filecount "backup/rclone2file" 0

	# rclone OK with files deleted - remote backup dest
	if $exec_remote ; then
		test_exec_backupdocker 0 \
			"backup rclone2file" \
			"$TESTRCLONE_NAME" \
			"$my_ip:$TESTSET_DIR/backup-rem/rclone2file" \
			--srcsecret /backup/rclone2file.conf \
			--dstsecret /secrets/id_ed25519 \
			--exclude '/UnusedVault/**'
		test_expect_filecount "backup-rem/rclone2file" 0
	fi

	return 0
}

##### Tests for rclone2file history ##########################################
function test_rclone2file_hist {
	if [ ! -f "$TESTRCLONE_CONF" ]
	then
		printf "\tSkipping rclone Tests.\n"
		return 0
	fi

	printf "Testing rclone history using \"%s\" in %s\n" \
		"$TESTRCLONE_NAME" "$TESTRCLONE_CONF"

	cp "$TESTRCLONE_CONF" "$TESTSET_DIR/backup/rclone2file-hist.conf"
	test_chown "$TESTSET_DIR/backup/rclone2file-hist.conf"

	test_cleanRclone "$TESTRCLONE_NAME" "$TESTRCLONE_CONF"

	# Time 1+2: Empty Cloud
	test_exec_backupdocker  0 \
		"backup rclone2file" \
		--hist \
		--histdate "2022-03-01" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file-hist \
		--srcsecret /backup/rclone2file-hist.conf \
		--exclude '/UnusedVault/**'
	test_exec_backupdocker  0 \
		"backup rclone2file" \
		--hist \
		--histdate "2022-03-02" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file-hist \
		--srcsecret /backup/rclone2file-hist.conf \
		--exclude '/UnusedVault/**'

	# Time 10+11: Added file
	test_putRclone "${TESTRCLONE_NAME}test.txt" "$TESTRCLONE_CONF" "rclone-hist-1"
	test_putRclone "${TESTRCLONE_NAME}testdir/testfile.txt" \
		"$TESTRCLONE_CONF" "rclone-hist-1"
	test_exec_backupdocker  0 \
		"backup rclone2file" \
		--hist \
		--histdate "2022-03-10" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file-hist \
		--srcsecret /backup/rclone2file-hist.conf \
		--exclude '/UnusedVault/**'
	test_exec_backupdocker  0 \
		"backup rclone2file" \
		--hist \
		--histdate "2022-03-11" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file-hist \
		--srcsecret /backup/rclone2file-hist.conf \
		--exclude '/UnusedVault/**'

	# Time 20+21: modified file
	test_putRclone "${TESTRCLONE_NAME}test.txt" "$TESTRCLONE_CONF" \
		"rclone-hist-2"
	test_putRclone "${TESTRCLONE_NAME}testdir/testfile.txt" \
		"$TESTRCLONE_CONF" "rclone-hist-2"
	test_exec_backupdocker  0 \
		"backup rclone2file" \
		--hist \
		--histdate "2022-03-20" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file-hist \
		--srcsecret /backup/rclone2file-hist.conf \
		--exclude '/UnusedVault/**'
	test_exec_backupdocker  0 \
		"backup rclone2file" \
		--hist \
		--histdate "2022-03-21" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file-hist \
		--srcsecret /backup/rclone2file-hist.conf \
		--exclude '/UnusedVault/**'

	# Time 30: deleted file
	test_cleanRclone "$TESTRCLONE_NAME" "$TESTRCLONE_CONF"
	test_exec_backupdocker  0 \
		"backup rclone2file" \
		--hist \
		--histdate "2022-03-30" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file-hist \
		--srcsecret /backup/rclone2file-hist.conf \
		--exclude '/UnusedVault/**'

	# Finally check:
	test_expect_filecount "backup/rclone2file-hist/2022/03/01" 0
	test_expect_filecount "backup/rclone2file-hist/2022/03/02" 0

	test_expect_filecount "backup/rclone2file-hist/2022/03/10" 2
	test_expect_filecount "backup/rclone2file-hist/2022/03/11" 2
	test_expect_linkedfiles \
		"backup/rclone2file-hist/2022/03/10/test.txt" \
		"backup/rclone2file-hist/2022/03/11/test.txt"
	test_expect_linkedfiles \
		"backup/rclone2file-hist/2022/03/10/testdir/testfile.txt" \
		"backup/rclone2file-hist/2022/03/11/testdir/testfile.txt"
	test_expect_file_contains \
		"backup/rclone2file-hist/2022/03/10/test.txt" \
		rclone-hist-1
	test_expect_file_contains \
		"backup/rclone2file-hist/2022/03/10/testdir/testfile.txt" \
		rclone-hist-1
	test_expect_file_contains \
		"backup/rclone2file-hist/2022/03/11/test.txt" \
		rclone-hist-1
	test_expect_file_contains \
		"backup/rclone2file-hist/2022/03/11/testdir/testfile.txt" \
		rclone-hist-1

	test_expect_filecount "backup/rclone2file-hist/2022/03/20" 2
	test_expect_filecount "backup/rclone2file-hist/2022/03/21" 2
	test_expect_linkedfiles \
		"backup/rclone2file-hist/2022/03/20/test.txt" \
		"backup/rclone2file-hist/2022/03/21/test.txt"
	test_expect_linkedfiles \
		"backup/rclone2file-hist/2022/03/20/testdir/testfile.txt" \
		"backup/rclone2file-hist/2022/03/21/testdir/testfile.txt"
	test_expect_file_contains \
		"backup/rclone2file-hist/2022/03/20/test.txt" \
		rclone-hist-2
	test_expect_file_contains \
		"backup/rclone2file-hist/2022/03/20/testdir/testfile.txt" \
		rclone-hist-2
	test_expect_file_contains \
		"backup/rclone2file-hist/2022/03/21/test.txt" \
		rclone-hist-2
	test_expect_file_contains \
		"backup/rclone2file-hist/2022/03/21/testdir/testfile.txt" \
		rclone-hist-2

	test_expect_filecount "backup/rclone2file-hist/2022/03/30" 0

	return 0
}

##### Tests for file2rclone ##################################################
function test_file2rclone {
	if [ ! -f "$TESTRCLONE_CONF" ]
	then
		printf "\tSkipping file2rclone Tests.\n"
		return 0
	fi

	printf "Testing file2rclone using \"%s\" in %s\n" \
		"$TESTRCLONE_NAME" "$TESTRCLONE_CONF"

	cp "$TESTRCLONE_CONF" "$TESTSET_DIR/backup/file2rclone.conf"
	test_chown "$TESTSET_DIR/backup/file2rclone.conf"

	test_cleanRclone "$TESTRCLONE_NAME" "$TESTRCLONE_CONF"

	mkdir -p \
		"$TESTSET_DIR/backup/file2rclone"

	# Wrong dst, no ":"
	test_exec_backupdocker 1 \
		"backup file2rclone" \
		/backup/file2rclone \
		"mydummyname"

	# Wrong dst, nothing after ":"
	test_exec_backupdocker 1 \
		"backup file2rclone" \
		/backup/file2rclone \
		"mydummyname:" \
		--dstsecret /backup/file2rclone.conf

	# Wrong dst, nothing before ":"
	test_exec_backupdocker 1 \
		"backup file2rclone" \
		/backup/file2rclone \
		":mydummyname" \
		--dstsecret /backup/file2rclone.conf

	# No password
	test_exec_backupdocker 1 \
		"backup file2rclone" \
		/backup/file2rclone \
		"$TESTRCLONE_NAME"

	# Not existing password file
	test_exec_backupdocker 1 \
		"backup file2rclone" \
		/backup/file2rclone \
		"$TESTRCLONE_NAME" \
		--dstsecret "filedoesnotexist"

	# remote source without source secret
	test_exec_backupdocker 1 \
		"backup file2rclone" \
		"$my_ip:$TESTSET_DIR/backup/file2rclone" \
		"$TESTRCLONE_NAME" \
		--dstsecret /backup/file2rclone.conf

	for source in "/backup/file2rclone" "$my_ip:$TESTSET_DIR/backup/file2rclone"
	do
		secretparam=""
		if [[ "$source" == *":"* ]] ; then
			secretparam+="--srcsecret /secrets/id_ed25519 "
		fi

		test_cleanRclone "$TESTRCLONE_NAME" "$TESTRCLONE_CONF"

		# backup from non-existing source should fail
		#shellcheck disable=SC2086 # secretparam intentionally may contain >1 word
		test_exec_backupdocker 1 \
			"backup file2rclone" \
			"$source/thisdirdoesnotexist" \
			"$TESTRCLONE_NAME" \
			--dstsecret /backup/file2rclone.conf \
			$secretparam \
			--exclude '/UnusedVault/**'

		# history backup should fail
		#shellcheck disable=SC2086 # secretparam intentionally may contain >1 word
		test_exec_backupdocker 1 \
			"backup file2rclone" \
			"$source" \
			"$TESTRCLONE_NAME" \
			--dstsecret /backup/file2rclone.conf \
			$secretparam \
			--hist \
			--exclude '/UnusedVault/**'

		# rclone OK with Empty Dir
		#shellcheck disable=SC2086 # secretparam intentionally may contain >1 word
		test_exec_backupdocker 0 \
			"backup file2rclone" \
			"$source" \
			"$TESTRCLONE_NAME" \
			--dstsecret /backup/file2rclone.conf \
			$secretparam \
			--exclude '/UnusedVault/**'
		test_expect_rclone_files "$TESTRCLONE_NAME" "$TESTRCLONE_CONF" 0 \
			--exclude '/UnusedVault/**'

		# backup one file
		cat >"$TESTSET_DIR/backup/file2rclone/dummyfile" <<<"Dummyfile"
		#shellcheck disable=SC2086 # secretparam intentionally may contain >1 word
		test_exec_backupdocker 0 \
			"backup file2rclone" \
			"$source" \
			"$TESTRCLONE_NAME" \
			--dstsecret /backup/file2rclone.conf \
			$secretparam \
			--exclude '/UnusedVault/**'
		test_expect_rclone_files "$TESTRCLONE_NAME" "$TESTRCLONE_CONF" 1 \
			--exclude '/UnusedVault/**'

		# backup additional file in subdirectory
		mkdir "$TESTSET_DIR/backup/file2rclone/testsubdir"
		cat >"$TESTSET_DIR/backup/file2rclone/testsubdir/dummyfile2" <<<"Dummyfile2"
		#shellcheck disable=SC2086 # secretparam intentionally may contain >1 word
		test_exec_backupdocker 0 \
			"backup file2rclone" \
			"$source" \
			"$TESTRCLONE_NAME" \
			--dstsecret /backup/file2rclone.conf \
			$secretparam \
			--exclude '/UnusedVault/**'
		test_expect_rclone_files "$TESTRCLONE_NAME" "$TESTRCLONE_CONF" 2 \
			--exclude '/UnusedVault/**'
		# includes subdir!
		test_expect_rclone_files "${TESTRCLONE_NAME}testsubdir" \
			"$TESTRCLONE_CONF" 1 \
			--exclude '/UnusedVault/**'

		# delete no longer existing file
		rm "$TESTSET_DIR/backup/file2rclone/dummyfile"
		#shellcheck disable=SC2086 # secretparam intentionally may contain >1 word
		test_exec_backupdocker 0 \
			"backup file2rclone" \
			"$source" \
			"$TESTRCLONE_NAME" \
			--dstsecret /backup/file2rclone.conf \
			$secretparam \
			--exclude '/UnusedVault/**'
		test_expect_rclone_files "$TESTRCLONE_NAME" "$TESTRCLONE_CONF" 1 \
			--exclude '/UnusedVault/**'
		# includes subdir!
		test_expect_rclone_files "${TESTRCLONE_NAME}testsubdir" \
			"$TESTRCLONE_CONF" 1 \
			--exclude '/UnusedVault/**'

		# delete no longer existing file in subdir
		rm "$TESTSET_DIR/backup/file2rclone/testsubdir/dummyfile2"
		#shellcheck disable=SC2086 # secretparam intentionally may contain >1 word
		test_exec_backupdocker 0 \
			"backup file2rclone" \
			"$source" \
			"$TESTRCLONE_NAME" \
			--dstsecret /backup/file2rclone.conf \
			$secretparam \
			--exclude '/UnusedVault/**'
		test_expect_rclone_files "$TESTRCLONE_NAME" "$TESTRCLONE_CONF" 1 \
			--exclude '/UnusedVault/**'
		# includes subdir!
		test_expect_rclone_files "${TESTRCLONE_NAME}testsubdir" \
			"$TESTRCLONE_CONF" 0 \
			--exclude '/UnusedVault/**'

		# delete no longer existing subdir
		rmdir "$TESTSET_DIR/backup/file2rclone/testsubdir"
		#shellcheck disable=SC2086 # secretparam intentionally may contain >1 word
		test_exec_backupdocker 0 \
			"backup file2rclone" \
			"$source" \
			"$TESTRCLONE_NAME" \
			--dstsecret /backup/file2rclone.conf \
			$secretparam \
			--exclude '/UnusedVault/**'
		test_expect_rclone_files "$TESTRCLONE_NAME" "$TESTRCLONE_CONF" 0 \
			--exclude '/UnusedVault/**'
	done

	return 0
}

##### Main ###################################################################
# do nothing
test_expect_vardefined \
	TESTRCLONE_CONF \
	TESTRCLONE_NAME
test_chown "$TESTRCLONE_CONF"
