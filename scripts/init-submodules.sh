#!/usr/bin/env bash
# Initialize selected git submodules.
#
# Usage:
#   ./scripts/init-submodules.sh           # all
#   ./scripts/init-submodules.sh all
#   ./scripts/init-submodules.sh irc       # ircu2 + gnuworld
#   ./scripts/init-submodules.sh web       # cservice-web + cservice-api
#   ./scripts/init-submodules.sh ircu2 gnuworld cservice-api
set -euo pipefail

cd "$(dirname "$0")/.."

expand_group() {
  case "$1" in
    all) echo ircu2 gnuworld iauthd-c cservice-web cservice-api ;;
    irc) echo ircu2 gnuworld iauthd-c ;;
    web) echo cservice-web cservice-api ;;
    *) echo "$1" ;;
  esac
}

if [[ $# -eq 0 ]]; then
  set -- all
fi

paths=()
for arg in "$@"; do
  # shellcheck disable=SC2207
  paths+=($(expand_group "$arg"))
done

# Deduplicate while preserving order
unique=()
for p in "${paths[@]}"; do
  skip=
  for u in "${unique[@]+"${unique[@]}"}"; do
    if [[ "$u" == "$p" ]]; then
      skip=1
      break
    fi
  done
  if [[ -z "$skip" ]]; then
    unique+=("$p")
  fi
done

echo "Initializing submodules: ${unique[*]}"
git submodule update --init -- "${unique[@]}"
