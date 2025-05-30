# Dockerfile for backup
#
# Backup solution in Docker leveraging on rsync
#
# (C) 2017-2021 Stefan Schallenberg

#checkov:skip=CKV_DOCKER_3: using root intentionally
#checkov:skip=CKV_DOCKER_2: HEALTHCHECK should be in kubernetes
# hadolint global ignore=DL3018,SC1091

FROM rclone/rclone:1.69.3 AS rclone

FROM alpine:3.22.0 AS offlineimap3
# Copy and install offlineimap3 (replaces offlineimap)
# offlineimap3 is the successort of offlineimap,
# migrated from python2.x to python 3
COPY ./offlineimap3 /offlineimap3
RUN \
	apk add --no-cache curl gcc git krb5-dev python3-dev musl-dev py3-pip
# ignoreing portalocker due to issues.
#     See https://github.com/OfflineIMAP/offlineimap3/issues/192
# patching offlineimap to Python 3.12 of Alping 3.20+:
#     replace distutils.core by setuptools

WORKDIR /offlineimap3
RUN \
	set -x && \
	python3 -m venv /usr/local && \
	. /usr/local/bin/activate && \
	pip install --no-cache-dir -r requirements.txt && \
	pip install --no-cache-dir setuptools==75.8.2 && \
	python3 setup.py install

FROM alpine:3.22.0

RUN \
	apk update && \
	apk add --no-cache \
		bash \
		curl \
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
COPY --from=rclone /usr/local/bin/rclone /usr/lib/nafets227.backup/

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN \
	RCLONE_VER=$( \
		/usr/lib/nafets227.backup/rclone --version \
		| sed -n 's/^rclone //p') && \
	RCLONE_BASEURL="https://downloads.rclone.org/$RCLONE_VER" && \
	curl -o /tmp/rclone.zip \
		"$RCLONE_BASEURL/rclone-$RCLONE_VER-osx-amd64.zip" && \
	unzip -p /tmp/rclone.zip "rclone-$RCLONE_VER-osx-amd64/rclone" \
		>/usr/lib/nafets227.backup/rclone.macos.amd64 && \
	curl -o /tmp/rclone.zip \
		"$RCLONE_BASEURL/rclone-$RCLONE_VER-osx-arm64.zip" && \
	unzip -p /tmp/rclone.zip "rclone-$RCLONE_VER-osx-arm64/rclone" \
		>/usr/lib/nafets227.backup/rclone.macos.arm64 && \
	chmod +x \
		/usr/lib/nafets227.backup/rclone \
		/usr/lib/nafets227.backup/rclone.macos.amd64 \
		/usr/lib/nafets227.backup/rclone.macos.arm64 && \
	rm /tmp/rclone.zip
SHELL ["/bin/sh", "-c"]

# maybe include gigasync
# https://github.com/noordawod/gigasync
# to speedup rsync

COPY backup-error /backup/backup
COPY backup-sample /backup/backup-sample
COPY src /usr/lib/nafets227.backup/

# using UID 41598 is a random number
RUN adduser --uid 41598 --no-create-home --disabled-password backupuser
USER 41598

ENTRYPOINT ["/usr/lib/nafets227.backup/backup_main"]
