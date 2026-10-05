#!/bin/bash
# Incremental in-image build helper for ircu2 / gnuworld Dockerfiles.
# Keeps a BuildKit cache of the work tree + ccache so code edits only
# recompile what make decides is stale (skips autogen/configure when possible).
set -euo pipefail

: "${SRC_RO:?SRC_RO must point at the read-only source bind}"
: "${WORK:?WORK must point at the cached work directory}"
: "${CONFIGURE_ARGS:?CONFIGURE_ARGS must be set (arguments to ./configure)}"

export CCACHE_DIR="${CCACHE_DIR:-/root/.ccache}"
if [[ -d /usr/lib/ccache ]]; then
  export PATH="/usr/lib/ccache:${PATH}"
fi

mkdir -p "$WORK" "$CCACHE_DIR"

# Sync sources into the cached workdir without --delete so object files
# from prior container builds survive. Never import host configure/make
# outputs (those often carry a host --prefix and break make install).
# '/config.h' is anchored to the tree root on purpose: ircu2 generates its
# config.h there, while iauthd-c keeps a real source file at src/config.h.
rsync -a \
  --exclude '.git/' \
  --exclude 'autom4te.cache/' \
  --exclude '.libs/' \
  --exclude '.deps/' \
  --exclude '*.o' \
  --exclude '*.lo' \
  --exclude '*.la' \
  --exclude '*.a' \
  --exclude '*.so' \
  --exclude '*.so.*' \
  --exclude 'config.status' \
  --exclude 'config.log' \
  --exclude 'config.cache' \
  --exclude '/config.h' \
  --exclude 'include/setup.h' \
  --exclude 'libtool' \
  --exclude 'Makefile' \
  --exclude 'stamp-h1' \
  --exclude '.docker-configure-args' \
  "${SRC_RO}/" "${WORK}/"

cd "$WORK"

need_autogen=0
if [[ ! -x configure ]]; then
  need_autogen=1
elif [[ -f configure.ac && configure.ac -nt configure ]]; then
  need_autogen=1
elif [[ -f Makefile.am && -f Makefile.in && Makefile.am -nt Makefile.in ]]; then
  need_autogen=1
fi

if [[ "$need_autogen" -eq 1 ]]; then
  if [[ -x ./autogen.sh ]]; then
    echo "==> Running ./autogen.sh (configure inputs changed or missing)"
    ./autogen.sh
  else
    echo "==> Running autoreconf -Wall -i (configure inputs changed or missing)"
    autoreconf -Wall -i
  fi
else
  echo "==> Skipping autogen (configure is up to date)"
fi

args_file="${WORK}/.docker-configure-args"
need_configure=0
if [[ ! -f config.status ]]; then
  need_configure=1
elif [[ configure -nt config.status ]]; then
  need_configure=1
elif [[ ! -f "$args_file" ]] || [[ "$(cat "$args_file")" != "$CONFIGURE_ARGS" ]]; then
  need_configure=1
fi

if [[ "$need_configure" -eq 1 ]]; then
  echo "==> Running ./configure ${CONFIGURE_ARGS}"
  # CONFIGURE_ARGS is a trusted Dockerfile-provided string (may include $(pkgconf ...)).
  eval "./configure ${CONFIGURE_ARGS}"
  printf '%s\n' "$CONFIGURE_ARGS" > "$args_file"
else
  echo "==> Skipping configure (flags and config.status are up to date)"
fi

echo "==> make -j$(nproc)"
make -j"$(nproc)"
echo "==> make install"
make install

if [[ -n "${POST_INSTALL:-}" ]]; then
  eval "$POST_INSTALL"
fi

echo "==> ccache stats"
ccache -s 2>/dev/null || true
