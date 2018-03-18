# Dockerfile for backup
#
# Backup solution in Docker leveraging on rsync
#
# (C) 2017 Stefan Schallenberg

FROM alpine:3.6

RUN apk add --no-cache \
	bash \
	mysql-client \
	offlineimap \
	rsync

# maybe include gigasync
# https://github.com/noordawod/gigasync
# to speedup rsync

ADD backup /backup/backup
ADD backup_main /backup_main
ADD backup.d /usr/lib/backup

ENTRYPOINT ["/backup_main"]