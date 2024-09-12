# Dockerfile for backup
#
# Backup solution in Docker leveraging on rsync
#
# (C) 2017-2021 Stefan Schallenberg

#checkov:skip=CKV_DOCKER_3: using root intentionally
#checkov:skip=CKV_DOCKER_2: HEALTHCHECK should be in kubernetes
# hadolint global ignore=DL3018,SC1091

FROM rclone/rclone:1.68.0 AS rclone

FROM alpine:3.20.2 AS offlineimap3
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
	sed -i 's:^.*portalocker.*$:setuptools:' requirements.txt && \
	sed -i "s:, 'portalocker\[cygwin\]'::" setup.py && \
	sed -i "s:, 'gssapi\[kerberos\]':, 'gssapi':" setup.py && \
	sed -i 's:from distutils.core :from setuptools :' setup.py && \
	pip install --no-cache-dir -r requirements.txt && \
	python3 setup.py install

FROM alpine:3.20.2

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

COPY backup-error /backup/backup
COPY backup-sample /backup/backup-sample
COPY backup.d /usr/lib/nafets227.backup
COPY src /usr/lib/nafets227.backup

ENTRYPOINT ["/usr/lib/nafets227.backup/backup_main"]
