#!/bin/bash
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

	[ ! -z "$source" ] && [ ! -z "$dest" ]
	test_assert "$?" "Internal Error" || return 1

	printf "Testing FILE Backup from %s to %s\n" \
		"$source" "$dest"

	mkdir -p \
		"$TESTSETDIR/backup/file/source" \
		"$TESTSETDIR/backup/file/dest"
	test_assert "$?" "Creating directories" || return 1
	source+="/file/source"
	dest+="/file/dest"

	# backup from non-existing source should fail
	eval $(test_exec_backupdocker 1 \
		"backup file" \
		"$source/thisdirdoesnotexist" \
		"/$dest" \
		"$@" \
		)

	# backup to non-existing dest should work !
	eval $(test_exec_backupdocker 0 \
		"backup file" \
		"$source" \
		"$dest/thisdirdoesnotexist" \
		"$@" \
		) &&
	test_expect_files "backup/file/dest/thisdirdoesnotexist" 0 &&
	rmdir "$TESTSETDIR/backup/file/dest/thisdirdoesnotexist"

	# backup empty path
	eval $(test_exec_backupdocker 0 \
		"backup file" \
		"$source" \
		"$dest" \
		"$@" \
		) &&
	test_expect_files "backup/file/dest" 0

	# rsync parameters with empty path
	eval $(test_exec_backupdocker 0 \
		"backup file" \
		"$source" \
		"$dest" \
		"$@" \
		-- \
		--verbose
		) &&
	test_expect_files "backup/file/dest" 0

	# backup one file
	echo "Dummyfile" >$TESTSETDIR/backup/file/source/dummyfile
	test_assert "$?" "Creating dummyfile" || return 1
	eval $(test_exec_backupdocker 0 \
		"backup file" \
		"$source" \
		"$dest" \
		"$@" \
		) &&
	test_expect_files "backup/file/source" 1

	# backup additional file in subdirectory
	mkdir $TESTSETDIR/backup/file/source/testsubdir
	test_assert "$?" "Creating testsubdir" || return 1
	echo "Dummyfile2" >$TESTSETDIR/backup/file/source/testsubdir/dummyfile2
	test_assert "$?" "Creating dummyfile2" || return 1
	eval $(test_exec_backupdocker 0 \
		"backup file" \
		"$source" \
		"$dest" \
		"$@" \
		) &&
	test_expect_files "backup/file/dest" 2 && # includes subdir!
	test_expect_files "backup/file/dest/testsubdir" 1

	# delete no longer existing file
	rm $TESTSETDIR/backup/file/source/dummyfile
	test_assert "$?" "remove Dummyfile" || return 1
	eval $(test_exec_backupdocker 0 \
		"backup file" \
		"$source" \
		"$dest" \
		"$@" \
		) &&
	test_expect_files "backup/file/dest" 1 && # includes subdir!
	test_expect_files "backup/file/dest/testsubdir" 1

	# delete no longer existing file in subdir
	rm $TESTSETDIR/backup/file/source/testsubdir/dummyfile2
	test_assert "$?" "remove Dummyfile2" || return 1
	eval $(test_exec_backupdocker 0 \
		"backup file" \
		"$source" \
		"$dest" \
		"$@" \
		) &&
	test_expect_files "backup/file/dest" 1 && # includes subdir!
	test_expect_files "backup/file/dest/testsubdir" 0

	# delete no longer existing subdir
	rmdir $TESTSETDIR/backup/file/source/testsubdir
	test_assert "$?" "remove testsubdir" || return 1
	eval $(test_exec_backupdocker 0 \
		"backup file" \
		"$source" \
		"$dest" \
		"$@" \
		) &&
	test_expect_files "backup/file/dest" 0

	rm -rf \
		"$TESTSETDIR/backup/file/source" \
		"$TESTSETDIR/backup/file/dest"
	test_assert "$?" "remove backupdirs" || return 1

	return 0
}

##### Tests for File backup (rsync) ##########################################
function test_file {
    ##### Specific tests for local/remote
	mkdir -p "$TESTSETDIR/backup/file1" "$TESTSETDIR/backup/file2"
	test_assert "$?" "create testdirs" || return 1

	# backup remote source without secret should fail
	eval $(test_exec_backupdocker 1 \
		"backup file" \
		"$my_ip:$TESTSETDIR/backup/file1" \
		/backup/file2 \
		$TEST_RSYNCOPT
		)

	# backup remote dest without secret should fail
	eval $(test_exec_backupdocker 1 \
		"backup file" \
		/backup/file1 \
		"$my_ip:$TESTSETDIR/backup/file2" \
		$TEST_RSYNCOPT
		)

	# backup remote source,dest without secret should fail
	local myhost="$HOST $HOSTNAME" # HOST ist set on MacOS, HOSTNAME on Linux
	eval $(test_exec_backupdocker 1 \
		"backup file" \
		"$my_ip:$TESTSETDIR/backup/file1" \
		"$myhost:$TESTSETDIR/backup/file2" \
		$TEST_RSYNCOPT
		)

	# backup remote source,dest with only source secret should work
	# since remote and source are on same machine
	eval $(test_exec_backupdocker 1 \
		"backup file" \
		"$my_ip:$TESTSETDIR/backup/file1" \
		"$myhost:$TESTSETDIR/backup/file2" \
		--srcsecret /secrets/id_rsa \
		--runonsrc \
		$TEST_RSYNCOPT
		)

	# backup remote source,dest with only source secret should fail
	eval $(test_exec_backupdocker 1 \
		"backup file" \
		"$my_ip:$TESTSETDIR/backup/file1" \
		"$myhost:$TESTSETDIR/backup/file2" \
		--srcsecret /secrets/id_rsa \
		--runonsrc \
		$TEST_RSYNCOPT
		)

	# backup remote source,dest with only dest secret should fail
	eval $(test_exec_backupdocker 1 \
		"backup file" \
		"$my_ip:$TESTSETDIR/backup/file1" \
		"$myhost:$TESTSETDIR/backup/file2" \
		--dstsecret /secrets/id_rsa \
		--runonsrc \
		$TEST_RSYNCOPT
		)
	# backup remote source,dest without runon should fail
	eval $(test_exec_backupdocker 1 \
		"backup file" \
		"$my_ip:$TESTSETDIR/backup/file1" \
		"$myhost:$TESTSETDIR/backup/file2" \
		--srcsecret /secrets/id_rsa \
		--dstsecret /secrets/id_rsa \
		$TEST_RSYNCOPT
		)

	rmdir "$TESTSETDIR/backup/file1" "$TESTSETDIR/backup/file2"
	test_assert "$?" "remove testdirs" || return 1

	##### common tests for all variants source,dest in local,remote
	for source in "/backup" "$my_ip:$TESTSETDIR/backup" ; do
		for dest in "/backup" "$my_ip:$TESTSETDIR/backup" ; do
			secretparm=""
			[[ "$source" == *":"* ]] && 
				secretparm+="--srcsecret /secrets/id_rsa "
			[[ "$dest" == *":"* ]] && 
				secretparm+="--dstsecret /secrets/id_rsa "

			if [[ "$source" == *":"* ]] && [[ "$dest" == *":"* ]] ; then
				test_file_srcdest \
					"$source" \
					"$dest" \
					"$TEST_RSYNCOPT" \
					--runonsrc \
					$secretparm \
				|| return 1

				secretparm+="--runondst "
			fi

			test_file_srcdest \
				"$source" \
				"$dest" \
				"$TEST_RSYNCOPT" \
				$secretparm \
			|| return 1
		done
	done

	return 0
}

##### Main ###################################################################
# do nothing
