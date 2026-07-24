#!/bin/bash
# gnuworld container entrypoint: ensure TLS material exists, then drop to gnuworld.
set -euo pipefail

CERT_DIR="${GNUWORLD_CERT_DIR:-/gnuworld/etc/certs}"
BASENAME="${GNUWORLD_CERT_BASENAME:-channels}"
TLS_CN="${GNUWORLD_TLS_CN:-channels.undernet.org}"
CERT_FILE="${CERT_DIR}/${BASENAME}.pem"
KEY_FILE="${CERT_DIR}/${BASENAME}.key"

if [[ -d "${CERT_DIR}" ]]; then
  if [[ ! -s "${CERT_FILE}" || ! -s "${KEY_FILE}" ]]; then
    echo "gnuworld-entrypoint: generating self-signed TLS cert (${CERT_FILE})"
    openssl req -x509 -newkey rsa:2048 -nodes \
      -keyout "${KEY_FILE}" \
      -out "${CERT_FILE}" \
      -days 3650 \
      -subj "/CN=${TLS_CN}" \
      -addext "subjectAltName=DNS:${TLS_CN},DNS:localhost,IP:127.0.0.1"
    chmod 644 "${CERT_FILE}" "${KEY_FILE}"
    chown gnuworld:gnuworld "${CERT_FILE}" "${KEY_FILE}" || true
  fi
fi

cd /gnuworld/bin
exec runuser -u gnuworld -- ./gnuworld -c -f /gnuworld/etc/gnuworld.conf "$@"
