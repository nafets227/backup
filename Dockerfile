# Dockerfile for backup
#
# Backup solution in Docker leveraging on rsync
#
# (C) 2017 Stefan Schallenberg

FROM alpine:3.6

RUN \
	apk update && \
	apk add --no-cache \
		bash \
		ca-certificates \
		mysql-client \
		offlineimap \
		rsync \
		&& \
	rm -rf /var/cache/apk/*

# maybe include gigasync
# https://github.com/noordawod/gigasync
# to speedup rsync

ADD backup-error /backup/backup
ADD backup-sample /backup/backup-sample
ADD backup.d /usr/lib/nafets227.backup
ADD src/backup_main /usr/lib/nafets227.backup/backup_main

ENTRYPOINT ["/usr/lib/nafets227.backup/backup_main"]
