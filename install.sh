#!/bin/sh
# Install subd, the CLI that stands up and moves an on-prem Subduction
# deployment (vaalbara: specs/on-prem.md §9):
#
#   curl -fsSL https://releases.subd.app/install.sh | sh
#
# It fetches the subd beside the version production runs — the
# "latest" release on github.com/subduction-dev/releases — for this
# machine's architecture, checks it against that release's SHA256SUMS,
# and installs it as /usr/local/bin/subd. From then on `subd
# self-update` moves it, as the feed allows.
#
# Settings, all optional:
#   SUBD_VERSION      a release tag (subd-vYYYY.M.N) instead of the latest
#   SUBD_INSTALL_DIR  where subd goes (default /usr/local/bin)
#   SUBD_RELEASES_URL where releases are read (default the GitHub
#                     releases of subduction-dev/releases) — a mirror
set -eu

releases="${SUBD_RELEASES_URL:-https://github.com/subduction-dev/releases/releases}"
dir="${SUBD_INSTALL_DIR:-/usr/local/bin}"
version="${SUBD_VERSION:-latest}"

fail() {
  echo "subd install: $*" >&2
  exit 1
}

[ "$(uname -s)" = Linux ] || fail "subd runs on Linux; this is $(uname -s)"
case "$(uname -m)" in
  x86_64 | amd64) arch=x64 ;;
  aarch64 | arm64) arch=arm64 ;;
  *) fail "subd is built for x86_64 and aarch64; this is $(uname -m)" ;;
esac

# The binary carries Node, which needs glibc 2.28 or newer (RHEL 8,
# Ubuntu 20.04, Debian 10 and after); a musl system such as Alpine
# has none at all.
if command -v ldd > /dev/null 2>&1; then
  glibc="$(ldd --version 2>&1 | sed -n '1s/.* \([0-9][0-9]*\.[0-9][0-9]*\)$/\1/p')"
  if [ -z "$glibc" ]; then
    fail "subd needs glibc 2.28 or newer, and this system's C library is not glibc"
  fi
  major="${glibc%%.*}"
  minor="${glibc#*.}"
  if [ "$major" -lt 2 ] || { [ "$major" -eq 2 ] && [ "$minor" -lt 28 ]; }; then
    fail "subd needs glibc 2.28 or newer; this system has $glibc"
  fi
fi

if command -v curl > /dev/null 2>&1; then
  fetch() { curl -fsSL --retry 3 -o "$2" "$1"; }
elif command -v wget > /dev/null 2>&1; then
  fetch() { wget -q -O "$2" "$1"; }
else
  fail "needs curl or wget"
fi
command -v sha256sum > /dev/null 2>&1 || fail "needs sha256sum (coreutils)"

# "latest" is resolved to its tag ONCE, so the binary and its sums
# come from one release even if a promotion moves "latest" between the
# two fetches (Greptile on vaalbara#775): GitHub answers
# /releases/latest with a redirect to /releases/tag/<tag>. A mirror that
# does not, or a machine with wget alone, reads "latest" twice.
if [ "$version" = latest ] && command -v curl > /dev/null 2>&1; then
  resolved="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$releases/latest" 2> /dev/null || true)"
  case "$resolved" in
    */tag/?*) version="${resolved##*/tag/}" ;;
  esac
fi
if [ "$version" = latest ]; then
  from="$releases/latest/download"
else
  from="$releases/download/$version"
fi
asset="subd-linux-$arch.gz"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT INT TERM

echo "subd install: $from/$asset"
fetch "$from/$asset" "$work/$asset" || fail "could not fetch $from/$asset"
fetch "$from/SHA256SUMS" "$work/SHA256SUMS" || fail "could not fetch $from/SHA256SUMS"
expected="$(sed -n "s/^\([0-9a-f]\{64\}\)  $asset\$/\1/p" "$work/SHA256SUMS")"
[ -n "$expected" ] || fail "SHA256SUMS names no $asset"
actual="$(sha256sum "$work/$asset" | cut -d ' ' -f 1)"
[ "$actual" = "$expected" ] || fail "$asset is $actual, and SHA256SUMS says $expected — nothing installed"

gunzip "$work/$asset"
chmod 0755 "$work/subd-linux-$arch"
"$work/subd-linux-$arch" --version > /dev/null || fail "the binary does not run here"

if [ -w "$dir" ]; then
  mv "$work/subd-linux-$arch" "$dir/subd"
elif command -v sudo > /dev/null 2>&1; then
  echo "subd install: $dir needs root — asking sudo"
  sudo install -m 0755 "$work/subd-linux-$arch" "$dir/subd"
else
  fail "$dir is not writable, and there is no sudo — rerun as root, or set SUBD_INSTALL_DIR"
fi
echo "subd install: $("$dir/subd" --version) at $dir/subd"
echo "next: subd init — then the runbook we sent you"
