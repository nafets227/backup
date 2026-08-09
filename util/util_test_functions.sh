#!/usr/bin/env bash
#
# Allgemeine Test Bibliothek
#
# (C) 2017 Stefan Schallenberg

function test_cleanImap {
	local mail_adr="$1"
	local mail_pw="$2"
	local mail_srv="$3"

	local imapstatus

	util_err_verify_or_exit

	printf "Cleaning %s at %s. Deleting all Mails.\n" \
		"$mail_adr" "$mail_srv"

	# intentionally not using util_curl here
	imapstatus=$(
		curl --ssl-reqd --silent --show-error \
		"imap://$mail_srv" \
		--user "$mail_adr:$mail_pw" \
		--request 'STATUS INBOX (MESSAGES)'
	)
	imapstatus=${imapstatus%%$'\r'} # delete CR LF

	#DEBUG printf "DEBUG: Status=%s\n" "$imapstatus"
	if [ "${imapstatus:0:25}" != "* STATUS INBOX (MESSAGES " ] ; then
		printf "Wrong Status received from IMAP: \"%s\"\n" \
			"$imapstatus"
		return 1
	elif [ "$imapstatus" == "* STATUS INBOX (MESSAGES 0)" ] ; then
		# 0 Messages -> no deleting needed
		return 0
	fi

	# intentionally not using util_curl here
	curl --ssl-reqd --silent --show-error \
		"imap://$mail_srv/INBOX" \
		--user "$mail_adr:$mail_pw" \
		--request 'STORE 1:* +FLAGS \Deleted'

	curl --ssl-reqd --silent --show-error \
		"imap://$mail_srv/INBOX" \
		--user "$mail_adr:$mail_pw" \
		--request 'EXPUNGE'

	return 0
}

function test_putImap {
	local mail_adr="$1"
	local mail_pw="$2"
	local mail_srv="$3"

	util_err_verify_or_exit

	printf "Storing a Mail into %s at %s.\n" \
		"$mail_adr" "$mail_srv"

	cat >"$TESTSET_DIR/testmsg" <<-EOF
		Return-Path: <$mail_adr>
		From: Test-From <$mail_adr>
		Content-Type: text/plain; charset=us-ascii
		Content-Transfer-Encoding: 7bit
		Mime-Version: 1.0 (Mac OS X Mail 10.2 \(3259\))
		Subject: Test from test_putImap
		Date: Thu, 4 Mar 2017 11:50:19 +0100
		To: Test-To <$mail_adr>

		Test
		EOF

	# intentionally not using util_curl here
	curl --ssl-reqd --silent --show-error \
		"imap://$mail_srv/INBOX" \
		--user "$mail_adr:$mail_pw" \
		-T "$TESTSET_DIR/testmsg"

	curl --ssl-reqd --silent --show-error \
		"imap://$mail_srv/INBOX" \
		--user "$mail_adr:$mail_pw" \
		--request 'STORE 1 -Flags /Seen'

	return 0
}

function test_internal_exec_init {
	local testdesc="${1-}"
	local calldepth="${TEST_CALLDEPTH:-0}"

	TESTSET_LAST_CHECK_NR=$(( ${TESTSET_LAST_CHECK_NR-0} + 1))
	TESTSET_LAST_TEST_NR=$TESTSET_LAST_CHECK_NR


	printf "Executing Test %d (%s:%s %s) ... " "$TESTSET_LAST_CHECK_NR" \
		"${BASH_SOURCE[$((calldepth+2))]}" \
		"${BASH_LINENO[$((calldepth+1))]}" \
		"${FUNCNAME[$((calldepth+2))]}"

	if [ -n "$testdesc" ] ; then
		printf "\t%s\n" "$testdesc"
	fi

	return 0
}

function test_expect_lastoutput_contains {
	TESTSET_LAST_CHECK_NR=$(( ${TESTSET_LAST_CHECK_NR-0} + 1))
	# not increasing TESTSET_LAST_TEST_NR
	local search="$1"
	local extension="${2:-.out}"
	local grepopts="${3-}"
	local altsearch="${4-}"

	local grep_cnt

	util_err_verify_or_exit

	#shellcheck disable=SC2086 # grepopts contains multiple params
	grep_cnt=$(
		grep -c $grepopts "$search" \
		<"$TESTSET_DIR/$TESTSET_LAST_TEST_NR$extension" \
		|| [ "$?" == 1 ] # ignore RC=1 for not found
		)
	if [ "$grep_cnt" == "0" ] ; then
		# expected text not in output.
		printf "CHECK %s FAILED. '%s' not found in output of test %s\n" \
			"$TESTSET_LAST_CHECK_NR" "$search" "$TESTSET_LAST_TEST_NR"
		if [ -n "$altsearch" ] ; then
			printf "========== Selected Output Test %d Begin ==========\n" \
				"$TESTSET_LAST_TEST_NR"
			grep "$altsearch" "$TESTSET_DIR/$TESTSET_LAST_TEST_NR$extension" \
				|| true
			printf "========== Selected Output Test %d End ==========\n" \
				"$TESTSET_LAST_TEST_NR"
		fi
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
	else
		# expected text in output -> OK
		TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
	fi

	return 0
}

function test_expect_lastoutput {
	TESTSET_LAST_CHECK_NR=$(( ${TESTSET_LAST_CHECK_NR-0} + 1))
	# not increasing TESTSET_LAST_TEST_NR
	local exp="$1"
	local extension="${2:-.out}"
	local rc

	util_err_verify_or_exit

	cmp --quiet \
		<(printf "%s" "$exp") \
		<(tail --lines=+4 "$TESTSET_DIR/$TESTSET_LAST_TEST_NR$extension") \
	&& rc=0 || rc=$?
	if [ "$rc" -gt 1 ] ; then
		# cmp error
		printf "ERROR checking lastoutput %s.\n" "$TESTSET_LAST_CHECK_NR"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
		return 1
	elif [ "$rc" -gt 0 ] ; then
		# values not equal
		printf "CHECK %s FAILED. Value of test %s is not as expected\n" \
			"$TESTSET_LAST_CHECK_NR" "$TESTSET_LAST_TEST_NR"
		printf "========== Expected output Test %s Begin ==========\n" \
			"$TESTSET_LAST_TEST_NR"
		printf "%s" "$exp"
		printf "========== Expected output Test %s End ==========\n" \
			"$TESTSET_LAST_TEST_NR"
		printf "========== Output Test %d Begin ==========\n" \
			"$TESTSET_LAST_TEST_NR"
		cat "$TESTSET_DIR/$TESTSET_LAST_TEST_NR$extension"
		printf "========== Output Test %d End ==========\n" \
			"$TESTSET_LAST_TEST_NR"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
	else
		# line count as expected -> OK
		TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
	fi

	return 0
}

function test_expect_lastoutput_linecount {
	util_err_verify_or_exit

	TESTSET_LAST_CHECK_NR=$(( ${TESTSET_LAST_CHECK_NR-0} + 1))
	# not increasing TESTSET_LAST_TEST_NR
	local linecountexp="$1"
	local extension="${2:-.out}"

	local linecountact
	linecountact=$(wc -l <"$TESTSET_DIR/$TESTSET_LAST_TEST_NR$extension")
	# Ignore Log Lines inserted at the beginning
	linecountact=$(( linecountact - 3 ))

	if [ "$linecountact" == "$linecountexp" ] ; then
		# line count as expected -> OK
		TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
	else
		# linecount not as expected
		printf "CHECK %s FAILED. Linecountof test %s is %d (exp=%d)\n" \
			"$TESTSET_LAST_CHECK_NR" "$TESTSET_LAST_TEST_NR" \
			"$linecountact" "$linecountexp"
		printf "========== Output Test %d Begin ==========\n" \
			"$TESTSET_LAST_TEST_NR"
		cat "$TESTSET_DIR/$TESTSET_LAST_TEST_NR$extension"
		printf "========== Output Test %d End ==========\n" \
			"$TESTSET_LAST_TEST_NR"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
	fi

	return 0
}

function test_get_lastoutput {
	local extension="${2:-.out}"

	util_err_verify_or_exit

	tail --lines=+4 "$TESTSET_DIR/$TESTSET_LAST_TEST_NR$extension"

	return 0
}

function test_exec_cmd {
	# Parameters:
	#     1 - expected RC [default: 0]
	#     2 - optional message to be printed if test fails
	#     3+ - command to be executed
	local rc_exp=${1:-0}
	local testmsg=${2-}
	shift 2

	util_err_verify_or_exit
	test_internal_exec_init

	local testrc

	printf "#-----\n#----- Command: %s\n#-----\n" "$*" \
		>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
	util_err_callfunc "$@" >>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out" 2>&1
	testrc=$UTIL_ERR_RC

	if [ "$testrc" -ne "$rc_exp" ] ; then
		printf "FAILED. RC=%d (exp=%d)\n" "$testrc" "$rc_exp"
		if [ -n "$testmsg" ] ; then
			printf "Info: %s\n" "$testmsg"
		fi
		printf "========== Output Test %d Begin ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		cat "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
		printf "========== Output Test %d End ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
	else
		printf "OK\n"
		TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
		if [ "$TESTSET_LOG_ALWAYS" == "1" ] ; then
			printf "========== Output Test %d Begin ==========\n" \
				"$TESTSET_LAST_CHECK_NR"
			cat "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
			printf "========== Output Test %d End ==========\n" \
				"$TESTSET_LAST_CHECK_NR"
		fi
	fi

	return 0
}

function test_exec_inlinecmd {
	# WARNING: This function is not isolating the command in a subshell.
	# USE WITH CARE!
	# Parameters:
	#     1 - expected RC [default: 0]
	#     2 - optional message to be printed if test fails
	#     3+ - command to be executed
	local rc_exp=${1:-0}
	local testmsg=${2-}
	shift 2

	util_err_verify_or_exit
	test_internal_exec_init

	local testrc

	printf "#-----\n#----- Command: %s\n#-----\n" "$*" \
		>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
	"$@" >>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out" 2>&1 \
		&& testrc=0 || testrc=$?

	if [ "$testrc" -ne "$rc_exp" ] ; then
		printf "FAILED. RC=%d (exp=%d)\n" "$testrc" "$rc_exp"
		if [ -n "$testmsg" ] ; then
			printf "Info: %s\n" "$testmsg"
		fi
		printf "========== Output Test %d Begin ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		cat "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
		printf "========== Output Test %d End ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
	else
		printf "OK\n"
		TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
		if [ "$TESTSET_LOG_ALWAYS" == "1" ] ; then
			printf "========== Output Test %d Begin ==========\n" \
				"$TESTSET_LAST_CHECK_NR"
			cat "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
			printf "========== Output Test %d End ==========\n" \
				"$TESTSET_LAST_CHECK_NR"
		fi
	fi

	return 0
}

function test_exec_ssh {
	# Parameters:
	#     1 - machine name to ssh to
	#     2 - expected RC [default: 0]
	#     [optional] --stdin forward stdin to ssh.
	#         by default it is set if no param is given, unset otherwise
	#     3ff - command to test
	local sshopt testrc
	local sshtarget="$1"
	shift
	local rc_exp=${1:-0}
	shift || true
	if [ "${1-}" == "--stdin" ] ; then
		shift
		sshopt=""
	elif [ "$#" == 0 ] ; then
		sshopt=""
	else
		sshopt="-n"
	fi

	util_err_verify_or_exit
	test_internal_exec_init

	printf "#-----\n#----- SSH Machine: %s, Command: %s\n#-----\n" \
		"$sshtarget" "$*" \
		>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"

	# We do NOT set -euo pipefail [-x] here because we dont know
	# if commands executed remotely come as params or are injected
	# via stdin. On top, we dont know if it may change the output
	# (especially debug setting -x) that make subsequent checks fail.

	#shellcheck disable=SC2029
	ssh $sshopt "$sshtarget" "$*" \
		>>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out" 2>&1 \
	&& testrc=0 || testrc=$?

	if [ "$testrc" -ne "$rc_exp" ] ; then
		printf "FAILED. RC=%d (exp=%d)\n" "$testrc" "$rc_exp"
		printf "SSH %s CMD: %s\n" "$sshtarget" "$*"
		printf "========== Output Test %d Begin ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		cat "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
		printf "========== Output Test %d End ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
	else
		printf "OK\n"
		TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
		if [ "$TESTSET_LOG_ALWAYS" == "1" ] ; then
			printf "SSH %s CMD: %s\n" "$sshtarget" "$*"
			printf "========== Output Test %d Begin ==========\n" \
				"$TESTSET_LAST_CHECK_NR"
			cat "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
			printf "========== Output Test %d End ==========\n" \
				"$TESTSET_LAST_CHECK_NR"
		fi
	fi

	return 0
}

function test_internal_execwait_url_once {
	#     1     expected httpcode
	#     2     url
	#     3ff   further parameters to curl
	#     TEST_EXECWAIT_IPS (global variable)
	#           IPs to connect to (name of array variable) [optional]
	#           the requests are done with the original url but network
	#           connects to these addresses (curl --connect-to)
	util_err_enable
	local httpcode_exp="$1"
	local url="$2"
	shift 2

	for ip in "${TEST_EXECWAIT_IPS[@]}" ; do
		if [[ "$ip" == *:* ]] ; then
			ip="[$ip]" # curl needs IPv6 addresses enclosed in brackets
		fi
		printf "#-----\n#----- command: %s\n#-----\n" \
			"curl \"$url\" $* --connect-to ::$ip" \
			> "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
		util_curl "$url" "$@" "--connect-to" "::$ip" \
			> "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.curlout"
		printf "%s\n" "$UTIL_CURL_ERRMSG" \
			> "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.curlerr"
		printf "%s/%s\n" "$UTIL_CURL_RC" "$UTIL_CURL_HTTPCODE" \
			> "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.curlresult"

		if [ "$httpcode_exp" = "$UTIL_CURL_HTTPCODE" ] ; then
			printf "\tSuccess %s with IP %s\n" \
				"$url" "$ip"
		elif \
			[ "$httpcode_exp" = "xxx" ] &&
			[ -n "$UTIL_CURL_HTTPCODE" ] &&
			[ "$UTIL_CURL_HTTPCODE" != "000" ]
		then
			printf "\tSuccess (%s) %s with IP %s\n" \
				"$UTIL_CURL_HTTPCODE" "$url" "$ip"
		else
			printf "\tFailed (%s/%s, exp=*/%s) %s with IP %s\n" \
				"$UTIL_CURL_RC" "$UTIL_CURL_HTTPCODE" \
				"$httpcode_exp" \
				"$url" "$ip"
			return 1
		fi
	done

	return 0
}

function test_execwait_url {
	# Parameters:
	#     1 - expected httpcode (xxx for any httpcode but no connection error)
	#     2 - timeout in seconds
	#     3 - url
	#     4 - IPs to connect to (name of array variable) [optional]
	#           the requests are done with the original url but network
	#           connects to these addresses (curl --connect-to)
	#     5ff - further parameters to curl
	local httpcode_exp="$1"
	local timeout="$2"
	local url="$3"
	local ipvarname="${4-}"
	shift 3 ; shift || true

	local dnsname TEST_EXECWAIT_IPS=()
	declare -n ipvar="$ipvarname" # name reference

	util_err_verify_or_exit
	test_internal_exec_init ; printf "\n"

	dnsname=${url#*://}
	dnsname=${dnsname%%/*}
	dnsname=${dnsname%%:*}

	TEST_EXECWAIT_IPS+=( "$dnsname" "${ipvar[@]}" )

	util_err_callfunc util_retry "$timeout" 5 \
		test_internal_execwait_url_once \
			"$httpcode_exp" "$url" "$@" \
			--connect-timeout 3 --max-time 5 --verbose

	if [ "$UTIL_ERR_RC" != 0 ] ; then
		printf "FAILED. RC=%s (exp=*/%s)\n" \
			"$(cat "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.curlresult" || true)" \
			"$httpcode_exp"
		printf "========== Output Test %d Begin ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		cat \
			"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out" \
			"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.curlout" || true
		printf "\n"
		printf "========== Output Test %d End ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		printf "========== stderr-Output Test %d Begin ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		cat "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.curlerr" || true
		printf "\n"
		printf "========== stderr-Output Test %d End ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
	else
		printf "OK\n"
		TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
		if [ "$TESTSET_LOG_ALWAYS" == "1" ] ; then
			printf "========== Output Test %d Begin ==========\n" \
				"$TESTSET_LAST_CHECK_NR"
			cat "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.curlout" || true
			printf "\n"
			printf "========== Output Test %d End ==========\n" \
				"$TESTSET_LAST_CHECK_NR"
		fi
	fi

	return 0
}

function test_internal_exec_kube {
	local -r kubecmd="$1"
	local -r kubecomment="${2-}"
	local -r kubenolog="${3-}"
	local cmd rc

	cmd="kubectl"
	cmd+=" --kubeconfig $KUBE_CONFIGFILE"
	cmd+=" --namespace $KUBE_NAMESPACE"

	if [ -n "$kubecomment" ] ; then
		printf "#----- %s\n" \
			"$kubecomment" \
			>>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
	fi

	if [ -z "$kubenolog" ] ; then
		printf "#----- Command: %s\n" \
			"$cmd $kubecmd" \
			>>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
	fi

	#shellcheck disable=SC2086 # cmd and kubecmd contains more than one param
	TEST_INTERNAL_EXEC_KUBE_OUTPUT=$(set +x ; eval $cmd $kubecmd 2>&1) \
	&& rc=0 || rc=$?
	if [ -z "$kubenolog" ] || [ "$rc" != 0 ] ; then
		printf "%s\n" \
			"$TEST_INTERNAL_EXEC_KUBE_OUTPUT" \
			>>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
	fi

	return $rc
}

function test_internal_check_kubecron {
	local jobname="$1"
	local jobStatus jobActive jobFailed jobSucceeded jobCondition
	# testrc used from global scope, i.e. the calling function test_exec_kubecron

	test_internal_exec_kube \
		"get job $jobname -o json | jq '.status'" "" "1"
	jobStatus="$TEST_INTERNAL_EXEC_KUBE_OUTPUT"
	jobActive=$(jq '.active // 0' <<<"$jobStatus" 2>&1)
	jobFailed=$(jq '.failed // 0' <<<"$jobStatus" 2>&1)
	jobSucceeded=$(jq '.succeeded // 0' <<<"$jobStatus" 2>&1)

	# editorconfig-checker-disable
	if ! jobCondition=$(jq -r \
		'try .conditions[] | select( (.status=="True" ) and ( .type | IN("Complete","Failed") ) ).type' \
		<<<"$jobStatus" 2>&1
		)
	# editorconfig-checker-enable
	then
		printf "%s\nACTIVE=%s\nFAILED=%s\nSUCCEEDED=%s\nCONDSTATUS=%s\n" \
			"$jobStatus" "$jobActive" "$jobFailed" "$jobSucceeded" \
			"$jobCondition"
		testrc=3
		return 255 # stop loop in util_retry
	elif [ "$jobCondition" == "Complete" ] ; then
		printf "  Completed Job: %s/%s/%s/%s (%s)\n" \
			"$jobActive" "$jobFailed" "$jobSucceeded" "$jobCondition" \
			"active/failed/succeeded/condition"
		testrc=0
		return 0
	elif [ "$jobCondition" == "Failed" ] ; then
		printf "     Failed Job: %s/%s/%s/%s (%s)\n" \
			"$jobActive" "$jobFailed" "$jobSucceeded" "$jobCondition" \
			"active/failed/succeeded/condition"
		testrc=1
		return 255 # stop look in util_retry
	else
		printf "\t\tWaiting for Job: %s/%s/%s/%s (%s)\n" \
			"$jobActive" "$jobFailed" "$jobSucceeded" "$jobCondition" \
			"active/failed/succeeded/condition"
		return 1
	fi
}

function test_exec_kubecron {
	# Parameters:
	#     1 - name of the cronjob
	#     2 - expected RC [default: 0], possible values:
	#         0 - OK
	#         1 - Job did run, but with error
	#         2 - Job timed out
	#         3 - Job could not be run
	#             (Kubernetes error when creating and scheduling)
	#     3 - optional message to be printed if test fails
	#     4 - Timeout in seconds [optional, default=240]
	local -r cronjobname="$1"
	local -r rc_exp="${2-0}"
	local -r infomsg="${3-}"
	local -r sleepMax="${4:-240}"

	util_err_verify_or_exit
	test_is_cmdavail "jq" || return 1 # abort test
	test_internal_exec_init
	util_kube_internal_verify_initialised

	local testrc=""

	util_err_callfunc util_err_notrap test_internal_exec_kube \
		"delete job/$cronjobname-test" \
		"try deleting previous jobs"

	util_err_callfunc test_internal_exec_kube \
		"create job $cronjobname-test --from=cronjob/$cronjobname"
	if [ "$UTIL_ERR_RC" == 0 ] ; then
		printf "\n"
		# do NOT use | tee here, as it would move util_err_callfunc into a
		# subshellKeep and UTIL_ERR_RC would be hidden.
		util_err_callfunc util_retry "$sleepMax" 5 \
			util_err_notrap test_internal_check_kubecron "$cronjobname-test" \
			> >(tee "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.kubecronwait") 2>&1
		[ "$UTIL_ERR_RC" == 0 ] || testrc=${testrc:-2}
	else
		testrc=3
	fi

	# Always try to print logs of Pods, even in case of errors
	util_err_callfunc test_internal_exec_kube \
		"logs job/$cronjobname-test --all-containers"
	[ "$UTIL_ERR_RC" == 0 ]	|| testrc=${testrc:-2}

	testrc="${testrc:-0}"

	if [ "$testrc" -ne "$rc_exp" ] ; then
		printf "Test %s FAILED. RC=%d (exp=%d)\n" \
			"$TESTSET_LAST_CHECK_NR" "$testrc" "$rc_exp"
		if [ -n "$infomsg" ] ; then
			printf "Info: %s\n" "$infomsg"
		fi
		printf "========== Output Test %d Begin ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		cat "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
		printf "========== Output Test %d End ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
	else
		util_err_callfunc \
			test_internal_exec_kube "delete job/$cronjobname-test"
		# ignore if deleting job fails.

		printf "Test %s OK\n" "$TESTSET_LAST_CHECK_NR"
		TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
		if [ "$TESTSET_LOG_ALWAYS" == "1" ] ; then
			printf "========== Output Test %d Begin ==========\n" \
				"$TESTSET_LAST_CHECK_NR"
			cat "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
			printf "========== Output Test %d End ==========\n" \
				"$TESTSET_LAST_CHECK_NR"
		fi
	fi

	return 0
}

function test_exec_kubenode {
	# Parameters:
	#     1 - name of the node
	#     2 - DNS name of the VM to run kubectl
	#     3 - timeout in sec
	#     4+ - IP addresses or DNS names to verify connection with

	local -r nodename="${1,,}" # lowercase
	local -r dnsname="$2"
	local -r timeout="$3"
	shift 3

	local testrc

	util_err_verify_or_exit
	test_internal_exec_init

	if [ -z "$nodename" ] ; then
		printf "Error: nodename empty\n"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
		return 1
	elif [ -z "$dnsname" ] ; then
		printf "Error: dnsname empty\n"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
		return 1
	elif [ -z "$timeout" ] ; then
		printf "Error: timeout empty\n"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
		return 1
	elif [ -z "$*" ] ; then
		printf "Error: Param IP Address missing\n"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
		return 1
	fi

	#----- Wait for node to become reade
	#shellcheck disable=SC2087 # intentionally expand on client side
	cat <<-EOF >"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.kubenode"
		----- CMD Begin ------
		kubectl wait node $nodename --for=condition=ready --timeout=${timeout}s
		----- CMD End ------
		EOF
	ssh -n "$dnsname" kubectl wait node "$nodename" \
		--for=condition=ready --timeout="${timeout}s" \
		>>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.kubenode" 2>&1 &&
	testrc=0 || testrc=$?

	if [ "$testrc" -ne 0 ] ; then
		printf "FAILED. Node %s did not become readyin %s\n" \
			"$nodename" "$timeout"
		printf "========== Output Test %d Begin ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		cat "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.kubenode"
		printf "========== Output Test %d End ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"

		# stop test here, as node is not ready
		# and subsequent checks will fail
		return 0
	fi

	#----- Test connectivity of a pod on the node
	local ips=() dnsip=()
	for f in "$@" ; do
		util_getIP "$f" "" dnsip
		ips+=( "${dnsip[@]}" )
	done

	cat >"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.in" <<-EOF
		set -x
		i=\$(date '+%s')
		while [ \$(( \$(date '+%s') - i )) -lt $timeout ]
		do
			$(
				for f in "${ips[@]}" ; do
					if [[ "$f" =~ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]] ; then
						# is an IPv4 address
						printf "\tping -c 1 -4 %s &&\n" "$f"
					else
						printf "\tping -c 1 -6 %s &&\n" "$f"
					fi
				done
			)
			exit 0
			sleep 1
		done
		exit 1
		EOF

	local kubecmd
	kubecmd=""
	kubecmd+="run kubenodetest-$nodename"
	kubecmd+=" --image alpine:latest"
	kubecmd+=" --image-pull-policy=IfNotPresent"
	kubecmd+=" --restart=Never"
	kubecmd+=" --overrides='{"
	kubecmd+="   \"apiVersion\": \"v1\","
	kubecmd+="   \"spec\": { \"nodeName\": \"$nodename\" } }'"
	kubecmd+=" --stdin"
	kubecmd+=" --pod-running-timeout=7m"
	kubecmd+=" --rm"

	#shellcheck disable=SC2087 # intentionally expand on client side
	cat \
		<(echo "----- CMD Begin ------") \
		"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.in" \
		<(echo "----- CMD End ------") \
		>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
	# do NOT use ssh -n here !
	#shellcheck disable=SC2029 # intentionally expand on client side
	ssh "$dnsname" kubectl "$kubecmd" \
		<"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.in" \
		>>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out" 2>&1 &&
	testrc=0 || testrc=$?

	if [ "$testrc" -ne 0 ] ; then
		printf "FAILED. RC=%d (exp=0)\n" "$testrc"
		printf "========== Output Test %d Begin ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		cat "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
		printf "========== Output Test %d End ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
	else
		printf "OK\n"
		#shellcheck disable=SC2029 # intentionally expand on client side
		TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
		if [ "$TESTSET_LOG_ALWAYS" == "1" ] ; then
			printf "========== Output Test %d Begin ==========\n" \
				"$TESTSET_LAST_CHECK_NR"
			cat "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
			printf "========== Output Test %d End ==========\n" \
				"$TESTSET_LAST_CHECK_NR"
		fi
	fi

	return 0
}

function test_exec_helm {
	# test helm chart installed
	# Parameters:
	#   1 - release =local instance name of helm chart (unique in Kube namespace)
	local release="$1"
	local pods pod testrc

	if [ "$KUBE_ACTION" != "install" ] ; then
		printf "Error: testhelm only allowed in install phase\n"
		return 1
	fi

	util_err_verify_or_exit
	util_kube_internal_verify_initialised
	test_internal_exec_init

	# wait for chart install to complete
	# currently disabled as first example, jenkins,
	# does this inside the chart tests
	# helm status \
	#	--kubeconfig $KUBE_CONFIGFILE \
	#	--namespace $KUBE_NAMESPACE \
	#	$release -o json | \
	# jq  -r '.info.status'
	# should return "deployed".

	printf "#-----\n#----- Helm Chart: %s, Namespace: %s\n#-----\n" \
		"$release" "$KUBE_NAMESPACE" \
		>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
	if ! helm test \
		--kubeconfig "$KUBE_CONFIGFILE" \
		--namespace "$KUBE_NAMESPACE" \
		"$release" \
		>>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out" 2>&1
	then
		# helm test --logs currently (2022-04) does not work
		# maybe https://github.com/helm/helm/pull/10603 will solve it.
		# So we workaround identifying the pods ourselves.
		# editorconfig-checker-disable
		pods=$( kubectl get pods \
			--kubeconfig "$KUBE_CONFIGFILE" \
			--namespace "$KUBE_NAMESPACE" \
			--output jsonpath='{.items[?(@.metadata.annotations.helm\.sh/hook=="test-success")].metadata.name}'
		)
		#editorconfig-checker-enable
		{
			for pod in $pods ; do
				printf -- "----- Logs of Pod %s -----\n" "$pod"
				kubectl logs \
					--kubeconfig "$KUBE_CONFIGFILE" \
					--namespace "$KUBE_NAMESPACE" \
					--all-containers \
					"$pod"
				printf -- "----- End of Logs of Pod %s -----\n" "$pod"
				done
		} >"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.podout"

		printf "FAILED.\n"
		printf "========== Output Test %d Begin ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		cat "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
		printf "========== Output Test %d End ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		printf "========== Pod-Output Test %d Begin ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		cat "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.podout"
		printf "========== Pod-Output Test %d End ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
	else
		printf "OK\n"
		TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
		if [ "$TESTSET_LOG_ALWAYS" == "1" ] ; then
			printf "========== Output Test %d Begin ==========\n" \
				"$TESTSET_LAST_CHECK_NR"
			cat "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
			printf "========== Output Test %d End ==========\n" \
				"$TESTSET_LAST_CHECK_NR"
		fi
	fi

	return 0
}

function test_exec_recvmail {
	local url="$1"
	local rc_exp="${2:-0}"
	shift && shift || true # dont fail if only one param given.

	util_err_verify_or_exit
	[ -z "$TEST_SNAIL" ] && return 1
	test_internal_exec_init "recvmail $rc_exp $url"

	local testrc
	local MAIL_STD_OPT
	MAIL_STD_OPT="-e -n -vv -Sv15-compat -Snosave"
	MAIL_STD_OPT+=" -Sexpandaddr=fail,-all,+addr"
	readonly MAIL_STD_OPT
	local MAIL_OPT="-S 'inbox=$url'"

	#shellcheck disable=SC2086 # vars contain multiple params
	LC_ALL=C MAILRC=/dev/null \
		eval $TEST_SNAIL $MAIL_STD_OPT $MAIL_OPT "$*" \
		>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.mailout" \
		2>&1 \
		</dev/null \
	&& testrc=0 || testrc=1
	if [ "$testrc" -ne "$rc_exp" ] ; then
		printf "FAILED. RC=%d (exp=%d)\n" "$testrc" "$rc_exp"
		printf "test_exec_recvmail(%s,%s,%s)\n" "$url" "$rc_exp" "$@"
		printf "CMD: $TEST_SNAIL %s %s %s\n" "$MAIL_STD_OPT" "$MAIL_OPT" "$*"
		printf "========== Output Test %d Begin ==========\n" "$TESTSET_LAST_CHECK_NR"
		cat "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.mailout"
		printf "========== Output Test %d End ==========\n" "$TESTSET_LAST_CHECK_NR"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
	else
		printf "OK\n"
		TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
	fi

	return 0
}

function test_exec_issuccess {
	if [ "${TESTSET_TESTFAILED##* }" == "$TESTSET_LAST_CHECK_NR" ] ; then
		return 1
	else
		return 0
	fi
}

function test_is_cmdavail {
	printf "Checking for Tools (%s) ... " "$*"

	for f in "$@" ; do
		if ! errmsg=$(which "$f" 2>&1) ; then
			printf "FAILED: Missing %s\n\t%s\n" \
				"$f" "$errmsg"
			return 1
		fi
	done

	printf "OK\n"

	return 0
}

function test_expect_vardefined {
	util_err_verify_or_exit

	TESTSET_LAST_CHECK_NR=$(( ${TESTSET_LAST_CHECK_NR-0} + 1))

	for f in "$@" ; do
		if eval "[ -z \"\${$f-}\" ]" ; then
			printf "\tCHECK %s FAILED. Missing var %s\n" \
				"$TESTSET_LAST_CHECK_NR" "$f"
			TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
			return 0
		fi
	done

	printf "\tCHECK %s OK.\n" "$TESTSET_LAST_CHECK_NR"
	TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))

	return 0
}

function test_expect_files {
	util_err_verify_or_exit

	TESTSET_LAST_CHECK_NR=$(( ${TESTSET_LAST_CHECK_NR-0} + 1))

	for f in "$@" ; do
		if [ ! -f "$f" ] ; then
			printf "\tCHECK %s FAILED. Missing file %s\n" \
				"$TESTSET_LAST_CHECK_NR" "$f"
			TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
			return 0
		fi
	done

	printf "\tCHECK %s OK.\n" "$TESTSET_LAST_CHECK_NR"
	TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
	return 0
}

function test_expect_value {
	util_err_verify_or_exit

	TESTSET_LAST_CHECK_NR=$(( ${TESTSET_LAST_CHECK_NR-0} + 1))
	# not increasing TESTSET_LAST_TEST_NR

	# param 1: file
	local testvalue="$1"
	local testvalexpected="$2"
	local testerrmsg="${3:-""}"

	if [ "$testvalue" == "$testvalexpected" ] ; then
		printf "\tCHECK %s OK.\n" "$TESTSET_LAST_CHECK_NR"
		TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
	else
		printf "\tCHECK %s FAILED. Value='%s' (exp='%s')%s\n" \
			"$TESTSET_LAST_CHECK_NR" "$testvalue" "$testvalexpected" "$testerrmsg"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
	fi

	return 0
}

function test_expect_file_missing {
	util_err_verify_or_exit

	TESTSET_LAST_CHECK_NR=$(( ${TESTSET_LAST_CHECK_NR-0} + 1))
	# not increasing TESTSET_LAST_TEST_NR

	# param 1: file
	local testfile="$1"
	local rc

	if [ "${testfile:0:1}" != "/" ] ; then
		testfile="$TESTSET_DIR/$testfile"
	fi

	testresult=$(ls -1A "$testfile" 2>/dev/null ) && rc=0 || rc=$?

	if [ "$rc" == "1" ] || [ "$rc" == "2" ]; then
		printf "\tCHECK %s OK.\n" "$TESTSET_LAST_CHECK_NR"
		TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
	elif [ "$rc" == "0" ] ; then
		printf "\tCHECK %s FAILED. File '%s' exists\n" \
			"$TESTSET_LAST_CHECK_NR" "$1"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
	else
		printf "\tCHECK %s FAILED. Cannot get files in '%s'\n" \
			"$TESTSET_LAST_CHECK_NR" "$1"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
	fi

	return 0
}

function test_expect_filecount {
	util_err_verify_or_exit

	TESTSET_LAST_CHECK_NR=$(( ${TESTSET_LAST_CHECK_NR-0} + 1))
	# not increasing TESTSET_LAST_TEST_NR

	# param 1: directory
	# param 2: nr of files (except . and ..)
	local testdir="$1"
	local testexpected="$2"
	local testresult
	local rc

	if [ "${testdir:0:1}" != "/" ] ; then
		testdir="$TESTSET_DIR/$testdir"
	fi

	#shellcheck disable=SC2012 # no worries about non-alpha filenames here
	testresult=$(ls -1A "$testdir" 2>/dev/null | wc -l | tr -d ' ')

	if [ "$testresult" != "$testexpected" ] ; then
		# nr of files differ from expected
		printf "\tCHECK %s FAILED. nr of files in '%s' is %s (exp=%s)\n" \
			"$TESTSET_LAST_CHECK_NR" "$1" "$testresult" "$testexpected"
		# printf "========== Output Test %d Begin ==========\n" \
		#   "$TESTSET_LAST_TEST_NR"
		# cat $TESTSET_DIR/$TESTSET_LAST_TEST_NR.out
		# printf "========== Output Test %d End ==========\n" \
		#    "$TESTSET_LAST_TEST_NR"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
	else
		printf "\tCHECK %s OK.\n" "$TESTSET_LAST_CHECK_NR"
		TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
	fi

	return 0
}

function test_expect_file_contains {
	util_err_verify_or_exit

	TESTSET_LAST_CHECK_NR=$(( ${TESTSET_LAST_CHECK_NR-0} + 1))
	# not increasing TESTSET_LAST_TEST_NR

	# param 1: file
	# param 2: text to search for
	local testfile="$1"
	local testexpected="$2"
	local testresult
	local rc

	if [ "${testfile:0:1}" != "/" ] ; then
		testfile="$TESTSET_DIR/$testfile"
	fi

	if ! testresult=$(grep -F "$testexpected" "$testfile")
	then
		printf "\tCHECK %s FAILED. %s does not contain '%s'\n" \
			"$TESTSET_LAST_CHECK_NR" "$1" "$2"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
	else
		printf "\tCHECK %s OK.\n" "$TESTSET_LAST_CHECK_NR"
		TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
	fi

	return 0
}

function test_expect_linkedfiles {
	util_err_verify_or_exit

	TESTSET_LAST_CHECK_NR=$(( ${TESTSET_LAST_CHECK_NR-0} + 1 ))
	# not increasing TESTSET_LAST_TEST_NR

	# param 1-n: files that should be hard-linked to each other

	local fnam
	local testexpected
	local fnamexpected
	local testresult
	local rc

	for fnam in "$@" ; do
		if [ "${fnam:0:1}" != "/" ] ; then
			fnam="$TESTSET_DIR/$fnam"
		fi

		if ! testresult=$(
			#shellcheck disable=SC2012 # no worries about non-alpha filenames here
			ls -1i "$fnam" 2>/dev/null | cut -f 1 -d " "
			)
		then
			printf "\tCHECK %s FAILED. Cannot list file '%s'\n" \
				"$TESTSET_LAST_CHECK_NR" "$fnam"
			TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
			return 0
		elif [ -n "${testexpected-}" ] && [ "$testresult" != "$testexpected" ] ; then
			printf "\tCHECK %s FAILED. '%s' and '%s' have different INode\n" \
				"$TESTSET_LAST_CHECK_NR" "$fnam" "$fnamexpected"
			TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
			return 0
		elif [ -z "${testexpected-}" ] ; then
			testexpected="$testresult"
			fnamexpected="$fnam"
		fi
	done

	printf "\tCHECK %s OK.\n" "$TESTSET_LAST_CHECK_NR"
	TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))

	return 0
}

function testset_init {
	# Initialise a Testset
	# Tests are distinguishing between Tests and Checks.
	#   - Tests are executing a test, so they are active
	#   - Checks are verifying the result of last test. Thus they
	#     can access results of the last test.
	# Parameters:
	#   --log                    Always log test results. Useful during Development
	#   --testsetname=<name>     use <name> as TestSetName for
	#     better identification [default: TestSet]
	# Output Global variables that are steering testings and may be changed
	#         by other functions called during execution of testset
	#    TESTSET_LAST_CHECK_NR   Number or last Check or test
	#    TESTSET_LAST_TEST_NR    Number or last Test
	#    TESTSET_TESTSOK         List of succeeded tests
	#    TESTSET_TESTFAILED      List of failed tests (or empty string)
	# Output Global Variables that configure behaviour of framework
	#    TESTSET_LOG_ALWAYS      0 (default) or 1 (if --log is supplied).
	#    TESTSET_NAME            Name of Testset (--testsetname or default)
	#    TEST_SNAIL              Executable for snail mail program
	#    TESTSET_PARM            Array of Parameters for Testset
	util_err_verify_or_exit

	printf "TESTS Starting.\n"
	TESTSET_LAST_CHECK_NR=0
	TESTSET_LAST_TEST_NR=0
	TESTSET_TESTSOK=0
	TESTSET_TESTFAILED=""
	TESTSET_LOG_ALWAYS=0
	TESTSET_NAME="TestSet"
	TESTSET_PARM=()
	TEST_SNAIL=""

	if [[ "$OSTYPE" =~ darwin* ]] ; then
		if ! which ip ; then
			printf "ip command on MacOS missing. You may want to install it with\n%s\n" \
				"brew install iproute2mac"
			return 1
		fi
		printf "Activating MacOS workaround.\n"
		# TEST_RSYNCOPT="--rsync-path=/opt/homebrew/bin/rsync"
		TEST_SNAIL=/opt/homebrew/bin/s-nail
	elif
		[ "$(awk -F= '/^NAME/{print $2}' /etc/os-release)" == "\"Ubuntu\"" ]
	then
		printf "Activating Ubuntu settings.\n"
		# TEST_RSYNCOPT=""
		TEST_SNAIL=s-nail
	else
		printf "Using default OS (OSTYPE=%s, os-release/NAME=%s\n" \
			"$OSTYPE" \
			"$(awk -F= '/^NAME/{print $2}' /etc/os-release)"
		# TEST_RSYNCOPT=""
		TEST_SNAIL="mailx"
	fi

	while [ "$#" -ne 0 ] ; do case "$1" in
		--log )
			TESTSET_LOG_ALWAYS=1
			;;
		--testsetname=* )
			TESTSET_NAME="${1##--testsetname=}"
			;;
		* )
			TESTSET_PARM+=("$1")
			;;
		esac
		shift
	done

	TESTSET_DIR=$(mktemp -d "${TMPDIR:-/tmp}/$TESTSET_NAME.XXXXXXXXXX")
	printf "\tTESTSET_DIR=%s\n" "$TESTSET_DIR"
	printf "\tTESTSET_LOG_ALWAYS=%s\n" "$TESTSET_LOG_ALWAYS"
	printf "\tParms=%s\n" "${TESTSET_PARM[*]}"

	return 0
}

function testset_issuccess {
	if [ "$TESTSET_TESTSOK" -ne "$TESTSET_LAST_CHECK_NR" ] ; then
		return 1
	else
		return 0
	fi
}

function testset_summary {
	printf "TESTS Ended. %d of %d successful.\n" \
		"$TESTSET_TESTSOK" "$TESTSET_LAST_CHECK_NR"
	if [ "$TESTSET_TESTSOK" -ne "$TESTSET_LAST_CHECK_NR" ] ; then
		printf "Failed tests:%s\n" "$TESTSET_TESTFAILED"
		return 1
	fi

	return 0
}
