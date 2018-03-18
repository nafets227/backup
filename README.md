# backup #
Container based implementation of backup. Features:
  - rsync to target system
  - historize data
  - requires file-sourced to be mounted (NFS possible)
  - can backup IMAP accounts
  - can backup mysql databases
  - can backup Samba configuration
  - Plugin system for other types of data

# Targets #
  - --local copy data to local disk that is mounted in the container on /backup.local
  - --cloud copy data to cloud location. Cloud location must support rsync protocol, it it indicated by the
     environment variable CLOUD_URL, CLOUD_USER and CLOUD_AUTH
     @TODO describe how env variables work.

# Sources #
backup supports currently the following sources:
  - Filesystem
  - MySql or MariaDB database
  - IMAP

# How to use #
1) Create your own custom script that has the configuration
2) mount this scipt on /backup/backup into container

# Environmetn Parameters #
DEBUG [default: 0]

# Future Plans #
@TODO Find a way to improve sync to cloud when files / directories have beend moved.
It would be fantastic if we can reuse files that are already present in the backup.
see https://lincolnloop.com/blog/detecting-file-moves-renames-rsync/ as input

# Reference #
Source https://github.com/nafets227/backup
Copyright (C) 2017 Stefan Schallenberg
License: @TODO define license
