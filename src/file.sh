#!/bin/sh
#
# Backup Files
#
# (C) 2013-2021 Stefan Schallenberg
#

# @TODO implement logging and rebase

##### backup2_file ###########################################################
# Interface to type_specific drivers:
#	backup2_<type>	function name
#	bck_src		Source URL
#	bck_dst		Destination URL
#	bck_src_secret	Source Secret Filename
#	bck_dst_secret	Destination Secret Filename
#	[ ...]		type specific futher options
function backup2_file {
    if [ "$#" -lt 4 ] ; then
        printf "Error in custom config script. "
        printf "Calling backup file with parms:\n\t%s\n" "$*"
        return 1
	elif [ x"$DEBUG" == x1 ] ; then
		printf "DEBUG: %s %s\n" "$FUNCNAME" "$*"
	fi

	#### NB: %/ removes a trailing slash if it exists
	local bckfile_src="${1%/}"
	local bckfile_dst="${2%/}"
	local bckfile_src_secret="$3"
	local bckfile_dst_secret="$4"
    shift 4

    local opt prm start_date rsync_rc diff_date elapsed sshopt

    if [ "$1" == "--inet" ] ; then
		opt="-rLt --size-only --partial"
		shift
    else
	    opt="-aHX --delete"
    fi

	if [ $# -gt 0 ]; then
		# we got additional rsync parameters
		prm="$*"
	else
		prm=""
	fi

	if		[[ "$bckfile_src" == *":"* ]] &&
			[[ "$bckfile_dst" == *":"* ]] ; then
		printf "Error: cannot copy from remote to remote - '%s' '%s'\n"
			"$bckfile_src" "$bckfile_dst"
		return 1
	fi

	if [[ "$bckfile_src" == *":"* ]] ; then
		if [ -z "$bckfile_src_secret" ] ; then
			printf "ERROR: No secret for remote src file given.\n"
			return 1
        elif [ x"$DEBUG" == x1 ] ; then
            printf "DEBUG: Source Directory not checked, its on another computer.\n"
        fi
	elif [ ! -d "$bckfile_src" ]; then
		printf "Error: Source Directory %s does not exist\n" "$bckfile_src"
		return 1
	else
		if [ x"$DEBUG" == x1 ] ; then
			printf "DEBUG: Source Directory OK.\n"
		fi
	fi

	if [[ "$bckfile_dst" == *":"* ]] ; then
		if [ -z "$bckfile_dst_secret" ] ; then
			printf "ERROR: No secret for remote dst file given.\n"
			return 1
        elif [ x"$DEBUG" == x1 ] ; then
            printf "DEBUG: Dest Directory not checked, its on another computer.\n"
        fi
	elif [ ! -d "$bckfile_dst" ]; then
		mkdir -p "$bckfile_dst" || return 1
		if [ x"$DEBUG" == x1 ] ; then
			printf "DEBUG: Dest Directory has been created.\n"
		fi
	else
		if [ x"$DEBUG" == x1 ] ; then
			printf "DEBUG: Dest Directory OK.\n"
		fi
	fi

	printf "Backing up Files %s to %s\n" "$bckfile_src" "$bckfile_dst"

	if	[[ "$bckfile_src" == *":"* ]] ; then
		sshopt="ssh -o StrictHostKeyChecking=no -i $bckfile_src_secret"
	elif [[ "$bckfile_dst" == *":"* ]] ; then
		sshopt="ssh -o StrictHostKeyChecking=no -i $bckfile_dst_secret"
	else
		sshopt="ssh"
	fi

	if [ x"$DEBUG" == x1 ] ; then
		opt="$opt --verbose --progress"
	fi

	# NB: source directory is given with a trailing slash.
	# This way rsync will not create a directory of same name as source
	# in the destination folder but sync all files inside source directory
	# into the target directory
#	start_date="$(date -u +"%s")" || return 1
	if [ x"$DEBUG" == x1 ] ; then
		printf "Executing rsync -e \"%s\" %s %s %s %s/ %s\n" \
            "$sshopt" "$opt" "$prm" "$bckfile_src" "$bckfile_dst"
	fi
	rsync -e "$sshopt" $opt $prm $bckfile_src/ $bckfile_dst
	rsync_rc="$?"

#	diff_date=$(( $(date -u +"%s") - $start_date )) || return 1
#	if [ "$diff_date" == "0" ] ; then
#		elapsed="00:00:00"
#	else
#		elapsed=$(date +%H:%M:%S -u -d @"$diff_date") || return 1
#	fi
    
    if [ $rsync_rc -eq 0 ] ; then
        printf "Backup of %s completed (%s).\n" "$bckfile_src" "$elapsed"
        return 0
    else
        printf "Backup of %s ended in error. RSync RC=%d (%s).\n" \
            "$bckfile_src" "$rsync_rc" "$elapsed"
        return 1
    fi

    return 99 # should never be reached
}
