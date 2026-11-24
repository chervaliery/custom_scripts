#!/usr/bin/env bash
# Installs (or updates) the static web builds of WordCraft, GridCraft and PdfCraft
# from their GitHub releases into $DEST/<app>/releases/<tag>, verifies checksums,
# and points $DEST/<app>/current at the new release. Old releases are kept for rollback.
#
#   sudo ./install-crafts.sh                       # latest release of each app
#   sudo WORDCRAFT_TAG=v0.5.0 ./install-crafts.sh  # pin one app to a given tag
#
# Needs: curl, jq, unzip, sha256sum
set -euo pipefail

DEST="${DEST:-/var/www/craft}"
KEEP="${KEEP:-3}"   # releases kept per app
APPS=(wordcraft gridcraft pdfcraft)

for cmd in curl jq unzip sha256sum; do
  command -v "$cmd" >/dev/null || { echo "missing: $cmd" >&2; exit 1; }
done

for app in "${APPS[@]}"; do
  pin_var="${app^^}_TAG"
  pin="${!pin_var:-}"
  if [ -n "$pin" ]; then
    api="https://api.github.com/repos/storytold/$app/releases/tags/$pin"
  else
    api="https://api.github.com/repos/storytold/$app/releases/latest"
  fi

  json="$(curl -fsSL "$api")"
  tag="$(jq -r '.tag_name' <<<"$json")"
  url="$(jq -r --arg a "$app" '.assets[] | select(.name | test("^" + $a + "-web-.*\\.zip$")) | .browser_download_url' <<<"$json" | head -n1)"
  sums="$(jq -r '.assets[] | select(.name == "SHA256SUMS.txt") | .browser_download_url' <<<"$json" | head -n1)"

  if [ -z "$url" ]; then
    echo "!! $app $tag: no web build in this release, skipping" >&2
    continue
  fi

  rel="$DEST/$app/releases/$tag"
  if [ -d "$rel" ]; then
    echo "== $app $tag already installed"
  else
    echo "== installing $app $tag"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    zip="$tmp/$(basename "$url")"
    curl -fsSL -o "$zip" "$url"

    if [ -n "$sums" ]; then
      curl -fsSL -o "$tmp/SHA256SUMS.txt" "$sums"
      ( cd "$tmp" && grep -E "[ *]$(basename "$zip")\$" SHA256SUMS.txt | sha256sum -c - )
    else
      echo "!! $app $tag: no SHA256SUMS.txt, checksum not verified" >&2
    fi

    mkdir -p "$tmp/x"
    unzip -q "$zip" -d "$tmp/x"
    index="$(find "$tmp/x" -maxdepth 3 -name index.html | head -n1)"
    if [ -z "$index" ]; then
      echo "!! $app $tag: no index.html in the archive" >&2
      exit 1
    fi
    mkdir -p "$DEST/$app/releases"
    cp -a "$(dirname "$index")" "$rel"
    chmod -R a+rX,go-w "$rel"
    rm -rf "$tmp"
    trap - EXIT
  fi

  ln -sfn "releases/$tag" "$DEST/$app/current"
  echo "   $DEST/$app/current -> releases/$tag"

  # prune old releases, newest first by mtime, keep $KEEP
  ls -1dt "$DEST/$app/releases"/* 2>/dev/null | tail -n +"$((KEEP + 1))" | while read -r old; do
    [ "$(readlink -f "$old")" = "$(readlink -f "$DEST/$app/current")" ] && continue
    echo "   pruning $(basename "$old")"
    rm -rf "$old"
  done
done

echo "Done. Roll back an app with: ln -sfn releases/<tag> $DEST/<app>/current"
