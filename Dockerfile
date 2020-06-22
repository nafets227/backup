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

ADD backup /backup/backup
ADD backup_main /backup_main
ADD backup.d /usr/lib/backup

ENTRYPOINT ["/backup_main"]
