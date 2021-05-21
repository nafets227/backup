#!/bin/bash
#
# Backup in Docker container
#
# (C) 2017-2020 Stefan Schallenberg
#
# Test script for File in history mode

##### test_file_srcdest ######################################################
function test_file_srcdest {
	local source="$1"
	local dest="$2"
	shift 2

	if [ -z "$source" ] || [ -z "$dest" ] ; then
		printf "Internal Error\n"
		return 1
	else
		printf "Testing FILE Backup from %s to %s\n" \
			"$source" "$dest"
	fi

	mkdir -p \
		"$TESTSETDIR/backup/file-hist/source" \
		"$TESTSETDIR/backup/file-hist/dest" \
	|| return 1
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
	test_expect_files "backup/file/dest/thisdirdoesnotexist/2020/06/10" 0 &&
	rmdir \
		"$TESTSETDIR/backup/file/dest/thisdirdoesnotexist/2020/06/10"
		"$TESTSETDIR/backup/file/dest/thisdirdoesnotexist/2020/06"
		"$TESTSETDIR/backup/file/dest/thisdirdoesnotexist/2020"
		"$TESTSETDIR/backup/file/dest/thisdirdoesnotexist"

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
	echo "Dummyfile" >$TESTSETDIR/backup/file/source/dummyfile || return 1
	eval $(test_exec_backupdocker 0 \
		"backup file" \
		--hist \
		--histdate "2020-10-12" \
		"$source" \
		"$dest" \
		"$@" \
		)

	# backup additional file in subdirectory
	mkdir $TESTSETDIR/backup/file/source/testsubdir || return 1
	echo "Dummyfile2" >$TESTSETDIR/backup/file/source/testsubdir/dummyfile2 || return 1
	eval $(test_exec_backupdocker 0 \
		"backup file" \
		--hist \
		--histdate "2020-10-13" \
		"$source" \
		"$dest" \
		"$@" \
		)

	# delete no longer existing file
	rm $TESTSETDIR/backup/file/source/dummyfile || return 1
	eval $(test_exec_backupdocker 0 \
		"backup file" \
		--hist \
		--histdate "2020-10-14" \
		"$source" \
		"$dest" \
		"$@" \
		)

	# delete no longer existing file in subdir
	rm $TESTSETDIR/backup/file/source/testsubdir/dummyfile2 || return 1
	eval $(test_exec_backupdocker 0 \
		"backup file" \
		--hist \
		--histdate "2020-10-15" \
		"$source" \
		"$dest" \
		"$@" \
		)

	# delete no longer existing subdir
	rmdir $TESTSETDIR/backup/file/source/testsubdir || return 1
	eval $(test_exec_backupdocker 0 \
		"backup file" \
		--hist \
		--histdate "2020-10-16" \
		"$source" \
		"$dest" \
		"$@" \
		)

	test_expect_files "backup/file/dest/2020/06/11" 0
	test_expect_files "backup/file/dest/2020/06/12" 1
	test_expect_files "backup/file/dest/2020/06/13" 2 && # includes subdir!
	test_expect_files "backup/file/dest/2020/06/13/testsubdir" 1
	test_expect_files "backup/file/dest/2020/06/14" 1 && # includes subdir!
	test_expect_files "backup/file/dest/2020/06/14/testsubdir" 1
	test_expect_files "backup/file/dest/2020/06/15" 1 && # includes subdir!
	test_expect_files "backup/file/dest/2020/06/15/testsubdir" 0
	test_expect_files "backup/file/dest/2020/06/16" 0

	rm -rf \
		"$TESTSETDIR/backup/file-hist/source" \
		"$TESTSETDIR/backup/file-hist/dest" \
	|| return 1

	return 0
}

##### Tests for File backup (rsync) ##########################################
function test_file_hist {
    ##### Specific tests for local/remote
	mkdir -p \
		"$TESTSETDIR/backup/file-hist-1" \
		"$TESTSETDIR/backup/file-hist-2" \
	|| return 1

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

	rmdir "$TESTSETDIR/backup/file1" "$TESTSETDIR/backup/file2" || return 1

	##### common tests for all variants source,dest in local,remote
	for source in "/backup" "$my_ip:$TESTSETDIR/backup" ; do
		for dest in "/backup" "$my_ip:$TESTSETDIR/backup" ; do
#	for source in "$my_ip:$TESTSETDIR/backup" ; do
#	for source in "/backup"  ; do
#		for dest in "/backup" ; do
			secretparm=""
			[[ "$source" == *":"* ]] && 
				secretparm+="--srcsecret /secrets/id_rsa "
			[[ "$dest" == *":"* ]] && 
				secretparm+="--dstsecret /secrets/id_rsa "

			if [[ "$source" == *":"* ]] && [[ "$dest" == *":"* ]] ; then
				test_file_srcdest \
					"$source" \
					"$dest" \
					"$rsync_opt" \
					--runonsrc \
					$secretparm \
				|| return 1

				secretparm+="--runondst "
			fi

			test_file_srcdest \
				"$source" \
				"$dest" \
				"$rsync_opt" \
				$secretparm \
			|| return 1
		done
	done

	return 0
}

##### Main ###################################################################
# do nothing
