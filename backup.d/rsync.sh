#!/bin/bash
#
# backup_rsync
# (C) 2015 Stefan Schallenberg
#
# Usage: backup_rsync [ --hist | --inet | --inetlog=<logfile> ] <source> <dest>
#            Copies all files from <source> to <dest> recursively, using rsync
#
#    Add Ons to rsync:
#        --hist enable HISTORY mode (see below)
#        --inet enable INTERNE mode (see below)
#        --inetlog=<logfile> enable INTERNET mode (see below)
#                            and write LOG (see below)
#        --ssh enable SSH mode (connect to remote rsync via SSH)
#        --sshlog=<logfile> enable SSH mode and write to log
#        <source> may be of format machine:/directory, then SSH is used.
#        <dest> does NOT support remote machines
#
#    HISTORY MODE:
#        History is supposed to create daily backups with hard-link to previous
#        backups for unmodified files.
#            1) a Directory named like 20151107 is created in DEST directoy
#            2) all files are compared with the latest subdirectory in DEST
#            3) unmodified files will be created in DEST/TODAY as hardlinks
#               to the same file in latest subdirectory
#            4) modified files will be copied
#            5) dest directoy may be local only
#
#    INTERNET MODE:
#         Internet Mode is designed to support target on WebDav system.
#            1) Timestamps are not reliable (most WebDav server always put
#               the current timestamp at write time and do now allow to
#               modify it)
#            2) Symbolic LInks are excluded (not allowed on WebDav)
#            3) NO Delete will be executed for safety reasond. If
#               INTERNT LOG Mode ist set, a logfile will be created that
#               shows all files that shoul be deleted.
#               to execute the deletes just call <logfilename>.sh
#
##############################################################################
# hint: IN order to compare two directories created in HISTORY Mode you may
# want to use e.g.
#       rsync -rvn 20151110/ 20151111/
#

function backup_rsync {
	local readonly debug=${debug:-0}
	local hist=0
	local rebase=0
	local inetlog=0
	local logfile=""
	local prm=""
	local histparm=""
	local currback=""
	local lastback=""
	local opt="-aHX --delete"
	local allowSrcRemote=1
	local allowDstRemote=0

	if [ x"$DEBUG" == x1 ] ; then
		printf "DEBUG: %s %s\n" "$FUNCNAME" "$*"
	fi

	if [ $# -lt 2 ]; then
		printf "Error: wrong number or arguments (%d given, >=2 expected)", "$#"
		exit -1
	fi

	if [ "$1" == "--hist" ] ; then
		hist=1
		shift
	elif [ "$1" == "--inet" ] ; then
		opt="-rLt --size-only --partial"
		shift
	elif [ "${1%%=*}" == "--inetlog" ] ; then
		inetlog=1
		logfile=${1#*=}
		opt="-rLt --size-only --partial"
		# optlog3="-n --info=DEL -r --delete --existing --ignore-existing"
		optlog3="-n --info=DEL,STATS0 --debug=NONE -r --delete --force --delete-excluded --existing --ignore-existing"
		shift
	elif [ "$1" == "--ssh" ] ; then
		allowDstRemote=1
		allowSrcRemote=0
		shift
		opt="-aH --partial"
	elif [ "${1%%=*}" == "--sshlog" ] ; then
		# NB: euserv.deßs remote RSync does currently not support --info=DEL,STATS0
		# Thats why we switched back to -n -v
		inetlog=1
		logfile=${1#*=}
		allowDstRemote=1
		allowSrcRemote=0
		shift
		opt="-aH --partial"
		#optlog3="-n --info=DEL,STATS0 --debug=NONE -r --delete --force --delete-excluded --existing --ignore-existing"
		optlog3="-n -v --recursive --delete --delete-excluded --ignore-non-existing --ignore-existing"
		# Options successful tried manually:
		#rsync -n -v -aH --delete --ignore-non-existing --ignore-existing --ignore-errors "--exclude=Thumbs.db*"
	elif [ "$1" == "--rebase" ] ; then
		allowDstRemote=0
		allowSrcRemote=0
		shift
		rebase=1
	elif [ "${1:0:2}" == "--" ] ; then
		printf "Error: Unknown option \"%s\"\n" "$1"
		exit -1
	fi

	#### NB: %/ removes a trailing slash if it exists
	local src="${1%/}"
	local dst="${2%/}"
	shift 2

	if [ $# -gt 0 ]; then
		# we got additional rsync parameters
		prm="$*"
	else
		prm=""
	fi

	if [[ "$src" == *":"* ]] ; then
		if [ $allowSrcRemote -eq 1 ]; then
			if [ $debug -eq 1 ]; then
				printf "Source Directory not checked, its on another computer.\n"
			fi
		else
			printf "Error: Source Directory cannot be on another computer.\n"
			exit -2
		fi
	elif [ ! -d "$src" ]; then
		printf "Error: Source Directory %s does not exist\n" "$src"
		exit -3
	else
		if [ $debug -eq 1 ]; then
			printf "Source Directory OK.\n"
		fi
	fi

	if [[ "$dst" == *":"* ]] ; then
		if [ $allowDstRemote -eq 1 ]; then
			if [ $debug -eq 1 ]; then
				printf "Dest Directory not checked, its on another computer.\n"
			fi
		else
			printf "Error: Dest Directory cannot be on another computer.\n"
			exit -4
		fi
	elif [ ! -d "$dst" ]; then
		# Not an error, Dest-Dir will be created by rsync
		if [ $debug -eq 1 ]; then
			printf "Dest Directory will be created.\n"
		fi
	else
		if [ $debug -eq 1 ]; then
			printf "Dest Directory OK.\n"
		fi
	fi

	if [ ! -z $logfile ] && [ "${logfile:0:1}" != "/" ] ; then
		printf "Error: Logfilename %s does not start with a slash.\n" "$logfile"
		exit -6
	fi

	if [ $hist -eq 1 ] ; then
		##### HISTORY MODE #####
		currback="$dst/$(date +%Y%m%d)"
		lastback=$(ls -rd $dst/2* 2>/dev/null | head -1)
		if [ "$currback" == "$lastback" ] ; then
			# target directory already exists
			# this means today a backup was already executed
			lastback=$(ls -rd $dst/2* 2>/dev/null | head -2 | tail -1)
			if [ "$currback" == "$lastback" ] ; then
				# No other directory found
				# So we have only one directory, thus use Initial mode!
				lastback=""
			fi
		fi

		if [ "$lastback" == "" ]; then
			histparm=""
			printf "Backing up %s in history mode to %s (Initial Backup)\n" \
				"$src" "$currback"
		else
			histparm="--link-dest=$lastback"
			printf "Backing up %s in history mode to %s (based on %s)\n" \
				"$src" "$currback" "$lastback"
		fi
	elif [ $rebase -eq 1 ] ; then
		currback="$src.rsync-rebase.tmp"
		histparm="--link-dest=$dst --link-dest=$src"
		printf "Rebasing %s onto %s\n" "$src" "$dst"
	else
		currback="$dst"
		printf "Backing up %s to %s\n" "$src" "$currback"
	fi

	if [[ "$dst" == *":"* ]] ; then
		if [ $debug -eq 1 ]; then
			printf "Dest Directory not created, its on another computer.\n"
		fi
	elif [ ! -d "$currback" ]; then
		mkdir -p "$currback"
		if [ $? -eq 0 ] ; then
			if [ $debug -eq 1 ]; then
				printf "Created Dest Directory %s\n" "$curback"
			fi
		else
			printf "Error creating Dest Directory %s\n" "$currback"
			exit -7
		fi
	fi

	if [ $debug -eq 1 ]; then
		opt="$opt --progress"
	fi

	# NB: source directory is given with a trailing slash.
	# This way rsync will not create a directory of same name as source
	# in the destination folder but sync all files inside source directory
	# into the target directory
	local start_date="$(date -u +"%s")"
	if [ $debug -eq 1 ]; then
		printf "Executing rsync %s %s %s %s %s/ %s\n" "$opt" "$histparm" "$prm" "$src" "$currback"
	fi
	rsync $opt $histparm $prm $src/ $currback
	local rsync_rc="$?"

	local diff_date=$(( $(date -u +"%s") - $start_date ))
	local elapsed=$(date +%H:%M:%S -u -d @"$diff_date")
	if [ $rebase -ne 1 ] ; then
		if [ $rsync_rc -eq 0 ] ; then
			printf "Backup of %s completed (%s).\n" "$src" "$elapsed"
		else
			printf "Backup of %s ended in error. RSync RC=%d (%s).\n" \
				"$src" "$rsync_rc" "$elapsed"
		fi
	else
		if [ $rsync_rc -eq 0 ] ; then
			[ $debug -eq 1 ] && printf "Removing original Src $src and renaming rebased copy.\n"
			rm -rf $src &&
			mv $currback $src
			rsync_rc="$?"
		fi
		if [ $rsync_rc -eq 0 ] ; then
			printf "Rebase of %s completed (%s).\n" "$src" "$elapsed"
		else
			printf "Rebase of %s ended in error. RSync RC=%d (%s).\n" \
				"$src" "$rsync_rc" "$elapsed"
			rm -rf $currback
		fi
	fi

	# If we want a log of to be deleted files, we do it this way:
	# execute rsync in dry mode to list the files
	if [ $inetlog -eq 1 ] ; then
		printf "Writing deleted filelist of %s to %s\n" "$src" "$logfile"

		# create directory for LogFile if it does not exist
		if [ ! -d $(dirname "$logfile") ]; then
			mkdir -p "$(dirname "$logfile")"
		fi

		if [ $debug -eq 1 ]; then
			printf "Executing rsync %s %s %s %s/ %s\n" \
				"$prm" "$optlog3" "$src" "$currback"
		fi
		rsync $prm $optlog3 $src/ $currback |\
			sed -n 's/^deleting //p' >$logfile
	fi

}

function backup_rebase {
	if [ x"$DEBUG" == x1 ] ; then
		printf "DEBUG: %s %s\n" "$FUNCNAME" "$*"
	fi

	if [ $# -le 1 ] ; then
		printf "too less arguments. Minimum 2 expected.\n"
		return 1
	fi

	while [ $# -gt 1 ] ; do
		base=$(realpath $1) &&
		dest=$(realpath $2) &&
		backup_rsync --rebase "$dest" "$base" \
		|| return 1
		shift
	done

	return 0
}

function backup_ducnt {
	if [ x"$DEBUG" == x1 ] ; then
		printf "DEBUG: %s %s\n" "$FUNCNAME" "$*"
	fi

	du -sh "$@" |
	while read size dir ; do
		printf "%s\t%s\t%s\n" \
			"$size" \
			"$(ls -R $dir | wc -l)" \
			"$dir"
	done
}

function backup_rsync_print {
	if [ x"$DEBUG" == x1 ] ; then
		printf "DEBUG: %s %s\n" "$FUNCNAME" "$*"
	fi

	# check: Parameter must be 3!
	if [ $# -ne 3 ]; then
		printf "Error: wrong number or arguments (%d given, =3 expected)", "$#"
		exit -1
	fi

	local src="${2%/}"
	local dst="${3%/}"
	local log="$1"

	# if [ ! -d "$dst" ] ; then
	#	printf "Error: Dest Directory %s does not exist or no directory.\n" \
	#		"$dst"
	#	exit -2
	# fi

	if [ ! -f "$log" ] ; then
		printf "Error: Logfile %s does not exist.\n" "$log"
		exit -3
	fi

	if [ -s "$log" ]; then
		printf "%s has deleted files. you may want to use\n" "$src"
		printf "xargs -d \x5c\x5cn -a %s -I _ rm -d \"%s/_\"\n" "$log" "$dst"
		printf "to delete the files on the internet storage. Filelist: \n"
		cat $log
	fi
}
