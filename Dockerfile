# Dockerfile for backup
#
# Backup solution in Docker leveraging on rsync
#
# (C) 2017-2021 Stefan Schallenberg
FROM rclone/rclone:1.65.2 AS rclone

FROM alpine:3.19.1 AS offlineimap3
# Copy and install offlineimap3 (replaces offlineimap)
# offlineimap3 is the successort of offlineimap,
# migrated from python2.x to python 3
COPY ./offlineimap3 /offlineimap3
RUN \
	apk add --no-cache curl gcc git krb5-dev python3-dev musl-dev py3-pip
RUN \
	set -x && \
	cd /offlineimap3 && \
	python3 -m venv /usr/local && \
	. /usr/local/bin/activate && \
	pip install -r requirements.txt && \
	python3 setup.py install

FROM alpine:3.19.1

RUN \
	apk update && \
	apk add --no-cache \
		bash \
		ca-certificates \
		krb5 \
		mysql-client \
		openssh-client \
		py3-pip \
		rsync \
		s-nail \
		&& \
	rm -rf /var/cache/apk/*

COPY --from=offlineimap3 /usr/local /usr/local/
COPY --from=rclone /usr/local/bin/rclone /usr/local/bin/rclone

# maybe include gigasync
# https://github.com/noordawod/gigasync
# to speedup rsync

ADD backup-error /backup/backup
ADD backup-sample /backup/backup-sample
ADD backup.d /usr/lib/nafets227.backup
ADD src /usr/lib/nafets227.backup

ENTRYPOINT ["/usr/lib/nafets227.backup/backup_main"]
