#!/usr/bin/env bash
# Downloads Chillax (Indian Type Foundry, ITF Free Font License) from Fontshare into
# assets/fonts/. The font may be embedded in the app but not redistributed on its own,
# so the files are not committed.
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
curl -fsSL -o "$tmp/chillax.zip" https://api.fontshare.com/v2/fonts/download/chillax
unzip -q -o "$tmp/chillax.zip" -d "$tmp/chillax"
for w in Regular Medium Semibold Bold; do
  f=$(find "$tmp/chillax" -type f \( -iname "Chillax-$w.ttf" -o -iname "Chillax-$w.otf" \) | sort | head -1)
  if [ -z "$f" ]; then echo "Chillax-$w not found in the Fontshare download" >&2; find "$tmp/chillax" -type f >&2; exit 1; fi
  cp "$f" "assets/fonts/Chillax-$w.ttf"
done
ls -la assets/fonts/Chillax-*
