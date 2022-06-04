# nafets227/backup CHANGELOG

## 0.6.2 (2022-06-04)
* fix Email Alerts if backup fails

## 0.6.1 (2022-06-03)
* Log Email Alerts
* fix reuse in-progress backups with remote execution

## 0.6 (2022-06-02)
* Send Alert Emails with backup status (#12)
* reuse in-progress backups if --histkeep parm is set (#8)
* logg stats every minute in rclone (#11)
* Improve Logging (#9)
* fix an issue with rclone update in history mode (#7)
* converge to DEBUG (eliminateing debug) (#1)
* alpine 3.16.0
* rclone 1.58.1

## 0.5.4 (2022-02-08)
* bump to alpine 3.15.0

## 0.5.3 (2021-11-17)
* Allow custom options in rclone

## 0.5.2 (2021-11-13)
* backpropagate secret files only if modified
* bump from alpine 3.14.2 to alpine 3.14.3
* improve tests

## 0.5.1 (2021-11-06)
* backpropagate secret files (can be modified with rclone)
* update to offlineimap3 based on python3
* bump from alpine 3.6 to alpine 3.14.2
* Improve tests

## 0.5 (2021-11-01)
* Support Cloud backup leveraging rclone

## 0.4.2 (2021-06-03)
* use tempdir on remote. Previously used fix path /usr/lib/nafets227.backup
  may not be writeable, especially for non-admin users.

## 0.4.1 (2021-06-03)
* Fix Param handling after "--" for rsync params (backup type file)
## 0.4 (2021-05-21)
* File backup
* Small fixes
* Improve tests and code quality

## 0.3 (2021-05-03)
* History Mode

## 0.2.3 (2021-04-26)
* Adopt to new kubectl version (mysql - currently unused)
* test: MAIL_ADR to point to a password file instead of containing the
  password itself
* Documentation Updates (CHANGELOG, README)

## 0.2.2 (2020-09-28)
* Enhance Tracing on IMAP error (print offlineimap config)

## 0.2.1 (2020-07-27)
* Removed Default location for Secrets
* Bugfix dst-secret that has been ignored
* Remove default location of complex script (was /backup/backup)

## 0.2 (2020-07-26)
* Implement Secrets (INCOMPATIBLE CHANGE)
* No longer Support Password parameter in IMAP. Replaced by Secret.
* renamed Target to Destination in Doku
* make tests run on MacOS
* Stability enhancements

## 0.1.1 (2020-07-17)
* Improve Logging for remote execution
* licensed under GPLv3

## 0.1 (2020-07-12)
* Support Imap Backup to local and remote Storage

