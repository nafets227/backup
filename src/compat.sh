#!/bin/bash
#
# compatibility layer to old scripts in backup.d
#
# (C) 2020 Stefan Schallenberg

function backup2_imap {
	if [ "$#" -lt 4 ] ; then
                printf "Error in custom config script. "
                printf "Calling backup imap with parms:\n\t%s\n"
                        "$*"
                return 1
        fi
		
        local bckimap_src="$1"
        local bckimap_dst="$2"
	local bckimap_srv="$3"
	local bckimap_pw="$4"

	backup_imap "$bckimap_src" "$bckimap_pw" "$bckimap_srv" "$backimp_dst"

}
