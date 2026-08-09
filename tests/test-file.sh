#!/usr/bin/env bash
#
# Backup in Docker container
#
# (C) 2017-2020 Stefan Schallenberg
#
# Test script for File

##### test_file_srcdest ######################################################
function test_file_srcdest {
	local source="$1"
	local dest="$2"
	shift 2

	[ -n "$source" ] && [ -n "$dest" ] # exits if false because set -e

	printf "Testing FILE Backup from %s to %s\n" \
		"$source" "$dest"

	mkdir -p \
		"$TESTSET_DIR/backup/file/source" \
		"$TESTSET_DIR/backup/file/dest"
	test_chown "$TESTSET_DIR/backup/file"
	test_chown "$TESTSET_DIR/backup/file/source"
	test_chown "$TESTSET_DIR/backup/file/dest"

	source+="/file/source"
	dest+="/file/dest"

	# backup from non-existing source should fail
	test_exec_backupdocker 1 \
		"backup file" \
		"$source/thisdirdoesnotexist" \
		"/$dest" \
		"$@"

	# backup to non-existing dest should work !
	test_exec_backupdocker 0 \
		"backup file" \
		"$source" \
		"$dest/thisdirdoesnotexist" \
		"$@"
	test_expect_filecount "backup/file/dest/thisdirdoesnotexist" 0
	rmdir "$TESTSET_DIR/backup/file/dest/thisdirdoesnotexist"

	# backup empty path
	test_exec_backupdocker 0 \
		"backup file" \
		"$source" \
		"$dest" \
		"$@"
	test_expect_filecount "backup/file/dest" 0

	# rsync parameters with empty path
	test_exec_backupdocker 0 \
		"backup file" \
		"$source" \
		"$dest" \
		"$@" \
		-- \
		--verbose
	test_expect_filecount "backup/file/dest" 0

	# backup one file
	cat >"$TESTSET_DIR/backup/file/source/dummyfile" <<<"Dummyfile"
	test_exec_backupdocker 0 \
		"backup file" \
		"$source" \
		"$dest" \
		"$@"
	test_expect_filecount "backup/file/source" 1

	# backup additional file in subdirectory
	mkdir "$TESTSET_DIR/backup/file/source/testsubdir"
	cat >"$TESTSET_DIR/backup/file/source/testsubdir/dummyfile2" <<<"Dummyfile2"
	test_exec_backupdocker 0 \
		"backup file" \
		"$source" \
		"$dest" \
		"$@"
	test_expect_filecount "backup/file/dest" 2 # includes subdir!
	test_expect_filecount "backup/file/dest/testsubdir" 1

	# delete no longer existing file
	rm "$TESTSET_DIR/backup/file/source/dummyfile"
	test_exec_backupdocker 0 \
		"backup file" \
		"$source" \
		"$dest" \
		"$@"
	test_expect_filecount "backup/file/dest" 1 # includes subdir!
	test_expect_filecount "backup/file/dest/testsubdir" 1

	# delete no longer existing file in subdir
	rm "$TESTSET_DIR/backup/file/source/testsubdir/dummyfile2"
	test_exec_backupdocker 0 \
		"backup file" \
		"$source" \
		"$dest" \
		"$@"
	test_expect_filecount "backup/file/dest" 1 # includes subdir!
	test_expect_filecount "backup/file/dest/testsubdir" 0

	# delete no longer existing subdir
	rmdir "$TESTSET_DIR/backup/file/source/testsubdir"
	test_exec_backupdocker 0 \
		"backup file" \
		"$source" \
		"$dest" \
		"$@"
	test_expect_filecount "backup/file/dest" 0

	rm -rf \
		"$TESTSET_DIR/backup/file/source" \
		"$TESTSET_DIR/backup/file/dest"

	return 0
}

##### Tests for File backup (rsync) ##########################################
function test_file {
	: "${my_ip:=""} ${my_host:=""} ${my_fileopt:=""}"

	##### Specific tests for local/remote
	mkdir -p "$TESTSET_DIR/backup/file1" "$TESTSET_DIR/backup/file2"

	# backup remote source without secret should fail
	#shellcheck disable=SC2086
	# TEST_RSYNCOPE intentionally may contain 0,1 or more words
	test_exec_backupdocker 1 \
		"backup file $my_fileopt" \
		"$my_ip:$TESTSET_DIR/backup/file1" \
		/backup/file2 \
		$TEST_RSYNCOPT

	# backup remote dest without secret should fail
	#shellcheck disable=SC2086
	# TEST_RSYNCOPE intentionally may contain 0,1 or more words
	test_exec_backupdocker 1 \
		"backup file $my_fileopt" \
		/backup/file1 \
		"$my_ip:$TESTSET_DIR/backup/file2" \
		$TEST_RSYNCOPT

	# backup remote source,dest without secret should fail
	#shellcheck disable=SC2086
	# TEST_RSYNCOPE intentionally may contain 0,1 or more words
	test_exec_backupdocker 1 \
		"backup file $my_fileopt" \
		"$my_ip:$TESTSET_DIR/backup/file1" \
		"$my_host:$TESTSET_DIR/backup/file2" \
		$TEST_RSYNCOPT

	# backup remote source,dest with only source secret should work
	# since remote and source are on same machine
	#shellcheck disable=SC2086
	# TEST_RSYNCOPE intentionally may contain 0,1 or more words
	test_exec_backupdocker 1 \
		"backup file $my_fileopt" \
		"$my_ip:$TESTSET_DIR/backup/file1" \
		"$my_host:$TESTSET_DIR/backup/file2" \
		--srcsecret /secrets/id_ed25519 \
		--runonsrc \
		$TEST_RSYNCOPT

	# backup remote source,dest with only source secret should fail
	#shellcheck disable=SC2086
	# TEST_RSYNCOPE intentionally may contain 0,1 or more words
	test_exec_backupdocker 1 \
		"backup file $my_fileopt" \
		"$my_ip:$TESTSET_DIR/backup/file1" \
		"$my_host:$TESTSET_DIR/backup/file2" \
		--srcsecret /secrets/id_ed25519 \
		--runonsrc \
		$TEST_RSYNCOPT

	# backup remote source,dest with only dest secret should fail
	#shellcheck disable=SC2086
	# TEST_RSYNCOPE intentionally may contain 0,1 or more words
	test_exec_backupdocker 1 \
		"backup file $my_fileopt" \
		"$my_ip:$TESTSET_DIR/backup/file1" \
		"$my_host:$TESTSET_DIR/backup/file2" \
		--dstsecret /secrets/id_ed25519 \
		--runonsrc \
		$TEST_RSYNCOPT
	# backup remote source,dest without runon should fail
	#shellcheck disable=SC2086
	# TEST_RSYNCOPE intentionally may contain 0,1 or more words
	test_exec_backupdocker 1 \
		"backup file $my_fileopt" \
		"$my_ip:$TESTSET_DIR/backup/file1" \
		"$my_host:$TESTSET_DIR/backup/file2" \
		--srcsecret /secrets/id_ed25519 \
		--dstsecret /secrets/id_ed25519 \
		$TEST_RSYNCOPT

	rmdir "$TESTSET_DIR/backup/file1" "$TESTSET_DIR/backup/file2"

	##### common tests for all variants source,dest in local,remote
	for source in "/backup" "$my_ip:$TESTSET_DIR/backup" ; do
		for dest in "/backup" "$my_ip:$TESTSET_DIR/backup" ; do
			secretparam=""
			[[ "$source" == *":"* ]] &&
				secretparam+="--srcsecret /secrets/id_ed25519 "
			[[ "$dest" == *":"* ]] &&
				secretparam+="--dstsecret /secrets/id_ed25519 "

			if [[ "$source" == *":"* ]] && [[ "$dest" == *":"* ]] ; then
				#shellcheck disable=SC2086 # secretparam intentionally may contain >1 word
				test_file_srcdest \
					"$source" \
					"$dest" \
					"$my_fileopt $TEST_RSYNCOPT" \
					--runonsrc \
					$secretparam

				secretparam+="--runondst "
			fi

			#shellcheck disable=SC2086 # secretparam intentionally may contain >1 word
			test_file_srcdest \
				"$source" \
				"$dest" \
				"$my_fileopt $TEST_RSYNCOPT" \
				$secretparam
		done
	done

	return 0
}

##### Main ###################################################################
# do nothing
