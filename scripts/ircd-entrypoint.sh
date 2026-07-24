#!/bin/bash
# ircd container entrypoint: ensure this host's TLS material exists, then drop to ircd.
set -euo pipefail

CERT_DIR="${IRCD_CERT_DIR:-/ircd/etc/certs}"
BASENAME="${IRCD_CERT_BASENAME:-}"
TLS_CN="${IRCD_TLS_CN:-}"

# Only services that mount CERT_DIR generate certs; others start immediately.
if [[ -d "${CERT_DIR}" && -n "${BASENAME}" && -n "${TLS_CN}" ]]; then
  CERT_FILE="${CERT_DIR}/${BASENAME}.pem"
  KEY_FILE="${CERT_DIR}/${BASENAME}.key"
  if [[ ! -s "${CERT_FILE}" || ! -s "${KEY_FILE}" ]]; then
    echo "ircd-entrypoint: generating self-signed TLS cert (${CERT_FILE})"
    openssl req -x509 -newkey rsa:2048 -nodes \
      -keyout "${KEY_FILE}" \
      -out "${CERT_FILE}" \
      -days 3650 \
      -subj "/CN=${TLS_CN}" \
      -addext "subjectAltName=DNS:${TLS_CN},DNS:localhost,IP:127.0.0.1"
    chmod 644 "${CERT_FILE}" "${KEY_FILE}"
    chown ircd:ircd "${CERT_FILE}" "${KEY_FILE}" || true
  fi
fi

exec runuser -u ircd -- /ircd/bin/ircd -n "$@"
