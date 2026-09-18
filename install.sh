#!/usr/bin/env bash

# Rig installer — downloads the shell executable and manual.

set -euo pipefail

REPO=knowledgeislands/tools-rig
INSTALL_DIR=${RIG_INSTALL_DIR:-${HOME:?HOME is required}/.local/bin}
MAN_INSTALL_DIR=${RIG_MAN_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/man/man1}
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

say() {
  printf 'rig-install: %s\n' "$*"
}

die() {
  printf 'rig-install: error: %s\n' "$*" >&2
  exit 1
}

usage() {
  printf '%s\n' \
    'Usage: ./install.sh [vX.Y.Z|--link]' \
    '' \
    'Install the latest released Rig, pin an exact release, or link a local checkout.'
}

if [ "$#" -gt 1 ]; then
  usage >&2
  exit 2
fi

version_argument=
case "${1:-}" in
  '') mode='release' ;;
  --link) mode='link' ;;
  -h|--help)
    usage
    exit 0
    ;;
  *) mode='release'; version_argument=$1 ;;
esac

if [ -n "$version_argument" ] &&
  ! [[ "$version_argument" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'rig-install: error: version must match vX.Y.Z: %s\n' "$version_argument" >&2
  usage >&2
  exit 2
fi

if [ "$mode" = link ]; then
  source_bin=$SCRIPT_DIR/bin/rig
  source_man=$SCRIPT_DIR/man/rig.1
  [ -f "$source_bin" ] || die "missing $source_bin"
  [ -f "$source_man" ] || die "missing $source_man"
  mkdir -p "$INSTALL_DIR" "$MAN_INSTALL_DIR"
  ln -sfn "$source_bin" "$INSTALL_DIR/rig"
  ln -sfn "$source_man" "$MAN_INSTALL_DIR/rig.1"
  say "linked $INSTALL_DIR/rig"
  say "linked $MAN_INSTALL_DIR/rig.1"
  exit 0
fi

command -v curl >/dev/null 2>&1 || die 'curl is required to install a release'

ref=$version_argument
if [ -z "$ref" ]; then
  ref=${RIG_VERSION:-}
  if [ -n "$ref" ] && ! [[ "$ref" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'rig-install: error: RIG_VERSION must match vX.Y.Z: %s\n' "$ref" >&2
    usage >&2
    exit 2
  fi
fi

if [ -z "$ref" ]; then
  ref=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1) || true
  [ -n "$ref" ] || die 'latest release tag unavailable'
  [[ "$ref" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
    die "latest release tag is not an exact version: $ref"
fi

source_url=https://raw.githubusercontent.com/$REPO/$ref/bin/rig
manual_url=https://raw.githubusercontent.com/$REPO/$ref/man/rig.1
temp_bin=$(mktemp)
temp_man=$(mktemp)
trap 'rm -f "$temp_bin" "$temp_man"' EXIT

say "staging Rig ($ref)"
curl -fsSL "$source_url" -o "$temp_bin" || die "download failed: $source_url"
curl -fsSL "$manual_url" -o "$temp_man" || die "download failed: $manual_url"
head -n 1 "$temp_bin" | grep -q '^#!/usr/bin/env bash$' || die 'downloaded file is not the Rig executable'
head -n 1 "$temp_man" | grep -q '^\.TH RIG 1' || die 'downloaded file is not the Rig manual'

mkdir -p "$INSTALL_DIR" "$MAN_INSTALL_DIR"
install -m 0755 "$temp_bin" "$INSTALL_DIR/rig"
say "installed $INSTALL_DIR/rig"
install -m 0644 "$temp_man" "$MAN_INSTALL_DIR/rig.1"
say "installed $MAN_INSTALL_DIR/rig.1"

case :$PATH: in
  *:$INSTALL_DIR:*) ;;
  *) say "note: $INSTALL_DIR is not on PATH" ;;
esac

say "done — run 'rig --help' to get started"
