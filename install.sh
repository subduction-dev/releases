#!/bin/sh
# subd's install script moved to shelf.subd.app:
#
#   curl -fsSL https://shelf.subd.app/install.sh | sh
#
# This copy stays at the old address so a line printed before the move
# still works: it runs the shelf's script, which reads the same
# settings (SUBD_VERSION, SUBD_INSTALL_DIR, SUBD_RELEASES_URL) from the
# environment this one was given. A SUBD_RELEASES_URL set for this
# address named a GitHub-style releases page, the only layout it read,
# so it is read that way unless SUBD_RELEASES_LAYOUT says otherwise.
set -eu

if [ -n "${SUBD_RELEASES_URL:-}" ] && [ -z "${SUBD_RELEASES_LAYOUT:-}" ]; then
  SUBD_RELEASES_LAYOUT=github
  export SUBD_RELEASES_LAYOUT
fi

script="https://shelf.subd.app/install.sh"
if command -v curl > /dev/null 2>&1; then
  body="$(curl -fsSL --retry 3 "$script")"
elif command -v wget > /dev/null 2>&1; then
  body="$(wget -q -O - "$script")"
else
  echo "subd install: needs curl or wget" >&2
  exit 1
fi
printf '%s\n' "$body" | sh
