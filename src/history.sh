#!/bin/bash
#
# (C) 2021 Stefan Schallenberg
# 
# History mode for Backup
#
# How it works:
#     When backuping up in history mode we create a new subdirectory
#     YYYY/MM/DD.in-progress if it does not yet exist. Then we hard-link
#     all files from the previous backup there. After that the
#     type-specific backup procedure is run and will overwrite or delete
#     the files. If it does not, because the file is still present and
#     unchanged in the source, the hard link will remain. After successful
#     Backup, YYYY/MM/YY.in-progress is renamed to YYYY/MM/DD.
#     Only compliant directories are considered as previous backup, 
#     exluding .in-progress dirs.

##### Initialise history backup ##############################################
function backup_inithist {
	# Parm:
	#     - backup destination (without YYYY/mm/dd)
	#     - backup date in format of YYYY/mm/dd
	# Output: Directory name of the prepared directory
	#     (appending .in-progressXX to "backup dest/backup date" if needed)
	local currback lastback

	local bck_dst="$1"
	local bck_histdate="$2"

	if [[ "$bck_dst" == *":"* ]] ; then
		printf "Error: cannot backup to remote %s in history mode\n" \
			"$bck_dst" >&2
		return 1
	fi

	currback="$bck_dst/$bck_histdate"
	lastback=$(backup_findlasthist "$bck_dst") || return 1

	if [ -z "$lastback" ]; then
		printf "Backing up in history mode to %s (Initial Backup)\n" "$currback" >&2
		if [ -e "$currback.in-progress" ] ; then
			rm -rf "$currback.in-progress" || return 1
		fi
		printf "%s" "$currback.in-progress"
		return 0
	elif [[ "$lastback" > "$currback" ]] ; then
		printf "Error: Newer Backup %s found for %s\n" \
			"$lastback" "$currback" >&2
		return 1
	elif [ "$lastback" == "$currback" ] ; then
		printf "Backing up in history mode to %s (Update existing Backup)\n" \
			"$currback" >&2
		printf "%s" "$currback"
		return 0
	else
		printf "Initialising history mode for %s based on %s ... \n" \
			"$currback.in-progress" "$lastback" >&2

		if [ -e "$currback.in-progress" ] ; then
			rm -rf "$currback.in-progress" || return 1
		fi

		mkdir -p "$currback.in-progress" &&
		rsync -aH \
			"--link-dest=$lastback" \
			"$lastback/" \
			"$currback.in-progress" \
		|| return 1

		printf "Finished initialising history mode for %s based on %s\n" \
			"$currback.in-progress" "$lastback" >&2

		printf "%s" "$currback.in-progress"
		return 0
	fi

	return 99 # should never reach this.
}

##### Find last history backup ###############################################
function backup_findlasthist {
	# Parm:
	#     backup destination, must be local, without YYYY/mm/dd
	# Output:
	#     Directory of last backup, "" if not found
	local bck_dst="$1"

	local dirs_year dir_year dirs_month dir_month dirs_day dir_day
	local IFS=$'\n'

	if [ -z "$bck_dst" ] ; then
		printf "Internal Error: Empty Param\n" >&2
		return 1
	fi

	#----- check year --------------------------------------------------------
	dirs_year=$(ls -1rd $bck_dst/2* 2>/dev/null) # ignore not-found error

	for dir_year in $dirs_year ; do
		if [[ ! "$dir_year" =~ /[0-9]{4}$ ]] ; then
			printf "Warning: Ignoring Invalid year-dir-format in '%s'\n" \
				"$dir_year" >&2
			continue
		fi

		dirs_month=$(ls -1rd $dir_year/* 2>/dev/null) # ignore not-found error
		for dir_month in $dirs_month ; do
			if [[ ! "$dir_month" =~ /[0-9]{2}$ ]] ; then
				printf "Warning: Ignoring Invalid month-dir-format in '%s'\n" \
					"$dir_month" >&2
				continue
			fi

			# month is valid -> search for backups in it.
			# if not found continue with next month
			dirs_day=$(ls -1rd $dir_month/* 2>/dev/null) # ignore not-found error
			for dir_day in $dirs_day ; do
				if [[ ! "$dir_day" =~ /[0-9]{2}$ ]] ; then
					printf "Warning: Ignoring Invalid day-dir-format in '%s'\n" \
						"$dir_day" >&2
					continue
				fi

				# day is valid -> use it as last backup!
				printf "%s" "$dir_day"
				return 0
			done
		done
	done

	# no previous backup found -> return blank
	printf ""
	return 0
}
