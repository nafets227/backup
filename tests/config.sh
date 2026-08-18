#!/usr/bin/env bash
#
# Configuration for our tests
#
# (C) 2026 Stefan Schallenberg

# IMAP test account
: "${TESTIMAP_SRC:=nafets227.backup.test@nafets.de}"
: "${TESTIMAP_SECRET:=tests/mail.password}"
: "${TESTIMAP_URL:=nafets.de:143}"

# rclone test configuration
: "${TESTRCLONE_CONF:=tests/rclone.conf}"
: "${TESTRCLONE_NAME:=nafets227_nafets_de:/}"
: "${TESTRCLONE_RO_NAME:=nafets227_nafets_de_ro:/}"

# Alert mail configuration
: "${TESTALERTMAIL_FROM:=nafets227/backup CI <no-reply@nafets.de>}"
: "${TESTALERTMAIL_ADR:=nafets227.backup.test@nafets.de}"
: "${TESTALERTMAIL_URL:=nafets.de}"
: "${TESTALERTMAIL_USER:=nafets.de}"
: "${TESTALERTMAIL_SECRET:=tests/mail.password}"
: "${TESTALERTMAIL_IMAP_URL:=nafets.de:143}"
: "${TESTALERTMAIL_IMAP_SECRET:=tests/mail.password}"

export \
	TESTIMAP_SRC \
	TESTIMAP_SECRET \
	TESTIMAP_URL \
	TESTRCLONE_CONF \
	TESTRCLONE_NAME \
	TESTRCLONE_RO_NAME \
	TESTALERTMAIL_FROM \
	TESTALERTMAIL_ADR \
	TESTALERTMAIL_URL \
	TESTALERTMAIL_USER \
	TESTALERTMAIL_SECRET \
	TESTALERTMAIL_IMAP_URL \
	TESTALERTMAIL_IMAP_SECRET
