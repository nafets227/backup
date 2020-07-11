# backup #
Container based implementation of backup. Features:
  - rsync to target system
  - ssh to source system
  - historize data
  - can backup IMAP accounts
  - can backup mysql databases
  - can backup Samba configuration
  - other types of data can be added easily

# Targets #
Target can be anything that is reachable via ssh or a local disk mounten inthe container. Copying via internet is supported.

# Sources #
backup supports currently the following sources:
  - Filesystem
  - MySql or MariaDB database
  - IMAP

# How to use #
1) Create your own custom script that has the configuration
2) mount this script on /backup/backup into container

# Environmetn Parameters #
DEBUG [default: 0]

# Future Plans #
@TODO Find a way to improve sync to cloud when files / directories have beend moved.
It would be fantastic if we can reuse files that are already present in the backup.
see https://lincolnloop.com/blog/detecting-file-moves-renames-rsync/ as input

# Reference #
Source https://github.com/nafets227/backup
Copyright (C) 2017-2020 Stefan Schallenberg
License: @TODO define license

Leveraging on 
  - Rsync https://rsync.samba.org/
  - Offlineimap https://www.offlineimap.org/
