# Dockerfile for backup
#
# Backup solution in Docker leveraging on rsync
#
# (C) 2017-2021 Stefan Schallenberg

#checkov:skip=CKV_DOCKER_3: using root intentionally
#checkov:skip=CKV_DOCKER_2: HEALTHCHECK should be in kubernetes
# hadolint global ignore=DL3018

FROM rclone/rclone:1.75.1 AS rclone

FROM alpine:3.24.1

RUN \
	apk update && \
	apk add --no-cache \
		bash \
		curl \
		ca-certificates \
		jq \
		krb5 \
		mysql-client \
		openssh-client \
		py3-pip \
		rsync \
		s-nail \
		&& \
	rm -rf /var/cache/apk/*

COPY requirements.txt /tmp/
RUN \
	pip install \
		--no-cache-dir --break-system-packages \
		-r /tmp/requirements.txt

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

COPY backup-error /backup/backup
COPY backup-sample /backup/backup-sample
COPY src /usr/lib/nafets227.backup/

# using UID 41598 is a random number
RUN adduser --uid 41598 --no-create-home --disabled-password backupuser
USER 41598

ENTRYPOINT ["/usr/lib/nafets227.backup/backup_main"]
