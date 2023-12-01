# Dockerfile for backup
#
# Backup solution in Docker leveraging on rsync
#
# (C) 2017-2021 Stefan Schallenberg
FROM rclone/rclone:1.64.0 AS rclone
FROM alpine:3.18.5

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

COPY --from=rclone /usr/local/bin/rclone /usr/local/bin/rclone

# Download and install offlineimap3 (replaces offlineimap)
# offlineimap3 is the successort of offlineimap,
# migrated from python2.x to python 3
RUN \
	set -x && \
	DEVPACKAGES="curl gcc krb5-dev python3-dev musl-dev" && \
	apk add --no-cache $DEVPACKAGES && \
	mkdir /offlineimap3 && cd /offlineimap3 && \
	curl -L \
		-o offlineimap3.tgz \
		https://github.com/OfflineIMAP/offlineimap3/archive/refs/tags/v8.0.0.tar.gz && \
	tar xvfz offlineimap3.tgz && cd offlineimap3-* && \
	python3 -m pip install --upgrade pip && pip install -r requirements.txt && \
	python3 setup.py install && \
	cd && \
	rm -rf /offlineimap3 && \
	apk del $DEVPACKAGES && \
	rm -rf /var/cache/apk/*

# maybe include gigasync
# https://github.com/noordawod/gigasync
# to speedup rsync

ADD backup-error /backup/backup
ADD backup-sample /backup/backup-sample
ADD backup.d /usr/lib/nafets227.backup
ADD src /usr/lib/nafets227.backup

ENTRYPOINT ["/usr/lib/nafets227.backup/backup_main"]
