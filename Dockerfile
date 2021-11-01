# Dockerfile for backup
#
# Backup solution in Docker leveraging on rsync
#
# (C) 2017-2021 Stefan Schallenberg
FROM rclone/rclone:1.57.0 AS rclone
FROM alpine:3.6

RUN \
	apk update && \
	apk add --no-cache \
		bash \
		ca-certificates \
		mysql-client \
		offlineimap \
		openssh-client \
		rsync \
		&& \
	rm -rf /var/cache/apk/*

COPY --from=rclone /usr/local/bin/rclone /usr/local/bin/rclone

# maybe include gigasync
# https://github.com/noordawod/gigasync
# to speedup rsync

ADD backup-error /backup/backup
ADD backup-sample /backup/backup-sample
ADD backup.d /usr/lib/nafets227.backup
ADD src /usr/lib/nafets227.backup

ENTRYPOINT ["/usr/lib/nafets227.backup/backup_main"]
