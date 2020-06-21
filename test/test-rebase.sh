#!/bin/bash
#
# Test Backup
#
# 

##### Create Test Situation ##################################################
function testdir_init () {
	mkdir $TESTSETDIR/rebase-base
	echo "Dummy1" >$TESTSETDIR/rebase-base/test-same
	echo "Dummy2" >$TESTSETDIR/rebase-base/test-updated
	echo "Dummy3" >$TESTSETDIR/rebase-base/test-deleted
	echo "Dummy4" >$TESTSETDIR/rebase-base/test-linked

	mkdir $TESTSETDIR/rebase-update
	echo "Dummy1" >$TESTSETDIR/rebase-update/test-same
	echo "Dummy2updated" >$TESTSETDIR/rebase-update/test-updated
	ln $TESTSETDIR/rebase-base/test-linked $TESTSETDIR/rebase-update/test-linked
	echo "Dummy5" >$TESTSETDIR/rebase-update/test-added
}

##### Test Rebase ############################################################
function test_rebase () {
	BASH_EXEC=". $BASEDIR/backup.d/rsync.sh ; debug=1 backup_rsync "
	test_exec_simple "test -e $BASEDIR/backup.d/rsync.sh"
	test_exec_simple bash <<<"$BASH_EXEC --rebase $TESTSETDIR/rebase-update $TESTSETDIR/rebase-base"

	inode_base=$(stat --format="%i" $TESTSETDIR/rebase-base/test-same)
	inode_upd=$(stat --format="%i" $TESTSETDIR/rebase-update/test-same)
	test_exec_simple "[ $inode_base == $inode_upd ]"

	inode_base=$(stat --format="%i" $TESTSETDIR/rebase-base/test-updated)
	inode_upd=$(stat --format="%i" $TESTSETDIR/rebase-update/test-updated)
	test_exec_simple "[ $inode_base != $inode_upd ]"
	text1="$(cat $TESTSETDIR/rebase-base/test-updated)"
	text2="$(cat $TESTSETDIR/rebase-update/test-updated)"
	test_exec_simple "[ $text1 == Dummy2 ]"
	test_exec_simple "[ $text2 == Dummy2updated ]"

	test_exec_simple "[ -e $TESTSETDIR/rebase-base/test-deleted ]"
	test_exec_simple "[ ! -e $TESTSETDIR/rebase-update/test-deleted ]"

	inode_base=$(stat --format="%i" $TESTSETDIR/rebase-base/test-linked)
	inode_upd=$(stat --format="%i" $TESTSETDIR/rebase-update/test-linked)
	test_exec_simple "[ $inode_base == $inode_upd ]"

	# test_exec_url "https://$BASEURL/archlinux/core/os/x86_64/core.db" 200
	return 0
}

#### MAIN ####################################################################

#load test framework
BASEDIR=$(dirname $BASH_SOURCE)
. $BASEDIR/../util/test-functions.sh || exit 1
testset_init "$@"

# Load config including $BASEDIR und $BASEURL
#. $(dirname $BASH_SOURCE)/install --config $TESTSETPARM || exit 1
#printf "\tBASEDIR=%s\n" "$BASEDIR"
#printf "\tDOM=%s\n" "$DOM"
#printf "\tMNAME=%s\n" "$MNAME"
#printf "\tMDEV=%s\n" "$MDEV"
#printf "\tIP_NET=%s\n" "$IP_NET"

testdir_init
test_rebase

testset_summary
exit $?
