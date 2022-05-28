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

	[ ! -z "$source" ] && [ ! -z "$dest" ]
	test_assert "$?" "Internal Error in $FUNCNAME" || return 1

	printf "Testing FILE HISTORY Backup from %s to %s\n" \
		"$source" "$dest"

	mkdir -p \
		"$TESTSETDIR/backup/file-hist/source" \
		"$TESTSETDIR/backup/file-hist/dest"
	test_assert "$?" "Creating directories in $FUNCNAME" || return 1

	source+="/file-hist/source"
	dest+="/file-hist/dest"

	# backup from non-existing source should fail
	eval $(test_exec_backupdocker 1 \
		"backup file" \
		--hist \
		--histdate "2020-10-01" \
		"$source/thisdirdoesnotexist" \
		"/$dest" \
		"$@" \
		)

	# backup to non-existing dest should work !
	eval $(test_exec_backupdocker 0 \
		"backup file" \
		--hist \
		--histdate "2020-10-10" \
		"$source" \
		"$dest/thisdirdoesnotexist" \
		"$@" \
		) &&
	test_expect_files "backup/file-hist/dest/thisdirdoesnotexist/2020/10/10" 0 &&
	rmdir \
		"$TESTSETDIR/backup/file-hist/dest/thisdirdoesnotexist/2020/10/10" \
		"$TESTSETDIR/backup/file-hist/dest/thisdirdoesnotexist/2020/10" \
		"$TESTSETDIR/backup/file-hist/dest/thisdirdoesnotexist/2020" \
		"$TESTSETDIR/backup/file-hist/dest/thisdirdoesnotexist"

	# backup empty path
	eval $(test_exec_backupdocker 0 \
		"backup file" \
		--hist \
		--histdate "2020-10-11" \
		"$source" \
		"$dest" \
		"$@" \
		)

	# backup one file
	echo "Dummyfile" >$TESTSETDIR/backup/file-hist/source/dummyfile
	test_assert "$?" "Creating dummyfile" || return 1
	eval $(test_exec_backupdocker 0 \
		"backup file" \
		--hist \
		--histdate "2020-10-12" \
		"$source" \
		"$dest" \
		"$@" \
		)

	# backup additional file in subdirectory
	mkdir $TESTSETDIR/backup/file-hist/source/testsubdir
	test_assert "$?" "Creating testsubdir" || return 1
	echo "Dummyfile2" >$TESTSETDIR/backup/file-hist/source/testsubdir/dummyfile2
	test_assert "$?" "Creating dummyfile2" || return 1
	eval $(test_exec_backupdocker 0 \
		"backup file" \
		--hist \
		--histdate "2020-10-13" \
		"$source" \
		"$dest" \
		"$@" \
		)

	# delete no longer existing file
	rm $TESTSETDIR/backup/file-hist/source/dummyfile
	test_assert "$?" "remove Dummyfile" || return 1
	eval $(test_exec_backupdocker 0 \
		"backup file" \
		--hist \
		--histdate "2020-10-14" \
		"$source" \
		"$dest" \
		"$@" \
		)

	# delete no longer existing file in subdir
	rm $TESTSETDIR/backup/file-hist/source/testsubdir/dummyfile2
	test_assert "$?" "remove Dummyfile2" || return 1
	eval $(test_exec_backupdocker 0 \
		"backup file" \
		--hist \
		--histdate "2020-10-15" \
		"$source" \
		"$dest" \
		"$@" \
		)

	# delete no longer existing subdir
	rmdir $TESTSETDIR/backup/file-hist/source/testsubdir
	test_assert "$?" "remove testsubdir" || return 1
	eval $(test_exec_backupdocker 0 \
		"backup file" \
		--hist \
		--histdate "2020-10-16" \
		"$source" \
		"$dest" \
		"$@" \
		)

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
		"$TESTSETDIR/backup/file-hist/source" \
		"$TESTSETDIR/backup/file-hist/dest"
	test_assert "$?" "remove backupdirs" || return 1

	return 0
}

##### Tests for File backup (rsync) ##########################################
function test_file_hist {
    ##### Specific tests for local/remote
	mkdir -p \
		"$TESTSETDIR/backup/file-hist-1" \
		"$TESTSETDIR/backup/file-hist-2"
	test_assert "$?" "Init $FUNCNAME" || return 1

	# backup remote source without secret should fail
	eval $(test_exec_backupdocker 1 \
		"backup file" \
		--hist \
		--histdate "2020-09-01" \
		"$my_ip:$TESTSETDIR/backup/file-hist-1" \
		/backup/file2 \
		$rsync_opt
		)

	# backup remote dest without secret should fail
	eval $(test_exec_backupdocker 1 \
		"backup file" \
		--hist \
		--histdate "2020-09-01" \
		/backup/file1 \
		"$my_ip:$TESTSETDIR/backup/file-hist-2" \
		$rsync_opt
		)

	# backup remote source,dest without secret should fail
	local myhost="$HOST $HOSTNAME" # HOST ist set on MacOS, HOSTNAME on Linux
	eval $(test_exec_backupdocker 1 \
		"backup file" \
		--hist \
		--histdate "2020-09-01" \
		"$my_ip:$TESTSETDIR/backup/file-hist-1" \
		"$myhost:$TESTSETDIR/backup/file-hist-2" \
		$rsync_opt
		)

	# backup remote source,dest with only source secret should work
	# since remote and source are on same machine
	eval $(test_exec_backupdocker 1 \
		"backup file" \
		--hist \
		--histdate "2020-09-01" \
		"$my_ip:$TESTSETDIR/backup/file-hist-1" \
		"$myhost:$TESTSETDIR/backup/file-hist-2" \
		--srcsecret /secrets/id_rsa \
		--runonsrc \
		$rsync_opt
		)

	# backup remote source,dest with only source secret should fail
	eval $(test_exec_backupdocker 1 \
		"backup file" \
		--hist \
		--histdate "2020-09-01" \
		"$my_ip:$TESTSETDIR/backup/file-hist-1" \
		"$myhost:$TESTSETDIR/backup/file-hist-2" \
		--srcsecret /secrets/id_rsa \
		--runonsrc \
		$rsync_opt
		)

	# backup remote source,dest with only dest secret should fail
	eval $(test_exec_backupdocker 1 \
		"backup file" \
		--hist \
		--histdate "2020-09-01" \
		"$my_ip:$TESTSETDIR/backup/file-hist-1" \
		"$myhost:$TESTSETDIR/backup/file-hist-2" \
		--dstsecret /secrets/id_rsa \
		--runonsrc \
		$rsync_opt
		)
	# backup remote source,dest without runon should fail
	eval $(test_exec_backupdocker 1 \
		"backup file" \
		--hist \
		--histdate "2020-09-01" \
		"$my_ip:$TESTSETDIR/backup/file-hist-1" \
		"$myhost:$TESTSETDIR/backup/file-hist-2" \
		--srcsecret /secrets/id_rsa \
		--dstsecret /secrets/id_rsa \
		$rsync_opt
		)

	rmdir "$TESTSETDIR/backup/file-hist-1" "$TESTSETDIR/backup/file-hist-2"
	test_assert "$?" "remove testdirs in $FUNCNAME" || return 1

	##### common tests for all variants source,dest in local,remote
	for dest in "/backup" ; do
		for source in "/backup" "$my_ip:$TESTSETDIR/backup" ; do
			secretparm=""
			[[ "$source" == *":"* ]] && 
				secretparm+="--srcsecret /secrets/id_rsa "

			test_file_hist_srcdest \
				"$source" \
				"$dest" \
				"$rsync_opt" \
				$secretparm \
			|| return 1
		done
	done

	for dest in "$my_ip:$TESTSETDIR/backup" ; do
		for source in "/backup" ; do
			# Backup to remote in history mod should fail
			eval $(test_exec_backupdocker 1 \
				"backup file" \
				--hist \
				--histdate "2020-10-01" \
				"$source" \
				"$dest" \
				"$rsync_opt" \
				--runonsrc \
				--dstsecret /secrets/id_rsa \
				)
		done
		for source in  "$my_ip:$TESTSETDIR/backup" ; do
			secretparm="--srcsecret /secrets/id_rsa "
			secretparm+="--dstsecret /secrets/id_rsa "

			# Backup to remote in history mod should fail if running on src
			# BUT since our src and dst are equal, we cannot test this situation

			# Backup to remote in history mod should work if running on dst
			test_file_hist_srcdest \
				"$source" \
				"$dest" \
				"$rsync_opt" \
				--runondst \
				$secretparm \
			|| return 1
		done
	done

	# Test --histkeep only with local/local
	test_file_hist_srcdest \
		"/backup" \
		"/backup" \
		"$rsync_opt" \
		$secretparm \
		--histkeep \
	|| return 1


	return 0
}

##### Main ###################################################################
# do nothing
