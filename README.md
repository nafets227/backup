# Backup

Container based implementation of backup. Features:

- rsync to destination system
- can backup IMAP accounts
- Plugin system allows adding other types of data
- History Mode preserves deleted files or old versions optimizing space by
  using hard links

## Destinations

Destination can be anything that is reachable via rsync/SSH or a local disk
mounted in the container. Copying via internet is supported.

## History Mode

History mode safes the backup to a subdirectory YYYY/mm/dd based on the backup
date (today, unless --histdate is used). In order to save space, starting from
the second backup we are hard-linking to unchanged filed of previous backup.
With --histkeep also unsuccessful backups are reused in order to avoid
double-downloading.

## Sources

backup supports currently the following sources:

- IMAP
- File
- rclone

## How to use

### Easy use

Start a container and pass the parameters (see below) for one action to this
container. This way of usage is recommended for testing and small number data
storages.

### Complex configurations

- Create your own custom script
- This script can contain multiple backup actions. see [Example][1]
- mount this script e.g. on /backup into container
- give ". <scriptname>" as parameter to the container

This way of usage is recommended if you have a number of backup actions and
other complex setups.

## parameters defining a backup action

1. "backup" (fix)
2. Type (currently only "imap", "file" or "rclone2file" supported)
3. Source
4. Destination
5. global options
6. '--'
7. local options (specific to "type", see relevant section)

see also [Example][1].

## Global Options

- --runonsrc
  Prefer to run on the source side
- --runondst
  Prefer to run on destination side
- --local
  Run locally (=in the container) only
- --srcsecret
  Secret to access source system (password/ssh-key, depending on type)
- --dstsecret
  Secret to access destination system (password/ssh-key, depending on type)
- --hist
  Backup in History Mode (see separate section)
- --histdate <date>
  Backup in History Mode, using <date> instead of today. Not intended for
  production use, but mainly for testing
- --histraw <YYYY/mm/dd>
  Backup in History Mode, using fixed subdirectory as target. Only intended for
  internal use
- --histkeep
  Reuse backup data of unsuccessful backups. This is especially useful for
  rclone backups from cloud providers like Microsoft OneDrive.

## Environment Parameters

- DEBUG: 0 or 1, defaults to 0
- MAIL_TO: EMail recipients
  Recipient(s) of Alerting emails. If set, it also activates the alerting
  feature.
- MAIL_FROM: Email Sender
  sender of the Alerting emails
- MAIL_URL: Email Server
  where to deliver the Alerting emails like
  'smtp[s]://user:password@some.host:port'
- MAIL_HOSTNAME: hostname reported in SMTP HELO
  optionally give the hostname that we report to SMTP server in
  HELO command. Usefule if the SMTP server requires a FQDN. Defaults to
  hostname.

## UserID´s in this Non-root image

This image is using non-root user "backupuser" with UID 41598.
Using a diffferent non-root user is not supported (email wont work), so
if you need to specify the user for the container runtime
(e.g. in Kubernetes "runAsUser") you MUST use 41598.

## IMAP

Backups data from an IMAP Server using offlineimap. This is done in a delta
approach, so only modified Emails are downloaded whereas deleted EMails are
deleted on the file directory

### IMAP Global parameters

- Source - Logon user used to connect to the IMAP Server. Typically it
  contains the Email including the domain.
- Destination - Directory where to store the downloaded EMails. Optionally
  prefixed by Server name followed by a colon.
- Source Secret
  is the password to logon to the server \[mandatory\]
- Destination Secret
  is the password to connect to the target server \[optional\]

### IMAP local parameters

1. IMAP Server URL (e.g. imap.mydomain.xxx:143)
   \[mandatory\]

## File

Backups data from any server reachable via rsync and/or SSH. It is based on
rsync, so only modified files are copied (delta-approach). No more existing
files are deleted in the target.

### File Global paramaters

- Source - Directoy of Files to be backed up. Optionally prefixed by Server
  name followed by a colon
- Destination - Directory where to store the downloaded EMails. Optionally
  prefixed by Server name followed by a colon.
- Source Secret
  is the password to logon to the server \[optional\]
  mandatory if the Source is remote
- Destination Secret
  is the password to connect to the target server \[optional\]
  mandatory if the Destination is remote

## rclone2file

Backups data from various Clouds, leveraging [rclone](https://rclone.org/).

### rclone2file Global paramaters

- Source - Name of the cloud in rclone config
- Destination - Directory where to store the download.
  Optionally prefixed by Server name followed by a colon.
- Source Secret - rclone.conf file to be used

## file2rclone

Backups data from local to various Clouds, leveraging
[rclone](https://rclone.org/).

### file2rclone Global paramaters

- Source - Name of the cloud in rclone config
- Destination - Directory where to store the download.
  Optionally prefixed by Server name followed by a colon.
- Source Secret - rclone.conf file to be used

## Security (Secrets)

Each remote system needs a Secret for Authentication and authorisation.
Typical form of Secrets are public keys or passwords. If needed, Secrets can
be defined with the --srcsecret or --dstsecret parameter. Starting from
version 0.2.1 no Defaults are applied.

## Rebasing history backups

Rebasing a history backup in order to save space can be done. You need to start
rebasing on the first backup that introduced the files to be based on other data
and then rebase each of the existing backups up to the latest.
a sample command could be:

    rsync -v -aHX --delete --progress
    --link-dest=../../../../../user_home/2021/11/20
    --link-dest=../20 20/ 20.rsync-rebase.tmp

## Future Plans

Features planned in the future

- can backup MySQL databases
- can backup Samba configuration
- Find a way to improve sync to cloud when files / directories have
  been moved. It would be fantastic if we can reuse files that are
  already present in the backup.
  see <https://lincolnloop.com/blog/detecting-file-moves-renames-rsync/>

## Hacking

If you want to develop and test on macOS, you need:

- `brew install offlineimap jq bash rsync rclone`
- activated local SSH server
- trust your own SSH key (e.g. ~/.ssh/id_rsa.pub must be in authorized_keys)
- tested with Docker Desktop for Mac

To run tests in test subdirectory you need to have some test data available.
ATTENTION: Test data will be DELETED on every run, so make sure you don´t have
any data on it!

- IMAP Test Account

  Setup an IMAP Test Account and set Environment variables accordingly:
  - TESTIMAP_SRC
  - TESTIMAP_SECRET
  - TESTIMAP_URL

- rclone Test Cloud

  Setup a Test-Cloud (I use Microsoft OneDrive that is for free).
  Create an rclone.cfg and pass its filename in $TESTRCLONE_CONF and the Cloud
  config to be used in $TESTRCLONE_NAME.
  You may wan to use something like
  `rclone --config ./rclonf.conf config` to create the file.

- alert test settings

  Tests will use specified mailbox to write alert logs to and check if they
  are there. IMAP Test Account can be reused. Be aware that ALL Emails in this
  account will be deleted on every test run. See test/test for details.
  - TESTALERTMAIL_TO
  - TESTALERTMAIL_FROM
  - TESTALERTMAIL_URL
  - TESTALERTMAIL_HOSTNAME
  - TESTALERTMAIL_IMAPxxx

start with running test/test to verify your environment

### GitHub Actions setup

GitHub Actions are setup in this repository to test against a dummy OneDrive
(`<nafets227@nafets.de>`) and Mailbox (<`nafets227.backup.test@nafets.de>`).
Dependabot triggered pull requests (e.g. to update actions or Git subrepos)
automatically trigger a GitHub Action. However, dependatbot triggered actions
cannot access the "normal" action secrets in GitHub. In order to overcome this
limitations, relevant secrets have been copied into the special dependabot
area of secrets:

- GH_SECRETS_ADMIN_TOKEN hold the value of the token named
  `dependabot_ghaction_nafet227backup`. See
  [Token on GitHub](https://github.com/settings/personal-access-tokens/2796058)
  This is needed to let the action update RCLONE config after re-authentication.
- MAIL_PW holds the mail password of the dummy accounts
  `nafets227.backup.test@nafets.de`. This account has limited send-rate to
  reduce the risk of being used as spam sender in case anyone steals the
  secret.
- RCLONE_CONF holds the rclone config of the dummy OneDrive
  `nafets227@nafets.de`. It is updated after every run, since authentication
  needs to be re-evaluated according to oauth technology.

## Reference

[Source](https://github.com/nafets227/backup)

Copyright (C) 2017-2021 Stefan Schallenberg
License: GPLv3, see [LICENSE](LICENSE)

Leveraging on

- [Rsync](https://rsync.samba.org/)
- [Offlineimap](https://www.offlineimap.org/)
- [rclone](https://rclone.org/)

[1]: backup-sample
