#!/bin/bash
#
# Allgemeine Test Bibliothek
#
# (C) 2017 Stefan Schallenberg

function test_cleanImap {
	if [ "$#" -ne 3 ] ; then
		printf "%s: Internal Error. Got %s parms (exp=3)\n" \
			"${FUNCNAME[0]}" "$#"
		return 1
	fi

	local mail_adr="$1"
	local mail_pw="$2"
	local mail_srv="$3"

	local imapstatus

	printf "Cleaning %s at %s. Deleting all Mails.\n" \
		"$mail_adr" "$mail_srv"

	imapstatus=$(
		curl --ssl-reqd --silent --show-error \
		"imap://$mail_srv" \
		--user "$mail_adr:$mail_pw" \
		--request 'STATUS INBOX (MESSAGES)'
	) || return 1
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

	imapstatus=$(
		curl --ssl-reqd --silent --show-error \
		"imap://$mail_srv/INBOX" \
		--user "$mail_adr:$mail_pw" \
		--request 'STORE 1:* +FLAGS \Deleted'
	) || return 1

	imapstatus=$(
		curl --ssl-reqd --silent --show-error \
		"imap://$mail_srv/INBOX" \
		--user "$mail_adr:$mail_pw" \
		--request 'EXPUNGE'
	) || return 1

	return 0
}

function test_putImap {
	if [ "$#" -ne 3 ] ; then
		printf "%s: Internal Error. Got %s parms (exp=3)\n" \
			"${FUNCNAME[0]}" "$#"
		return 1
	fi

	local mail_adr="$1"
	local mail_pw="$2"
	local mail_srv="$3"

	printf "Storing a Mail into %s at %s.\n" \
		"$mail_adr" "$mail_srv"

	cat >"$TESTSET_DIR/testmsg" <<-EOF &&
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

	curl --ssl-reqd --silent --show-error \
		"imap://$mail_srv/INBOX" \
		--user "$mail_adr:$mail_pw" \
		-T "$TESTSET_DIR/testmsg" &&

	curl --ssl-reqd --silent --show-error \
		"imap://$mail_srv/INBOX" \
		--user "$mail_adr:$mail_pw" \
		--request 'STORE 1 -Flags /Seen' &&

	true || return 1

	return 0
}

function test_exec_init {
	local testdesc="$1"

	TESTSET_LAST_CHECK_NR=$(( ${TESTSET_LAST_CHECK_NR-0} + 1))
	TESTSET_LAST_TEST_NR=$TESTSET_LAST_CHECK_NR

	printf "Executing Test %d (%s:%s %s) ... " "$TESTSET_LAST_CHECK_NR" \
		"${BASH_SOURCE[2]}" "${BASH_LINENO[1]}" "${FUNCNAME[2]}"

	if [ -n "$testdesc" ] ; then
		printf "\t%s\n" "$testdesc"
	fi

	return 0
}

function test_lastoutput_contains {
	TESTSET_LAST_CHECK_NR=$(( ${TESTSET_LAST_CHECK_NR-0} + 1))
	# not increasing TESTSET_LAST_TEST_NR
	local search="$1"
	local extension="${2:-.out}"
	local grepopts="$3"
	local altsearch="$4"

	local grep_cnt
	#shellcheck disable=SC2086 # grepopts contains multiple parms
	grep_cnt=$(
		grep -c $grepopts "$search" \
		<"$TESTSET_DIR/$TESTSET_LAST_TEST_NR$extension"
		)
	if [ $? -gt 1 ] ; then
		# grep error
		printf "ERROR checking %s. Search: '%s'\n" \
			"$TESTSET_LAST_CHECK_NR" "$search"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
		return 1
	elif [ "$grep_cnt" == "0" ] ; then
		# expected text not in output.
		printf "CHECK %s FAILED. '%s' not found in output of test %s\n" \
			"$TESTSET_LAST_CHECK_NR" "$search" "$TESTSET_LAST_TEST_NR"
		if [ -n "$altsearch" ] ; then
			printf "========== Selected Output Test %d Begin ==========\n" \
				"$TESTSET_LAST_TEST_NR"
			grep "$altsearch" "$TESTSET_DIR/$TESTSET_LAST_TEST_NR$extension"
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
	local RC

	cmp --quiet \
		<(printf "%s" "$exp") \
		<(tail --lines=+4 "$TESTSET_DIR/$TESTSET_LAST_TEST_NR$extension")
	RC="$?"
	if [ "$RC" -gt 1 ] ; then
		# cmp error
		printf "ERROR checking lastoutput %s.\n" "$TESTSET_LAST_CHECK_NR"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
		return 1
	elif [ "$RC" -gt 0 ] ; then
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
	TESTSET_LAST_CHECK_NR=$(( ${TESTSET_LAST_CHECK_NR-0} + 1))
	# not increasing TESTSET_LAST_TEST_NR
	local linecountexp="$1"
	local extension="${2:-.out}"

	local linecountact
	linecountact=$(wc -l <"$TESTSET_DIR/$TESTSET_LAST_TEST_NR$extension")
	# Ignore Log Lines inserted at the beginning
	linecountact=$(( linecountact - 3 ))
	if [ $? -gt 1 ] ; then
		# wc error
		printf "ERROR checking linecount %s.\n" "$TESTSET_LAST_CHECK_NR"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
		return 1
	elif [ "$linecountact" == "$linecountexp" ] ; then
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

	tail --lines=+4 "$TESTSET_DIR/$TESTSET_LAST_TEST_NR$extension" || return 1

	return 0
}

function test_wait_url {
	# Parameters:
	#     1 - url
	#     2 - timeout in seconds
	#     3ff - additional dnsnames or IPs to wait for
	#           the request is done with the original url but network
	#           connects to this adresses (curl --connect-to)
	local -r url="$1"
	local -r timeout="$2"
	shift 2

	if
		[[ ! "$url" =~ ^http://.* ]] &&
		[[ ! "$url" =~ ^https://.* ]]
	then
		printf "%s: Invalid url (not http[s]) \"%s\"\n" "${FUNCNAME[0]}" "$url"
		return 1
	elif [ -z "$timeout" ] ; then
		printf "%s: No timeout given for %s\n" \
			"${FUNCNAME[0]}" "$url"
		return 1
	fi

	local i dnsname
	dnsname=${url#*://}
	dnsname=${dnsname%%/*}
	dnsname=${dnsname%%:*}

	i=$(date '+%s') || return 1
	# tricky solution: "error error" is an invalid arithmetic producing an
	# error and abort. Please note that "error" would just represent the value
	# of the (unset) variable error and NOT produce an abort
	while (( $(date '+%s' || echo "error error") - i < timeout )) ; do
		local ips=() iptemp=() ip="" ok="1" n || return 1
		for n in "$dnsname" "$@" ; do
			util_getIP "$n" "" "iptemp" &&
			ips+=( "${iptemp[@]}" ) &&
			true || return 1
		done

		for ip in "${ips[@]}" ; do
			if [[ "$ip" == *:* ]] ; then
				ip="[$ip]" # curl needs IPv6 adresses enclosed in brackets
			fi
			if \
				curl -k -f "$url" \
					-o /dev/null \
					--connect-to "$dnsname::$ip" \
					--no-progress-meter
			then
				printf "Successfully connected to %s with IP %s\n" \
					"$url" "$ip"
			else
				printf "Error connecting to %s with IP %s - retrying\n" \
					"$url" "$ip"
				ok=0
			fi
		done

		if [ "$ok" == 1 ] ; then
			printf "%s reachable\n" "$url"
			return 0
		fi

		printf "waiting for url %s: sleep 5 seconds (%s/%s)\n" \
				"$url" $(( $(date '+%s') - i)) "$timeout"
		sleep 5
	done

	printf "timed out waiting for url %s\n" "$url"
	return 1
}

function test_exec_cmd {
	# Parameters:
	#     1 - expected RC [default: 0]
	#     2 - optional message to be printed if test fails
	#     3+ - command to be executed
	if [ "$#" -lt 3 ] ; then
		printf "%s: Internal error: too few parameters (%s < 3)\n" \
			"${FUNCNAME[0]}" "$#"
		return 1
	fi

	test_exec_init || return 1

	local -r rc_exp=${1:-0}
	local testmsg=$2
	shift 2 || return 1
	local testrc

	printf "#-----\n#----- Command: %s\n#-----\n" "$*" \
		>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
	"$@" >>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out" 2>&1
	testrc=$?

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
	#     3ff - command to test
	test_exec_init || return 1

	local sshtarget="$1"
	shift
	local rc_exp=${1:-0}
	shift

	local sshopt="-n"
	local testrc

	printf "#-----\n#----- SSH Machine: %s, Command: %s\n#-----\n" \
		"$sshtarget" "$*" \
		>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
	[ "$#" == 0 ] && sshopt=""
	#shellcheck disable=SC2029
	ssh $sshopt "$sshtarget" "$*" \
		>>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out" 2>&1
	testrc=$?

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

function test_exec_url {
	test_exec_init || return 1

	local url="$1"
	local rc_exp=${2-200}
	shift 2
	local testrc

	testrc=$(curl -s "$@" \
		-i -v \
		-o "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.curlout" \
		--stderr "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.curlerr" \
		-w "%{http_code}" \
		"$url")
	local rc=$?
	if [ $rc -ne 0 ] || [ "$testrc" != "$rc_exp" ] ; then
		printf "FAILED. RC=%d HTTP-Code=%s (exp=%s)\n" \
		"$rc" "$testrc" "$rc_exp"
		printf "URL: %s\n" "$url"
		printf "Options: %s\n" "$@"
		printf "========== Output Test %d Begin ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		cat "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.curlout"
		printf "\n"
		printf "========== Output Test %d End ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		printf "========== stderr-Output Test %d Begin ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		cat "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.curlerr"
		printf "\n"
		printf "========== stderr-Output Test %d End ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		[ "$rc" -ne 0 ] && testrc=999
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
	else
		printf "OK\n"
		TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
		if [ "$TESTSET_LOG_ALWAYS" == "1" ] ; then
			printf "========== Output Test %d Begin ==========\n" \
				"$TESTSET_LAST_CHECK_NR"
			cat "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.curlout"
			printf "\n"
			printf "========== Output Test %d End ==========\n" \
				"$TESTSET_LAST_CHECK_NR"
		fi
	fi

	return 0
}

function test_internal_exec_kube {
	local -r kubecmd="$1"
	local -r kubecomment="$2"
	local -r kubenolog="$3"
	local cmd rc

	util_kube_internal_verify_initialised &&
	util_kube_internal_create_namespace &&
	true || return 1

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

	#shellcheck disable=SC2086 # cmd and kubecmd contains more than one parm
	TEST_INTERNAL_EXEC_KUBE_OUTPUT=$(set +x ; eval $cmd $kubecmd 2>&1)
	rc=$?
	if [ -z "$kubenolog" ] || [ "$rc" != 0 ] ; then
		printf "%s\n" \
			"$TEST_INTERNAL_EXEC_KUBE_OUTPUT" \
			>>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
	fi

	return $rc
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
	test_assert_tools "jq" || return 1
	test_exec_init || return 1

	local -r cronjobname="$1"
	local -r rc_exp="${2-0}"
	local -r infomsg="$3"
	local -r sleepMax=${4:-240}
	local -r sleepNext=5

	local testrc="" jobStatus jobActive jobFailed jobSucceeded jobCondition
	local slept=0

	test_internal_exec_kube \
		"delete job/$cronjobname-test" \
		"try deleting previous jobs" \
	|| true # Ignore errors here!

	test_internal_exec_kube \
		"create job $cronjobname-test --from=cronjob/$cronjobname" \
		|| testrc=3

	while [ -z "$testrc" ] ; do
		test_internal_exec_kube \
			"get job $cronjobname-test -o json | jq '.status'" \
			"" "1" &&
		jobStatus="$TEST_INTERNAL_EXEC_KUBE_OUTPUT" &&
		jobActive=$(jq '.active // 0' <<<"$jobStatus" 2>&1) &&
		jobFailed=$(jq '.failed // 0' <<<"$jobStatus" 2>&1) &&
		jobSucceeded=$(jq '.succeeded // 0' <<<"$jobStatus" 2>&1) &&
		# editorconfig-checker-disable
		jobCondition=$(jq -r \
			'try .conditions[] | select( (.status=="True" ) and ( .type | IN("Complete","Failed") ) ).type' \
			<<<"$jobStatus" 2>&1
			)
		# editorconfig-checker-enable
		#shellcheck disable=SC2181 # using $? here helps to keep the structure
		if [ "$?" != 0 ] ; then
			printf "%s\nACTIVE=%s\nFAILED=%s\nSUCCEEDED=%s\nCONDSTATUS=%s\n" \
				"$jobStatus" "$jobActive" "$jobFailed" "$jobSucceeded" \
				"$jobCondition" \
				>>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
			testrc=3
			break
		elif [ "$jobCondition" == "Complete" ] ; then
			printf "  Completed Job: %s/%s/%s/%s (%s)\n" \
				"$jobActive" "$jobFailed" "$jobSucceeded" "$jobCondition" \
				"active/failed/succeeded/condition" \
				>>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
			testrc=0
			break
		elif [ "$jobCondition" == "Failed" ] ; then
			printf "     Failed Job: %s/%s/%s/%s (%s)\n" \
				"$jobActive" "$jobFailed" "$jobSucceeded" "$jobCondition" \
				"active/failed/succeeded/condition" \
				>>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
			testrc=1
			break
		elif [ "$slept" -gt "$sleepMax" ] ; then
			printf "   TimedOut Job: %s/%s/%s/%s (%s)\n" \
				"$jobActive" "$jobFailed" "$jobSucceeded" "$jobCondition" \
				"active/failed/succeeded/condition" \
				>>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
			testrc=2
			break
		else
			printf "Waiting for Job: %s/%s/%s/%s (%s)" \
				"$jobActive" "$jobFailed" "$jobSucceeded" "$jobCondition" \
				"active/failed/succeeded/condition" \
				>>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
			printf " sleep %s seconds (%s/%s)\n" \
					"$sleepNext" "$slept" "$sleepMax" \
					>>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"

			sleep $sleepNext ; slept=$(( slept + sleepNext ))
		fi
	done

	# Always try to print logs of Pods, even in case of errors
	test_internal_exec_kube \
		"logs job/$cronjobname-test --all-containers" \
		|| testrc=2

	if [ "$testrc" -ne "$rc_exp" ] ; then
		printf "FAILED. RC=%d (exp=%d)\n" "$testrc" "$rc_exp"
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
		local cmd
		cmd="kubectl --kubeconfig $KUBE_CONFIGFILE --namespace $KUBE_NAMESPACE"
		cmd+=" delete job/$cronjobname-test"
		printf "#----- Delete Job\n#----- Command: %s\n" "$cmd" \
			>>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
		#shellcheck disable=SC2086 # cmd contains multiple parms
		# ignore if deleting job fails.
		eval $cmd >>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out" 2>&1 || true

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

function test_exec_kubenode {
	# Parameters:
	#     1 - name of the node
	#     2 - DNS name of the VM to run kubectl
	#         if empty, the current machine will be used (no ssh)
	#     3 - timeout in sec
	#     4+ - IP adresses or DNS names to verify connection with
	test_exec_init || return 1

	local -r nodename="${1,,}" # lowercase
	local -r dnsname="$2"
	local -r timeout="$3"
	local -r prm_count="$#"
	shift 3

	if [ "$prm_count" -lt 3 ] ; then
		printf "%s: Internal Error, less than 3 parms\n" "${FUNCNAME[0]}"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
		return 1
	elif [ -z "$nodename" ] ; then
		printf "Error: nodename empty\n"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
		return 1
	elif [ -z "$dnsname" ] ; then
		printf "Error: dnsnamee empty\n"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
		return 1
	elif [ -z "$timeout" ] ; then
		printf "Error: timeoute empty\n"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
		return 1
	elif [ -z "$*" ] ; then
		printf "Error: Parm IP Adress missing\n"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
		return 1
	fi

	local ips=() dnsip=()
	for f in "$@" ; do
		util_getIP "$f" "" dnsip &&
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
						printf "ping -c 1 -4 %s &&" "$f"
					else
						printf "ping -c 1 -6 %s &&" "$f"
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
	kubecmd+=" --rm"
	kubecmd+=" --pod-running-timeout=7m"

	local testrc
	#shellcheck disable=SC2087 # intentionally expand on client side
	cat \
		<(echo "----- CMD Begin ------") \
		"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.in" \
		<(echo "----- CMD End ------") \
		>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out"
	# do NOT use ssh -n here !
	ssh -o StrictHostKeyChecking=no "$dnsname" \
		kubectl "$kubecmd" \
	<"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.in" \
	>>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.out" 2>&1

	testrc=$?

	if [ "$testrc" -ne 0 ] ; then
		printf "FAILED. RC=%d (exp=%d)\n" "$testrc" "$rc_exp"
		if [ -n "$msg" ] ; then
			printf "Info: %s\n" "$3"
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

function test_exec_recvmail {
	local url="$1"
	local rc_exp="${2:-0}"
	shift 2

	[ -z "$TEST_SNAIL" ] && return 1
	test_exec_init "recvmail $rc_exp $url" || return 1

	local testrc
	local MAIL_STD_OPT
	MAIL_STD_OPT="-e -n -vv -Sv15-compat -Snosave"
	MAIL_STD_OPT+=" -Sexpandaddr=fail,-all,+addr"
	readonly MAIL_STD_OPT
	local MAIL_OPT="-S 'inbox=$url'"

	#shellcheck disable=SC2086 # vars contain multiple parms
	LC_ALL=C MAILRC=/dev/null \
		eval $TEST_SNAIL $MAIL_STD_OPT $MAIL_OPT "$*" \
		>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.mailout" \
		2>&1 \
		</dev/null
	testrc=$?
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
}

function test_exec_sendmail {
	local url="$1"
	local rc_exp="${2:-0}"
	local from="$3"
	local to="$4"
	shift 4

	[ -z "$TEST_SNAIL" ] && return 1
	test_exec_init "sendmail $rc_exp $url" || return 1

	local MAIL_STD_OPT
	MAIL_STD_OPT="-n -vv -Sv15-compat -Ssendwait -Snosave"
	MAIL_STD_OPT+=" -Sexpandaddr=fail,-all,+addr"
	readonly MAIL_STD_OPT
	MAIL_OPT="-S 'smtp=$url'"
	MAIL_OPT="$MAIL_OPT -s 'Subject TestMail $TESTSET_LAST_CHECK_NR'"
	MAIL_OPT="$MAIL_OPT -r '$from'"

	#shellcheck disable=SC2086 # vars contain multiple parms
	LC_ALL=C MAILRC=/dev/null \
		eval $TEST_SNAIL $MAIL_STD_OPT $MAIL_OPT "$*" '$to' \
		>"$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.mailout" \
		2>&1 \
		<<<"Text TestMail $TESTSET_LAST_CHECK_NR"
	testrc=$?
	if [ "$testrc" -ne "$rc_exp" ] ; then
		printf "FAILED. RC=%d (exp=%d)\n" "$rc" "$rc_exp"
		printf "send_testmail(%s,%s,%s,%s,%s)\n" \
			"$rc_exp" "$url" "$from" "$to" "$*"
		printf "CMD: $TEST_SNAIL %s %s %s '%s'\n" \
			"$MAIL_STD_OPT" "$MAIL_OPT" "$*" "$to"
		printf "========== Output Test %d Begin ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		cat "$TESTSET_DIR/$TESTSET_LAST_CHECK_NR.mailout"
		printf "========== Output Test %d End ==========\n" \
			"$TESTSET_LAST_CHECK_NR"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
	else
		printf "OK\n"
		TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
	fi
}

function test_exec_issuccess {
	if [ "${TESTSET_TESTFAILED##* }" == "$TESTSET_LAST_CHECK_NR" ] ; then
		return 1
	else
		return 0
	fi
}

function test_assert {
	TESTSET_LAST_CHECK_NR=$(( ${TESTSET_LAST_CHECK_NR-0} + 1))
	local testrc

	printf "Executing Assert %d (Manual %s:%s %s) ... " "$TESTSET_LAST_CHECK_NR" \
		"${BASH_SOURCE[1]}" "${BASH_LINENO[0]}" "${FUNCNAME[1]}"

	if [ "$1" != "0" ] ; then
		printf "FAILED: %s\n" "$2"
		testrc=1
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
		return $testrc
	fi

	printf "OK\n"
	testrc=0
	TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
	return $testrc
}

function test_assert_tools {
	TESTSET_LAST_CHECK_NR=$(( ${TESTSET_LAST_CHECK_NR-0} + 1))
	local testrc

	printf "Executing Assert %d (Tools %s) ... " "$TESTSET_LAST_CHECK_NR" "$*"

	for f in "$@" ; do
		if ! errmsg=$(which "$f" 2>&1) ; then
			printf "FAILED: Missing %s\n\t%s\n" \
				"$f" "$errmsg"
			testrc=1
			TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
			return $testrc
		fi
	done

	printf "OK\n"
	testrc=0
	TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
	return $testrc
}

function test_assert_vars {
	TESTSET_LAST_CHECK_NR=$(( ${TESTSET_LAST_CHECK_NR-0} + 1))
	local testrc

	printf "Executing Assert %s (Vars %s) ... " "$TESTSET_LAST_CHECK_NR" "$*"

	for f in "$@" ; do
		if eval "[ -z \"\$$f\" ]" ; then
			printf "FAILED: Missing %s\n" "$f"
			testrc=1
			TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
			return $testrc
		fi
	done

	printf "OK\n"
	testrc=0
	TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
	return $testrc
}

function test_assert_files {
	TESTSET_LAST_CHECK_NR=$(( ${TESTSET_LAST_CHECK_NR-0} + 1))
	local testrc

	printf "Executing Assert %s (Files %s) ... " "$TESTSET_LAST_CHECK_NR" "$*"

	for f in "$@" ; do
		if [ ! -f "$f" ] ; then
			printf "FAILED: Missing %s\n" "$f"
			testrc=1
			TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
			return $testrc
		fi
	done

	printf "OK\n"
	testrc=0
	TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
	return $testrc
}

function test_expect_value {
	TESTSET_LAST_CHECK_NR=$(( ${TESTSET_LAST_CHECK_NR-0} + 1))
	# not increasing TESTSET_LAST_TEST_NR

	# parm 1: file
	local testvalue="$1"
	local testvalexpected="$2"
	local rc

	if [ "$testvalue" == "$testvalexpected" ] ; then
		printf "\tCHECK %s OK.\n" "$TESTSET_LAST_CHECK_NR"
		TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
		return 0
	else
		printf "\tCHECK %s FAILED. Value='%s' (exp='%s')\n" \
			"$TESTSET_LAST_CHECK_NR" "$testvalue" "$testvalexpected"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
		return 0
	fi

	# should not reach this
	#shellcheck disable=SC2317
	return 99
}

function test_expect_file_missing {
	TESTSET_LAST_CHECK_NR=$(( ${TESTSET_LAST_CHECK_NR-0} + 1))
	# not increasing TESTSET_LAST_TEST_NR

	# parm 1: file
	local testfile="$1"
	local rc

	if [ "${testfile:0:1}" != "/" ] ; then
		testfile="$TESTSET_DIR/$testfile"
	fi

	testresult=$(ls -1A "$testfile" 2>/dev/null )
	rc=$?

	if [ "$rc" == "1" ] || [ "$rc" == "2" ]; then
		printf "\tCHECK %s OK.\n" "$TESTSET_LAST_CHECK_NR"
		TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
		return 0
	elif [ "$rc" == "0" ] ; then
		printf "\tCHECK %s FAILED. File '%s' exists\n" \
			"$TESTSET_LAST_CHECK_NR" "$1"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
		return 0
	else
		printf "\tCHECK %s FAILED. Cannot get files in '%s'\n" \
			"$TESTSET_LAST_CHECK_NR" "$1"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
		return 1
	fi

	# should not reach this
	#shellcheck disable=SC2317
	return 99
}

function test_expect_files {
	TESTSET_LAST_CHECK_NR=$(( ${TESTSET_LAST_CHECK_NR-0} + 1))
	# not increasing TESTSET_LAST_TEST_NR

	# parm 1: directory
	# parm 2: nr of files (except . and ..)
	local testdir="$1"
	local testexpected="$2"
	local testresult
	local rc

	if [ "${testdir:0:1}" != "/" ] ; then
		testdir="$TESTSET_DIR/$testdir"
	fi

	#shellcheck disable=SC2012 # no worries about non-alpha filenames here
	testresult=$( \
		set -o pipefail ;
		ls -1A "$testdir" 2>/dev/null | wc -l | tr -d ' '
		)
	rc=$?

	if [ "$rc" != 0 ] ; then
		printf "\tCHECK %s FAILED. Cannot get files in '%s'\n" \
			"$TESTSET_LAST_CHECK_NR" "$1"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
		return 1
	elif [ "$testresult" != "$testexpected" ] ; then
		# nr of files differ from expected
		printf "\tCHECK %s FAILED. nr of files in '%s' is %s (exp=%s)\n" \
			"$TESTSET_LAST_CHECK_NR" "$1" "$testresult" "$testexpected"
		# printf "========== Output Test %d Begin ==========\n" \
		#   "$TESTSET_LAST_TEST_NR"
		# cat $TESTSET_DIR/$TESTSET_LAST_TEST_NR.out
		# printf "========== Output Test %d End ==========\n" \
		#    "$TESTSET_LAST_TEST_NR"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
		return 0
	else
		printf "\tCHECK %s OK.\n" "$TESTSET_LAST_CHECK_NR"
		TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
		return 0
	fi

	# should not reach this
	#shellcheck disable=SC2317
	return 99
}

function test_expect_file_contains {
	TESTSET_LAST_CHECK_NR=$(( ${TESTSET_LAST_CHECK_NR-0} + 1))
	# not increasing TESTSET_LAST_TEST_NR

	# parm 1: file
	# parm 2: text to search for
	local testfile="$1"
	local testexpected="$2"
	local testresult
	local rc

	if [ "${testfile:0:1}" != "/" ] ; then
		testfile="$TESTSET_DIR/$testfile"
	fi

	testresult=$(grep -F "$testexpected" "$testfile")
	rc=$?

	if [ "$rc" != 0 ] ; then
		printf "\tCHECK %s FAILED. %s does not contain '%s'\n" \
			"$TESTSET_LAST_CHECK_NR" "$1" "$2"
		TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
		return 1
	else
		printf "\tCHECK %s OK.\n" "$TESTSET_LAST_CHECK_NR"
		TESTSET_TESTSOK=$(( ${TESTSET_TESTSOK-0} + 1))
		return 0
	fi

	# should not reach this
	#shellcheck disable=SC2317
	return 99
}

function test_expect_linkedfiles {
	TESTSET_LAST_CHECK_NR=$(( ${TESTSET_LAST_CHECK_NR-0} + 1 ))
	# not increasing TESTSET_LAST_TEST_NR

	# parm 1-n: files that should be hard-linked to each other

	local fnam
	local testexpected
	local fnamexpected
	local testresult
	local rc

	for fnam in "$@" ; do
		if [ "${fnam:0:1}" != "/" ] ; then
			fnam="$TESTSET_DIR/$fnam"
		fi

		testresult=$(
			set -o pipefail ;
			#shellcheck disable=SC2012 # no worries about non-alpha filenames here
			ls -1i "$fnam" 2>/dev/null | cut -f 1 -d " "
			)
		rc=$?

		if [ "$rc" != 0 ] ; then
			printf "\tCHECK %s FAILED. Cannot list file '%s'\n" \
				"$TESTSET_LAST_CHECK_NR" "$fnam"
			TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
			return 1
		elif [ -n "$testexpected" ] && [ "$testresult" != "$testexpected" ] ; then
			printf "\tCHECK %s FAILED. '%s' and '%s' have different INode\n" \
				"$TESTSET_LAST_CHECK_NR" "$fnam" "$fnamexpected"
			TESTSET_TESTFAILED="$TESTSET_TESTFAILED $TESTSET_LAST_CHECK_NR"
			return 1
		elif [ -z "$testexpected" ] ; then
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
	# Tests are distinguishing between Tests anc Checks.
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
	local testsetparm

	printf "TESTS Starting.\n"
	TESTSET_LAST_CHECK_NR=0
	TESTSET_LAST_TEST_NR=0
	TESTSET_TESTSOK=0
	TESTSET_TESTFAILED=""
	TESTSET_LOG_ALWAYS=0
	TESTSET_NAME="TestSet"
	TEST_SNAIL=""

	if [[ "$OSTYPE" =~ darwin* ]] ; then
		if ! which ip ; then
			printf "ip command on MacOS missing. You may want to install it with\n%s\n" \
				"brew install iproute2mac"
			return 1
		fi
		printf "Activating MacOS workaround.\n"
		# TEST_RSYNCOPT="--rsync-path=/usr/local/bin/rsync"
		TEST_SNAIL=/usr/local/bin/s-nail
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
			testsetparm+="$1"
			;;
		esac
		shift
	done

	TESTSET_DIR=$(mktemp -d "${TMPDIR:-/tmp}/$TESTSET_NAME.XXXXXXXXXX") \
		|| return 1
	printf "\tTESTSET_DIR=%s\n" "$TESTSET_DIR"
	printf "\tTESTSET_LOG_ALWAYS=%s\n" "$TESTSET_LOG_ALWAYS"
	printf "\tParms=%s\n" "$testsetparm"

	#shellcheck disable=SC2086
	set -- $testsetparm

	return 0
}

function testset_success {
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
