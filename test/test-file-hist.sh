#!/bin/bash
#
# Backup in Docker container
#
# (C) 2017-2020 Stefan Schallenberg
#
# Test script for File in history mode

##### test_file_hist_srcdest #################################################
function test_file_hist_srcdest {
	local source="$1"
	local dest="$2"
	shift 2

	[ -n "$source" ] && [ -n "$dest" ]
	test_assert "$?" "Internal Error in ${FUNCNAME[0]}" || return 1

	printf "Testing FILE HISTORY Backup from %s to %s\n" \
		"$source" "$dest"

	mkdir -p \
		"$TESTSET_DIR/backup/file-hist/source" \
		"$TESTSET_DIR/backup/file-hist/dest"
	test_assert "$?" "Creating directories in ${FUNCNAME[0]}" || return 1
	test_chown "$TESTSET_DIR/backup/file-hist" || return 1
	test_chown "$TESTSET_DIR/backup/file-hist/source" || return 1
	test_chown "$TESTSET_DIR/backup/file-hist/dest" || return 1

	source+="/file-hist/source"
	dest+="/file-hist/dest"

	# backup from non-existing source should fail
	eval "$(test_exec_backupdocker 1 \
		"backup file" \
		--hist \
		--histdate "2020-10-01" \
		"$source/thisdirdoesnotexist" \
		"/$dest" \
		"$@" \
		)"

	# backup to non-existing dest should work !
	eval "$(test_exec_backupdocker 0 \
		"backup file" \
		--hist \
		--histdate "2020-10-10" \
		"$source" \
		"$dest/thisdirdoesnotexist" \
		"$@" \
		)" &&
	test_expect_files "backup/file-hist/dest/thisdirdoesnotexist/2020/10/10" 0 &&
	rmdir \
		"$TESTSET_DIR/backup/file-hist/dest/thisdirdoesnotexist/2020/10/10" \
		"$TESTSET_DIR/backup/file-hist/dest/thisdirdoesnotexist/2020/10" \
		"$TESTSET_DIR/backup/file-hist/dest/thisdirdoesnotexist/2020" \
		"$TESTSET_DIR/backup/file-hist/dest/thisdirdoesnotexist"

	# backup empty path
	eval "$(test_exec_backupdocker 0 \
		"backup file" \
		--hist \
		--histdate "2020-10-11" \
		"$source" \
		"$dest" \
		"$@" \
		)"

	# backup one file
	cat >"$TESTSET_DIR/backup/file-hist/source/dummyfile" <<<"Dummyfile"
	test_assert "$?" "Creating dummyfile" || return 1
	test_chown "$TESTSET_DIR/backup/file-hist/source/dummyfile" || return 1
	eval "$(test_exec_backupdocker 0 \
		"backup file" \
		--hist \
		--histdate "2020-10-12" \
		"$source" \
		"$dest" \
		"$@" \
		)"

	# backup additional file in subdirectory
	mkdir "$TESTSET_DIR/backup/file-hist/source/testsubdir"
	test_assert "$?" "Creating testsubdir" || return 1
	test_chown "$TESTSET_DIR/backup/file-hist/source/testsubdir" || return 1
	cat >"$TESTSET_DIR/backup/file-hist/source/testsubdir/dummyfile2" \
		<<<"Dummyfile2"
	test_assert "$?" "Creating dummyfile2" || return 1
	test_chown "$TESTSET_DIR/backup/file-hist/source/testsubdir/dummyfile2" \
		|| return 1
	eval "$(test_exec_backupdocker 0 \
		"backup file" \
		--hist \
		--histdate "2020-10-13" \
		"$source" \
		"$dest" \
		"$@" \
		)"

	# delete no longer existing file
	rm "$TESTSET_DIR/backup/file-hist/source/dummyfile"
	test_assert "$?" "remove Dummyfile" || return 1
	eval "$(test_exec_backupdocker 0 \
		"backup file" \
		--hist \
		--histdate "2020-10-14" \
		"$source" \
		"$dest" \
		"$@" \
		)"

	# delete no longer existing file in subdir
	rm "$TESTSET_DIR/backup/file-hist/source/testsubdir/dummyfile2"
	test_assert "$?" "remove Dummyfile2" || return 1
	eval "$(test_exec_backupdocker 0 \
		"backup file" \
		--hist \
		--histdate "2020-10-15" \
		"$source" \
		"$dest" \
		"$@" \
		)"

	# delete no longer existing subdir
	rmdir "$TESTSET_DIR/backup/file-hist/source/testsubdir"
	test_assert "$?" "remove testsubdir" || return 1
	eval "$(test_exec_backupdocker 0 \
		"backup file" \
		--hist \
		--histdate "2020-10-16" \
		"$source" \
		"$dest" \
		"$@" \
		)"

	test_expect_files "backup/file-hist/dest/2020/10/11" 0
	test_expect_files "backup/file-hist/dest/2020/10/12" 1
	test_expect_files "backup/file-hist/dest/2020/10/13" 2 && # includes subdir!
	test_expect_files "backup/file-hist/dest/2020/10/13/testsubdir" 1
	test_expect_files "backup/file-hist/dest/2020/10/14" 1 && # includes subdir!
	test_expect_files "backup/file-hist/dest/2020/10/14/testsubdir" 1
	test_expect_files "backup/file-hist/dest/2020/10/15" 1 && # includes subdir!
	test_expect_files "backup/file-hist/dest/2020/10/15/testsubdir" 0
	test_expect_files "backup/file-hist/dest/2020/10/16" 0

	rm -rf \
		"$TESTSET_DIR/backup/file-hist/source" \
		"$TESTSET_DIR/backup/file-hist/dest"
	test_assert "$?" "remove backupdirs" || return 1

	return 0
}

##### Tests for File backup (rsync) ##########################################
function test_file_hist {
	: "${my_ip:=""} ${my_host:=""} ${my_fileopt:=""}"
	##### Specific tests for local/remote
	mkdir -p \
		"$TESTSET_DIR/backup/file-hist-1" \
		"$TESTSET_DIR/backup/file-hist-2"
	test_assert "$?" "Init ${FUNCNAME[0]}" || return 1
	test_chown "$TESTSET_DIR/backup/file-hist-1" || return 1
	test_chown "$TESTSET_DIR/backup/file-hist-2" || return 1

	# backup remote source without secret should fail
	eval "$(test_exec_backupdocker 1 \
		"backup file $my_fileopt" \
		--hist \
		--histdate "2020-09-01" \
		"$my_ip:$TESTSET_DIR/backup/file-hist-1" \
		/backup/file2 \
		"$TEST_RSYNCOPT"
		)"

	# backup remote dest without secret should fail
	eval "$(test_exec_backupdocker 1 \
		"backup file $my_fileopt" \
		--hist \
		--histdate "2020-09-01" \
		/backup/file1 \
		"$my_ip:$TESTSET_DIR/backup/file-hist-2" \
		"$TEST_RSYNCOPT"
		)"

	# backup remote source,dest without secret should fail
	eval "$(test_exec_backupdocker 1 \
		"backup file $my_fileopt" \
		--hist \
		--histdate "2020-09-01" \
		"$my_ip:$TESTSET_DIR/backup/file-hist-1" \
		"$my_host:$TESTSET_DIR/backup/file-hist-2" \
		"$TEST_RSYNCOPT"
		)"

	# backup remote source,dest with only source secret should work
	# since remote and source are on same machine
	eval "$(test_exec_backupdocker 1 \
		"backup file $my_fileopt" \
		--hist \
		--histdate "2020-09-01" \
		"$my_ip:$TESTSET_DIR/backup/file-hist-1" \
		"$my_host:$TESTSET_DIR/backup/file-hist-2" \
		--srcsecret /secrets/id_rsa \
		--runonsrc \
		"$TEST_RSYNCOPT"
		)"

	# backup remote source,dest with only source secret should fail
	eval "$(test_exec_backupdocker 1 \
		"backup file $my_fileopt" \
		--hist \
		--histdate "2020-09-01" \
		"$my_ip:$TESTSET_DIR/backup/file-hist-1" \
		"$my_host:$TESTSET_DIR/backup/file-hist-2" \
		--srcsecret /secrets/id_rsa \
		--runonsrc \
		"$TEST_RSYNCOPT"
		)"

	# backup remote source,dest with only dest secret should fail
	eval "$(test_exec_backupdocker 1 \
		"backup file $my_fileopt" \
		--hist \
		--histdate "2020-09-01" \
		"$my_ip:$TESTSET_DIR/backup/file-hist-1" \
		"$my_host:$TESTSET_DIR/backup/file-hist-2" \
		--dstsecret /secrets/id_rsa \
		--runonsrc \
		"$TEST_RSYNCOPT"
		)"
	# backup remote source,dest without runon should fail
	eval "$(test_exec_backupdocker 1 \
		"backup file $my_fileopt" \
		--hist \
		--histdate "2020-09-01" \
		"$my_ip:$TESTSET_DIR/backup/file-hist-1" \
		"$my_host:$TESTSET_DIR/backup/file-hist-2" \
		--srcsecret /secrets/id_rsa \
		--dstsecret /secrets/id_rsa \
		"$TEST_RSYNCOPT"
		)"

	rmdir "$TESTSET_DIR/backup/file-hist-1" "$TESTSET_DIR/backup/file-hist-2"
	test_assert "$?" "remove testdirs in ${FUNCNAME[0]}" || return 1

	##### common tests for all variants source,dest in local,remote
	#shellcheck disable=SC2043
	for dest in "/backup" ; do
		for source in "/backup" "$my_ip:$TESTSET_DIR/backup" ; do
			secretparm=""
			[[ "$source" == *":"* ]] &&
				secretparm+="--srcsecret /secrets/id_rsa "

			#shellcheck disable=SC2086 # secretparm intentionally may conatain >1 word
			test_file_hist_srcdest \
				"$source" \
				"$dest" \
				"$my_fileopt $TEST_RSYNCOPT" \
				$secretparm \
			|| return 1
		done
	done

	#shellcheck disable=SC2066
	for dest in "$my_ip:$TESTSET_DIR/backup" ; do
		#shellcheck disable=SC2043
		for source in "/backup" ; do
			# Backup to remote in history mod should fail
			eval "$(test_exec_backupdocker 1 \
				"backup file $my_fileopt" \
				--hist \
				--histdate "2020-10-01" \
				"$source" \
				"$dest" \
				"$TEST_RSYNCOPT" \
				--runonsrc \
				--dstsecret /secrets/id_rsa \
				)"
		done
		for source in  "$my_ip:$TESTSET_DIR/backup" ; do
			if [[ $source == *":"* ]] ; then
				secretparm="--srcsecret /secrets/id_rsa "
				secretparm+="--dstsecret /secrets/id_rsa "
			fi

			# Backup to remote in history mod should fail if running on src
			# BUT since our src and dst are equal, we cannot test this situation

			# Backup to remote in history mod should work if running on dst
			#shellcheck disable=SC2086 # secretparm intentionally may conatain >1 word
			test_file_hist_srcdest \
				"$source" \
				"$dest" \
				"$my_fileopt $TEST_RSYNCOPT" \
				--runondst \
				$secretparm \
			|| return 1
		done
	done

	# Test --histkeep only with local/local
	#shellcheck disable=SC2086 # secretparm intentionally may conatain >1 word
	test_file_hist_srcdest \
		"/backup" \
		"/backup" \
		"$TEST_RSYNCOPT" \
		$secretparm \
		--histkeep \
	|| return 1


	return 0
}

##### Main ###################################################################
# do nothing
