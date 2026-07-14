#!/usr/bin/env bash
#
# Support functions for error handling in bash
# inspired by https://stackoverflow.com/a/41864168
#
# (C) 2026 Stefan Schallenberg

declare -g UTIL_ERR_TRAPERR UTIL_ERR_PS4 UTIL_ERR_BASHDEB UTIL_ERR_INIT
declare -g UTIL_ERR_RC=0
declare -g util_err_rc=0 util_err_lineno=0

#shellcheck disable=SC2016 # intentionally not expanding vars here.
UTIL_ERR_TRAPERR='util_err_rc=$? ; util_err_lineno=$LINENO ;
		printf "Unhandled error %s in command %s at line %s in %s\n" \
			"$util_err_rc" "$BASH_COMMAND" "$util_err_lineno" \
			"${BASH_SOURCE[0]:-(null)}" ;
		util_err_print_stack ;
		exit 1
		'
#shellcheck disable=SC2016 # intentionally not expanding vars here.
# editorconfig-checker-disable-next-line
UTIL_ERR_PS4='+${BASH_SOURCE[0]:-(null)}(${LINENO})${FUNCNAME[0]:+ ${FUNCNAME[0]}()}: '

# bash debug settings; we use an array so that
# "${UTIL_ERR_BASHDEB[@]}"
# will expand to nothing or "-x".
if [ -o xtrace ] ; then
	UTIL_ERR_BASHDEB=( "-x" )
else
	UTIL_ERR_BASHDEB=()
fi

UTIL_ERR_INIT="set -Eeuo pipefail ; shopt -s inherit_errexit"

readonly UTIL_ERR_TRAPERR UTIL_ERR_PS4 UTIL_ERR_BASHDEB UTIL_ERR_INIT

function util_err_notrap {
	local funcname
	funcname="$1" ; shift

	trap - ERR
	"$funcname" "$@"
}

function util_err_enable {
	set -e # shellopt errexit - exit any shell on unchecked error

	#shellcheck disable=SC2064 # intentionally expanding here.
	trap "$UTIL_ERR_TRAPERR" ERR
	set -E # extend trap scope to whole shell

	# improve debug log, start each line with source, lineno andfunction
	export PS4="$UTIL_ERR_PS4"

	return 0
}

function util_err_disable {
	trap - ERR
	set +eE

	return 0
}

function util_err_callfunc {
	local funcname
	funcname="$1" ; shift

	util_err_disable
	(
		util_err_enable
		"$funcname" "$@"
	)
	export UTIL_ERR_RC=$?
	util_err_enable

	return 0
}

function util_err_print_stack {
	local i=1
	while (( i < ${#BASH_SOURCE[@]} )) ; do
		# echo "${BASH_SOURCE[i]-}"
		# echo "${BASH_LINENO[i]-}"
		# echo "${FUNCNAME[i]:+ ${FUNCNAME[i]}()}"
		printf "\t%s(%s)%s\n" \
			"${BASH_SOURCE[i]:-null}" \
			"${BASH_LINENO[i-1]:-null}" \
			"${FUNCNAME[i]:+ ${FUNCNAME[i]}()}"
		(( i++ ))
	done

	return 0
}

function util_err_verify_or_exit {
	local msg
	if ! shopt -qo errexit ; then
		msg="set -e / -o errexit"
	elif ! shopt -q inherit_errexit ; then
		msg="shopt inherit_errexit"
	elif ! shopt -qo errtrace ; then
		msg="set -E / -o errtrace"
	elif ! shopt -qo nounset ; then
		msg="set -u / -o nounset"
	elif ! shopt -qo pipefail ; then
		msg="set -o pipefail"
	elif [ "$(trap -p ERR)" != "trap -- '$UTIL_ERR_TRAPERR' ERR" ] ; then
		msg="trap ERR"
	# verify PS4 for debug output
	elif [ "$PS4" != "$UTIL_ERR_PS4" ] ; then
		msg="PS4"
	else
		return 0 # all OK!
	fi

	printf "%s: Internal Error. %s not set when called by %s. Exiting.\n" \
		"${FUNCNAME[0]}" "$msg" "${FUNCNAME[1]}"
	util_err_print_stack

	exit 1
}

# we do NOT "set -Eeuo pipefail ; shopt -s inherit_errexit" here.
# For clarity of code, we expect it to be set by the caller.
# If it is not set, we fail.

#shellcheck disable=SC2064 # intentionally expanding here.
trap "$UTIL_ERR_TRAPERR" ERR

# improve debug log, start each line with source, lineno andfunction
export PS4="$UTIL_ERR_PS4"

# make shellcheck happy
: "$util_err_rc $util_err_lineno ${#UTIL_ERR_BASHDEB[@]} $UTIL_ERR_INIT"

util_err_verify_or_exit
