#!/bin/sh
#
# Backup rclone
#
# (C) 2021 Stefan Schallenberg
#

##### backup2_rclone ###########################################################
# Interface to type_specific drivers:
#	backup2_<type>	function name
#	bck_src		rclone URL, as used with rclone sync (e.g. MyCloud:/)
#	bck_dst		Destination URL
#	bck_src_secret	Source Secret Filename
#	bck_dst_secret	Destination Secret Filename
function backup2_rclone {
        if [ "$#" -ne 4 ] ; then
                printf "Error in custom config script. "
                printf "Calling backup rclone with parms:\n\t%s\n" "$*"
                return 1
	elif [ x"$DEBUG" == x1 ] ; then
		printf "DEBUG: %s %s\n" "$FUNCNAME" "$*"
	fi

	local bckrclone_src="$1"
	local bckrclone_dst="$2"
	local bckrclone_src_secret="$3"
	local bckrclone_dst_secret="$4"

	local bckrclone_src_cloudname bckrclone_src_path &&
	bckrclone_src_cloudname="${bckrclone_src%%:*}" &&
	bckrclone_src_path=${bckrclone_src:$((${#bckrclone_src_cloudname} + 1))} &&
	true || return 1

	if [ -z "$bckrclone_src" ] ; then
		printf "Error. No rclone URL given.\n"
		return 1
	elif [ -z "$bckrclone_src_cloudname" ] ; then
		printf "Error. rclone Source URL \"%s\" has empty cloud (before :).\n" \
			"$bckrclone_src"
		return 1
	elif [ -z "$bckrclone_src_path" ] ; then
		printf "Error. rclone Source URL \"%s\" has empty path (after :).\n" \
			"$bckrclone_src"
		return 1
	elif [ -z "$bckrclone_src_secret" ] ; then
		printf "Error: No rclone Secret given.\n"
		return 1
	elif [ ! -f "$bckrclone_src_secret" ] ; then
		printf "Error: rclone Secret file \"%s\" does not exist.\n" \
			"$bckrclone_src_secret"
		return 1
	fi

	if [ ! -d "$bckrclone_dst" ] ; then
		mkdir -p "$bckrclone_dst" || return 1
	fi

	rclone \
		--config $bckrclone_src_secret \
		sync \
		$bckrclone_src \
		$bckrclone_dst &&
	rclone \
		--config $bckrclone_src_secret \
		rmdirs --leave-root \
		$bckrclone_dst &&
	rclone \
		--config $bckrclone_src_secret \
		sync --create-empty-src-dirs \
		$bckrclone_src \
		$bckrclone_dst

	rc=$?
	if [ $rc -ne 0 ] ; then
		printf "##### Error connecting to rclone %s. Config:\n" "$bckrclone_src"
		cat $bckrclone_src_secret
		printf "##### Enf od Config for rclone %s\n" "$bckrclone_src"
		return 1
	fi

	return 0
}
