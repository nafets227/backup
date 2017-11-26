#!/bin/bash
#
# (C) 2015 Stefan Schallenberg
#

#Source all modules in install.d
for f in $(dirname $BASH_SOURCE)/backup.d/*.sh ; do
    echo "Loading Module $f"
    . $f
done

##### Now do somesthing else...
