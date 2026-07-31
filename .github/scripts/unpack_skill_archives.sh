#!/usr/bin/env bash
# unpack_skill_archives.sh <root-dir> <dest-dir>
# Unzips every *.skill archive found under root into dest, so other checks can
# scan their contents. Prints nothing; other checks scan <dest> afterwards.
set -uo pipefail
ROOT="${1:-.}"
DEST="${2:?dest dir required}"
mkdir -p "$DEST"
find "$ROOT" -type d \( -name tests -o -name docs \) -prune -o -type f -name '*.skill' -print 2>/dev/null | while IFS= read -r arch; do
  base="$(basename "$arch" .skill)"
  mkdir -p "$DEST/$base"
  unzip -o -q "$arch" -d "$DEST/$base" 2>/dev/null || true
done
