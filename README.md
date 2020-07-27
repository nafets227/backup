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
  - mount this script e.g. on /backup into container
  - give ". <scriptname>" as parameter to the container

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
Each remote system needs a Secret for Authentication and authorisation. Typical form of Secrets are public keys or passwords. If needed, Secrets can be defined with the --srcsecret or --dstsecret parameter.
Starting from version 0.2.1 no Defaults are applied.

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

# Hacking #
If you want to develop and test on MacOS, you need:
  - brew install offlineimap jq bash
  - activated local ssh server
  - trust your own ssh key (e.g. ~/.ssh/id_rsa.pub must be in authorized_keys)
  - tested with docker desktop for Mac
start with running test/test to verify your environment

# Reference #
[Source](https://github.com/nafets227/backup)

Copyright (C) 2017-2020 Stefan Schallenberg
License: @TODO define license

Leveraging on 
  - [Rsync](https://rsync.samba.org/)
  - [Offlineimap](https://www.offlineimap.org/)

[1]: backup-sample
