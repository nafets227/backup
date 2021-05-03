# nafets227/backup CHANGELOG

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

