#!/usr/bin/env bash
# Publishes font files to /var/www/craft/fonts (served at /craft/fonts/) and writes the
# fonts.json index the bridge reads. Every browser that opens WordCraft through ownCloud
# then gets these fonts automatically, as if added with WordCraft's Add Font….
#
#   sudo apt install fonts-liberation2 && sudo ./install-fonts.sh     # Liberation (default)
#   sudo ./install-fonts.sh /usr/share/fonts/truetype/dejavu ~/myfonts   # any folders/files
#
# Rerun after adding or removing fonts. Keep the set small: every browser downloads it once.
set -euo pipefail

DEST="${DEST:-/var/www/craft/fonts}"
srcs=("$@")

if [ ${#srcs[@]} -eq 0 ]; then
  for d in /usr/share/fonts/truetype/liberation2 /usr/share/fonts/truetype/liberation; do
    if [ -d "$d" ]; then srcs=("$d"); break; fi
  done
  if [ ${#srcs[@]} -eq 0 ]; then
    echo "No Liberation fonts found. Install them first: sudo apt install fonts-liberation2" >&2
    exit 1
  fi
fi

mkdir -p "$DEST"
for s in "${srcs[@]}"; do
  find "$s" -maxdepth 2 -type f \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.ttc' \
       -o -iname '*.woff' -o -iname '*.woff2' \) -exec cp -fL {} "$DEST/" \;
done

cd "$DEST"
{
  echo '['
  first=1
  for f in *; do
    case "${f,,}" in *.ttf|*.otf|*.ttc|*.woff|*.woff2) ;; *) continue ;; esac
    case "$f" in *'"'*|*'\'*) echo "skipping odd name: $f" >&2; continue ;; esac
    [ $first = 1 ] || echo ','
    first=0
    printf '  {"name": "%s", "size": %d}' "$f" "$(stat -c %s "$f")"
  done
  echo
  echo ']'
} > fonts.json
chmod -R a+rX,go-w "$DEST"
echo "Published $(grep -c '"name"' fonts.json) font files in $DEST"
