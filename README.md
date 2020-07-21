# Backup #
Container based implementation of backup. Features:
  - rsync to destination system
  - can backup IMAP accounts
  - Plugin system allows adding other types of data

# Destinations #
Destination can be anything that is reachable via rsync/ssh or a local disk mounted in the container. Copying via internet is supported.

# Sources #
backup supports currently the following sources:
  - IMAP

# How to use #
## Easy use 
Start a container and pass the parameters (see below) for one action to this container.  
This way of usage is recommended for testing and small number data storages.

## Complex configurations
  - Create your own custom script
  - This script can contain multiple backup actions. see [Example][1]
  - mount this script on /backup/backup into container

This way of usage is recommended if you have a number of backup actions and
other complex setups.

## parameters defining a backup action
  1. "backup" (fix)
  2. Type (currently only "imap" supported)
  3. Source
  4. Destination
  5. (IMAP) Server Url (e.g. imap.mydomain.xxx:143)

see also [Example][1].

## Environment Parameters #
  - DEBUG: 0 or 1, defaults to 0

## IMAP
IMAP Logon name must be the Email including the domain.

# Security (Secrets)
Each remote system needs a Secret for Authentication and authorisation. Typical form of Secrets are public keys or passwords. Secrets are searched in the following order:
  1. Paramter
     if the --srcsecret or --dstsecret parameters are set, they must contain a
     fully qualified pathname of the secret
  2. Default
     The default is to search in /backup/<partner>.<extension>.
     <partner> specifies the remote id (e.g. machinename or Emailname).
     Extension depends on the type (e.g. .password for IMAP,
     .id_rsa as SSH-key for rsync or remote execution).
  3. System Default
     only in case of SSH the system Default /root/.ssh/id_rsa is used.

# Future Plans #
Features planned in the future
  - can backup mysql databases
  - can backup Samba configuration
  - ssh to source system
  - historize data
  - Find a way to improve sync to cloud when files / directories have
    been moved. It would be fantastic if we can reuse files that are
    already present in the backup.
    see https://lincolnloop.com/blog/detecting-file-moves-renames-rsync/

# Reference #
[Source](https://github.com/nafets227/backup)

Copyright (C) 2017-2020 Stefan Schallenberg
License: @TODO define license

Leveraging on 
  - [Rsync](https://rsync.samba.org/)
  - [Offlineimap](https://www.offlineimap.org/)

[1]: backup-sample
