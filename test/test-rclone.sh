#!/bin/bash
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
	test_assert "$?" "copy rcloneraw.conf" >&2 || return 1
	test_chown "$TESTSET_DIR/backup/rcloneraw.conf" || return 1

	cp ~/.ssh/id_rsa "$TESTSET_DIR/id_rsa"
	test_assert "$?" "Copy SSH Key" >&2 || return 1
	test_chown "$TESTSET_DIR/id_rsa" || return 1

	test_exec_cmd 0 "Backup Command $*" \
		docker run -i \
			-v "$TESTSET_DIR/backup:/backup" \
			-v "$TESTSET_DIR/id_rsa:/secrets/id_rsa:ro" \
			-e DEBUG=1 \
			--entrypoint /usr/lib/nafets227.backup/rclone \
			"$TESTIMG" \
			--config /backup/rcloneraw.conf \
			"$@"

	if test_exec_issuccess ; then
		return 0
	else
		return 1
	fi
}

function test_cleanRclone () {
	if [ "$#" -ne 2 ] ; then
		printf "%s: Internal Error. Got %s parms (exp=3)\n" \
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

	return $?
}

function test_putRclone () {
	if [ "$#" -lt 2 ] ; then
		printf "%s: Internal Error. Got %s parms (exp=2+)\n" \
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

	return $?
}

function test_expect_rclone_files {
	local rclone_namepath="$1"
	local rclone_conf="$2"
	local testexpected="$3"
	shift 3

	test_rclone_execraw "$rclone_conf" \
		lsf "$rclone_namepath" "$@"

	testresult=$(
		set -o pipefail
		test_get_lastoutput |
		grep --count --invert-match "^#-----"  || [ "$?" == "1" ]
		)

	rc=$?

	if [ "$rc" != 0 ] ; then
		test_assert 1 "Cannot get files in '$rclone_namepath'"
		return 1
	else
		test_expect_value "$testresult" "$testexpected"
		return 0
	fi

	# should not reach this
	#shellcheck disable=SC2317 # intentionally not reachable
	return 99
}


##### Tests for rclone2file ##################################################
function test_rclone2file {
	if \
		! test_assert_files "$TESTRCLONE_CONF"
	then
		printf "\tSkipping rclone Tests.\n"
		return 0
	fi

	if [ -n "$my_ip" ] ; then
		exec_remote=true
	else
		test_assert "1" "Skipping IMAP Remote Tests (ip/ipconfig)"
		exec_remote=false
	fi

	printf "Testing rclone2file using \"%s\" in %s\n" \
		"$TESTRCLONE_NAME" "$TESTRCLONE_CONF"

	cp "$TESTRCLONE_CONF" "$TESTSET_DIR/backup/rclone2file.conf"
	test_assert "$?" "copy rclone2file.conf" || return 1
	test_chown "$TESTSET_DIR/backup/rclone2file.conf" || return 1

	test_cleanRclone "$TESTRCLONE_NAME" "$TESTRCLONE_CONF"
	test_assert "$?" "clean rclone" || return 1

	# rclone OK with Empty Cloud (compatibility "rclone")
	eval "$(test_exec_backupdocker  0 \
		"backup rclone" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file \
		--srcsecret /backup/rclone2file.conf \
		--exclude '/UnusedVault/**' \
		)" &&
	test_expect_files "backup/rclone2file" 0

	# Wrong src, no ":"
	eval "$(test_exec_backupdocker 1 \
		"backup rclone2file" \
		"mydummyname" \
		/backup/rclone2file \
		)"

	# Wrong src, nothing after ":"
	eval "$(test_exec_backupdocker 1 \
		"backup rclone2file" \
		"mydummyname:" \
		/backup/rclone2file \
		--srcsecret /backup/rclone2file.conf \
		)"

	# Wrong src, nothing before ":"
	eval "$(test_exec_backupdocker 1 \
		"backup rclone2file" \
		":mydummyname" \
		/backup/rclone2file \
		--srcsecret /backup/rclone2file.conf \
		)"

	# No password
	eval "$(test_exec_backupdocker 1 \
		"backup rclone2file" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file \
		)"

	# Not existing password file
	eval "$(test_exec_backupdocker 1 \
		"backup rclone2file" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file \
		--srcsecret "filedoesnotexist"
		)"

	# rclone OK with Empty Cloud
	eval "$(test_exec_backupdocker  0 \
		"backup rclone2file" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file \
		--srcsecret /backup/rclone2file.conf \
		--exclude '/UnusedVault/**' \
		)" &&
	test_expect_files "backup/rclone2file" 0

	# rclone OK with Empty Cloud - remote backup dest
	$exec_remote &&
	eval "$(test_exec_backupdocker 0 \
		"backup rclone2file" \
		"$TESTRCLONE_NAME" \
		"$my_ip:$TESTSET_DIR/backup-rem/rclone2file" \
		--srcsecret /backup/rclone2file.conf \
		--dstsecret /secrets/id_rsa \
		--exclude '/UnusedVault/**' \
		)" &&
	test_expect_files "backup-rem/rclone2file" 0

	# Verify modifying conf
	cp "$TESTRCLONE_CONF" "$TESTSET_DIR/backup/rclone-update.conf" &&
	test_assert "$?" "write rclone-update.conf" || return 1
	test_chown "$TESTSET_DIR/backup/rclone-update.conf" || return 1

	test_assert "$?" "write rclone-update.conf" || return 1
	eval "$(test_exec_backupdocker 0 \
		"backup rclone_unittest_updateconf" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file \
		--srcsecret /backup/rclone-update.conf \
		)" &&
	test_exec_cmd "" "" \
		fgrep '[rclone-unittest-dummy]' "$TESTSET_DIR/backup/rclone-update.conf"

	# Verify modifying conf - remote
	cp "$TESTRCLONE_CONF" "$TESTSET_DIR/backup/rclone-update.conf" &&
	test_assert "$?" "write rclone-update.conf" || return 1
	test_chown "$TESTSET_DIR/backup/rclone-update.conf" || return 1
	$exec_remote &&
	eval "$(test_exec_backupdocker 0 \
		"backup rclone_unittest_updateconf" \
		"$TESTRCLONE_NAME" \
		"$my_ip:$TESTSET_DIR/backup-rem/rclone2file" \
		--srcsecret /backup/rclone-update.conf \
		--dstsecret /secrets/id_rsa \
		)" &&
	test_exec_cmd "" "" \
		fgrep '[rclone-unittest-dummy]' "$TESTSET_DIR/backup/rclone-update.conf"

	# Store Testfiles
	test_putRclone "${TESTRCLONE_NAME}test.txt" "$TESTRCLONE_CONF"
	test_assert "$?" "put test.txt on rclone" || return 1
	test_putRclone "${TESTRCLONE_NAME}testdir/testfile.txt" "$TESTRCLONE_CONF"
	test_assert "$?" "put testdir/testfile.txt on rclone" || return 1

	# rclone OK with files
	eval "$(test_exec_backupdocker 0 \
		"backup rclone2file" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file \
		--srcsecret /backup/rclone2file.conf \
		--exclude '/UnusedVault/**' \
		)" &&
	test_expect_files "backup/rclone2file" 2 &&
	test_expect_files "backup/rclone2file/testdir" 1

	# rclone OK with files - remote backup dest
	$exec_remote &&
	eval "$(test_exec_backupdocker 0 \
		"backup rclone2file" \
		"$TESTRCLONE_NAME" \
		"$my_ip:$TESTSET_DIR/backup-rem/rclone2file" \
		--srcsecret /backup/rclone2file.conf \
		--dstsecret /secrets/id_rsa \
		--exclude '/UnusedVault/**' \
		)" &&
	test_expect_files "backup-rem/rclone2file" 2 &&
	test_expect_files "backup-rem/rclone2file/testdir" 1

	test_cleanRclone "$TESTRCLONE_NAME" "$TESTRCLONE_CONF"
	test_assert "$?" "clean rclone" || return 1

	# rclone OK with files deleted
	eval "$(test_exec_backupdocker 0 \
		"backup rclone2file" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file \
		--srcsecret /backup/rclone2file.conf \
		--exclude '/UnusedVault/**' \
		)" &&
	test_expect_files "backup/rclone2file" 0

	# rclone OK with files deleted - remote backup dest
	$exec_remote &&
	eval "$(test_exec_backupdocker 0 \
		"backup rclone2file" \
		"$TESTRCLONE_NAME" \
		"$my_ip:$TESTSET_DIR/backup-rem/rclone2file" \
		--srcsecret /backup/rclone2file.conf \
		--dstsecret /secrets/id_rsa \
		--exclude '/UnusedVault/**' \
		)" &&
	test_expect_files "backup-rem/rclone2file" 0

	return 0
}

##### Tests for rclone2file history ##########################################
function test_rclone2file_hist {
	if \
		! test_assert_files "$TESTRCLONE_CONF"
	then
		printf "\tSkipping rclone Tests.\n"
		return 0
	fi

	printf "Testing rclone history using \"%s\" in %s\n" \
		"$TESTRCLONE_NAME" "$TESTRCLONE_CONF"

	cp "$TESTRCLONE_CONF" "$TESTSET_DIR/backup/rclone2file-hist.conf"
	test_assert "$?" "copy rclone2file-hist.conf" || return 1
	test_chown "$TESTSET_DIR/backup/rclone2file-hist.conf" || return 1

	test_cleanRclone "$TESTRCLONE_NAME" "$TESTRCLONE_CONF"
	test_assert "$?" "clean rclone" || return 1

	# Time 1+2: Empty Cloud
	eval "$(test_exec_backupdocker  0 \
		"backup rclone2file" \
		--hist \
		--histdate "2022-03-01" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file-hist \
		--srcsecret /backup/rclone2file-hist.conf \
		--exclude '/UnusedVault/**' \
		)"
	eval "$(test_exec_backupdocker  0 \
		"backup rclone2file" \
		--hist \
		--histdate "2022-03-02" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file-hist \
		--srcsecret /backup/rclone2file-hist.conf \
		--exclude '/UnusedVault/**' \
		)"

	# Time 10+11: Added file
	test_putRclone "${TESTRCLONE_NAME}test.txt" "$TESTRCLONE_CONF" "rclone-hist-1"
	test_assert "$?" "put test.txt on rclone" || return 1
	test_putRclone "${TESTRCLONE_NAME}testdir/testfile.txt" \
		"$TESTRCLONE_CONF" "rclone-hist-1"
	test_assert "$?" "put testdir/testfile.txt on rclone" || return 1
	eval "$(test_exec_backupdocker  0 \
		"backup rclone2file" \
		--hist \
		--histdate "2022-03-10" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file-hist \
		--srcsecret /backup/rclone2file-hist.conf \
		--exclude '/UnusedVault/**' \
		)"
	eval "$(test_exec_backupdocker  0 \
		"backup rclone2file" \
		--hist \
		--histdate "2022-03-11" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file-hist \
		--srcsecret /backup/rclone2file-hist.conf \
		--exclude '/UnusedVault/**' \
		)"

	# Time 20+21: modified file
	test_putRclone "${TESTRCLONE_NAME}test.txt" "$TESTRCLONE_CONF" \
		"rclone-hist-2"
	test_assert "$?" "put test.txt on rclone" || return 1
	test_putRclone "${TESTRCLONE_NAME}testdir/testfile.txt" \
		"$TESTRCLONE_CONF" "rclone-hist-2"
	test_assert "$?" "put testdir/testfile.txt on rclone" || return 1
	eval "$(test_exec_backupdocker  0 \
		"backup rclone2file" \
		--hist \
		--histdate "2022-03-20" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file-hist \
		--srcsecret /backup/rclone2file-hist.conf \
		--exclude '/UnusedVault/**' \
		)"
	eval "$(test_exec_backupdocker  0 \
		"backup rclone2file" \
		--hist \
		--histdate "2022-03-21" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file-hist \
		--srcsecret /backup/rclone2file-hist.conf \
		--exclude '/UnusedVault/**' \
		)"

	# Time 30: deleted file
	test_cleanRclone "$TESTRCLONE_NAME" "$TESTRCLONE_CONF"
	test_assert "$?" "clean rclone" || return 1
	eval "$(test_exec_backupdocker  0 \
		"backup rclone2file" \
		--hist \
		--histdate "2022-03-30" \
		"$TESTRCLONE_NAME" \
		/backup/rclone2file-hist \
		--srcsecret /backup/rclone2file-hist.conf \
		--exclude '/UnusedVault/**' \
		)"

	# Finally check:
	test_expect_files "backup/rclone2file-hist/2022/03/01" 0
	test_expect_files "backup/rclone2file-hist/2022/03/02" 0

	test_expect_files "backup/rclone2file-hist/2022/03/10" 2
	test_expect_files "backup/rclone2file-hist/2022/03/11" 2
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

	test_expect_files "backup/rclone2file-hist/2022/03/20" 2
	test_expect_files "backup/rclone2file-hist/2022/03/21" 2
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

	test_expect_files "backup/rclone2file-hist/2022/03/30" 0

	return 0
}

##### Tests for file2rclone ##################################################
function test_file2rclone {
	if \
		! test_assert_files "$TESTRCLONE_CONF"
	then
		printf "\tSkipping file2rclone Tests.\n"
		return 0
	fi

	printf "Testing file2rclone using \"%s\" in %s\n" \
		"$TESTRCLONE_NAME" "$TESTRCLONE_CONF"

	cp "$TESTRCLONE_CONF" "$TESTSET_DIR/backup/file2rclone.conf"
	test_assert "$?" "copy file2rclone.conf" || return 1
	test_chown "$TESTSET_DIR/backup/file2rclone.conf" || return 1

	test_cleanRclone "$TESTRCLONE_NAME" "$TESTRCLONE_CONF"
	test_assert "$?" "clean rclone" || return 1

	mkdir -p \
		"$TESTSET_DIR/backup/file2rclone"
	test_assert "$?" "Creating directories" || return 1

	# Wrong dst, no ":"
	eval "$(test_exec_backupdocker 1 \
		"backup file2rclone" \
		/backup/file2rclone \
		"mydummyname" \
		)"

	# Wrong dst, nothing after ":"
	eval "$(test_exec_backupdocker 1 \
		"backup file2rclone" \
		/backup/file2rclone \
		"mydummyname:" \
		--dstsecret /backup/file2rclone.conf \
		)"

	# Wrong dst, nothing before ":"
	eval "$(test_exec_backupdocker 1 \
		"backup file2rclone" \
		/backup/file2rclone \
		":mydummyname" \
		--dstsecret /backup/file2rclone.conf \
		)"

	# No password
	eval "$(test_exec_backupdocker 1 \
		"backup file2rclone" \
		/backup/file2rclone \
		"$TESTRCLONE_NAME" \
		)"

	# Not existing password file
	eval "$(test_exec_backupdocker 1 \
		"backup file2rclone" \
		/backup/file2rclone \
		"$TESTRCLONE_NAME" \
		--dstsecret "filedoesnotexist" \
		)"

	# remote source without source secret
	eval "$(test_exec_backupdocker 1 \
		"backup file2rclone" \
		"$my_ip:$TESTSET_DIR/backup/file2rclone" \
		"$TESTRCLONE_NAME" \
		--dstsecret /backup/file2rclone.conf \
		)"

	for source in "/backup/file2rclone" "$my_ip:$TESTSET_DIR/backup/file2rclone"
	do
		secretparm=""
		if [[ "$source" == *":"* ]] ; then
			secretparm+="--srcsecret /secrets/id_rsa "
		fi

		test_cleanRclone "$TESTRCLONE_NAME" "$TESTRCLONE_CONF"
		test_assert "$?" "clean rclone" || return 1

		# backup from non-existing source should fail
		#shellcheck disable=SC2086 # secretparm intentionally may conatain >1 word
		eval "$(test_exec_backupdocker 1 \
			"backup file2rclone" \
			"$source/thisdirdoesnotexist" \
			"$TESTRCLONE_NAME" \
			--dstsecret /backup/file2rclone.conf \
			$secretparm \
			--exclude '/UnusedVault/**' \
			)"

		# history backup should fail
		#shellcheck disable=SC2086 # secretparm intentionally may conatain >1 word
		eval "$(test_exec_backupdocker 1 \
			"backup file2rclone" \
			"$source" \
			"$TESTRCLONE_NAME" \
			--dstsecret /backup/file2rclone.conf \
			$secretparm \
			--hist \
			--exclude '/UnusedVault/**' \
			)"

		# rclone OK with Empty Dir
		#shellcheck disable=SC2086 # secretparm intentionally may conatain >1 word
		eval "$(test_exec_backupdocker 0 \
			"backup file2rclone" \
			"$source" \
			"$TESTRCLONE_NAME" \
			--dstsecret /backup/file2rclone.conf \
			$secretparm \
			--exclude '/UnusedVault/**' \
			)" &&
		test_expect_rclone_files "$TESTRCLONE_NAME" "$TESTRCLONE_CONF" 0

		# backup one file
		cat >"$TESTSET_DIR/backup/file2rclone/dummyfile" <<<"Dummyfile"
		test_assert "$?" "Creating dummyfile" || return 1
		#shellcheck disable=SC2086 # secretparm intentionally may conatain >1 word
		eval "$(test_exec_backupdocker 0 \
			"backup file2rclone" \
			"$source" \
			"$TESTRCLONE_NAME" \
			--dstsecret /backup/file2rclone.conf \
			$secretparm \
			"$@" \
			--exclude '/UnusedVault/**' \
			)" &&
		test_expect_rclone_files "$TESTRCLONE_NAME" "$TESTRCLONE_CONF" 1

		# backup additional file in subdirectory
		mkdir "$TESTSET_DIR/backup/file2rclone/testsubdir"
		test_assert "$?" "Creating testsubdir" || return 1
		cat >"$TESTSET_DIR/backup/file2rclone/testsubdir/dummyfile2" <<<"Dummyfile2"
		test_assert "$?" "Creating dummyfile2" || return 1
		#shellcheck disable=SC2086 # secretparm intentionally may conatain >1 word
		eval "$(test_exec_backupdocker 0 \
			"backup file2rclone" \
			"$source" \
			"$TESTRCLONE_NAME" \
			--dstsecret /backup/file2rclone.conf \
			$secretparm \
			"$@" \
			--exclude '/UnusedVault/**' \
			)" &&
		test_expect_rclone_files "$TESTRCLONE_NAME" "$TESTRCLONE_CONF" 2 &&
		# includes subdir!
		test_expect_rclone_files "${TESTRCLONE_NAME}testsubdir" \
			"$TESTRCLONE_CONF" 1

		# delete no longer existing file
		rm "$TESTSET_DIR/backup/file2rclone/dummyfile"
		test_assert "$?" "remove Dummyfile" || return 1
		#shellcheck disable=SC2086 # secretparm intentionally may conatain >1 word
		eval "$(test_exec_backupdocker 0 \
			"backup file2rclone" \
			"$source" \
			"$TESTRCLONE_NAME" \
			--dstsecret /backup/file2rclone.conf \
			$secretparm \
			"$@" \
			--exclude '/UnusedVault/**' \
			)" &&
		test_expect_rclone_files "$TESTRCLONE_NAME" "$TESTRCLONE_CONF" 1 &&
		# includes subdir!
		test_expect_rclone_files "${TESTRCLONE_NAME}testsubdir" \
			"$TESTRCLONE_CONF" 1

		# delete no longer existing file in subdir
		rm "$TESTSET_DIR/backup/file2rclone/testsubdir/dummyfile2"
		test_assert "$?" "remove Dummyfile2" || return 1
		#shellcheck disable=SC2086 # secretparm intentionally may conatain >1 word
		eval "$(test_exec_backupdocker 0 \
			"backup file2rclone" \
			"$source" \
			"$TESTRCLONE_NAME" \
			--dstsecret /backup/file2rclone.conf \
			$secretparm \
			"$@" \
			--exclude '/UnusedVault/**' \
			)" &&
		test_expect_rclone_files "$TESTRCLONE_NAME" "$TESTRCLONE_CONF" 1 &&
		# includes subdir!
		test_expect_rclone_files "${TESTRCLONE_NAME}testsubdir" \
			"$TESTRCLONE_CONF" 0

		# delete no longer existing subdir
		rmdir "$TESTSET_DIR/backup/file2rclone/testsubdir"
		test_assert "$?" "remove testsubdir" || return 1
		#shellcheck disable=SC2086 # secretparm intentionally may conatain >1 word
		eval "$(test_exec_backupdocker 0 \
			"backup file2rclone" \
			"$source" \
			"$TESTRCLONE_NAME" \
			--dstsecret /backup/file2rclone.conf \
			$secretparm \
			"$@" \
			--exclude '/UnusedVault/**' \
			)" &&
		test_expect_rclone_files "$TESTRCLONE_NAME" "$TESTRCLONE_CONF" 0

		true || return 1

	done

	return 0
}

##### Main ###################################################################
# do nothing
