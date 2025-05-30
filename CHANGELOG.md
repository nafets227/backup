# nafets227/backup CHANGELOG

## 0.9 (2025-03-04) Incompatible

Move to non-root container

see README.md for more details on how to specify
user "backupuser" with UID 41598.

## 0.8.2 (2025-03-02)

- alpine 3.21.3
- rclone 1.69.1
- offlineimap3 07f8d72
- CI: CodeCheck with SuperLinter
- remove Build-dependency to nafets227/util (copy the one file we need)
- removed dead code for samba, its no longer on our todo list

## 0.8.1 (2022-12-18)

- fix compatibility for backup type "rclone"

## 0.8 (2022-12-15)

- add new backup type file2rclone to backup local files onto cloud
- rename backup type rclone to rclone2file, making clear it
  downloads files from the cloud to a local directory.
- deprecate backup typ rclone, that is replaced by rclone2file.
  It will be removed in future versions.

## 0.7.1 (2022-12-14)

- improve CI by using GitHub Actions also for testing
- BREAKING CHANGE: focus on ghcr.io registry, stop updating docker hub
  (docker.io/nafets227/backup)

## 0.7. (2022-11-26)

- fix reusing .in-progress (#28)
- retry imap to workaround uid validity issue
- improve logging to list each backup
- alpine 3.17.0
- rclone 1.60.1

## 0.6.2 (2022-06-04)

- fix Email Alerts if backup fails

## 0.6.1 (2022-06-03)

- Log Email Alerts
- fix reuse in-progress backups with remote execution

## 0.6 (2022-06-02)

- Send Alert Emails with backup status (#12)
- reuse in-progress backups if --histkeep parm is set (#8)
- logg stats every minute in rclone (#11)
- Improve Logging (#9)
- fix an issue with rclone update in history mode (#7)
- converge to DEBUG (eliminateing debug) (#1)
- alpine 3.16.0
- rclone 1.58.1

## 0.5.4 (2022-02-08)

- bump to alpine 3.15.0

## 0.5.3 (2021-11-17)

- Allow custom options in rclone

## 0.5.2 (2021-11-13)

- backpropagate secret files only if modified
- bump from alpine 3.14.2 to alpine 3.14.3
- improve tests

## 0.5.1 (2021-11-06)

- backpropagate secret files (can be modified with rclone)
- update to offlineimap3 based on python3
- bump from alpine 3.6 to alpine 3.14.2
- Improve tests

## 0.5 (2021-11-01)

- Support Cloud backup leveraging rclone

## 0.4.2 (2021-06-03)

- use tempdir on remote. Previously used fix path /usr/lib/nafets227.backup
  may not be writeable, especially for non-admin users.

## 0.4.1 (2021-06-03)

- Fix Param handling after "--" for rsync params (backup type file)

## 0.4 (2021-05-21)

- File backup
- Small fixes
- Improve tests and code quality

## 0.3 (2021-05-03)

- History Mode

## 0.2.3 (2021-04-26)

- Adopt to new kubectl version (MySQL - currently unused)
- test: MAIL_ADR to point to a password file instead of containing the
  password itself
- Documentation Updates

## 0.2.2 (2020-09-28)

- Enhance Tracing on IMAP error (print offlineimap config)

## 0.2.1 (2020-07-27)

- Removed Default location for Secrets
- Bugfix dst-secret that has been ignored
- Remove default location of complex script (was /backup/backup)

## 0.2 (2020-07-26)

- Implement Secrets (INCOMPATIBLE CHANGE)
- No longer Support Password parameter in IMAP. Replaced by Secret.
- renamed Target to Destination in Doku
- make tests run on macOS
- Stability enhancements

## 0.1.1 (2020-07-17)

- Improve Logging for remote execution
- licensed under GPLv3

## 0.1 (2020-07-12)

- Support Imap Backup to local and remote Storage
