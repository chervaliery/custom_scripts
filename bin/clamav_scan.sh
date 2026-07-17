#!/usr/bin/env bash
set -euo pipefail

SCAN_DIRS_FILE="/etc/clamav/scan_dirs.conf"
TMP_REPORT=$(mktemp)

WHITELIST_PATHS="/etc/clamav/whitelist_paths.txt"
WHITELIST_HASHES="/etc/clamav/whitelist_hashes.txt"

# Build the scan list from the config file (one directory per line, # comments allowed)
if [ ! -r "$SCAN_DIRS_FILE" ]; then
    echo "Error: scan directory config not found: $SCAN_DIRS_FILE" >&2
    exit 1
fi

SCAN_DIRS=""
while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="$(echo "$line" | xargs)"   # trim whitespace
    [ -z "$line" ] && continue
    SCAN_DIRS="$SCAN_DIRS $line"
done < "$SCAN_DIRS_FILE"

if [ -z "$SCAN_DIRS" ]; then
    echo "Error: no scan directories configured in $SCAN_DIRS_FILE" >&2
    exit 1
fi

HOSTNAME=$(hostname)
MAILJET_SCRIPT="/usr/local/bin/mailjet-send"

LOCKFILE="/var/run/clamav_scan.lock"

exec 9>"$LOCKFILE"
flock -n 9 || exit 0

clamdscan --multiscan --fdpass --infected $SCAN_DIRS > "$TMP_REPORT" || true

INFECTED_FOUND=0
FILTERED_REPORT=""

while IFS= read -r line; do
    [[ "$line" != *"FOUND" ]] && continue

    FILE=$(echo "$line" | cut -d: -f1)

    if grep -Fxq "$FILE" "$WHITELIST_PATHS" 2>/dev/null; then
        continue
    fi

    if [ -f "$FILE" ]; then
        HASH=$(sha256sum "$FILE" | awk '{print $1}')
        if grep -Fxq "$HASH" "$WHITELIST_HASHES" 2>/dev/null; then
            continue
        fi
    fi

    FILTERED_REPORT+="$line\n"
    INFECTED_FOUND=1

done < "$TMP_REPORT"

if [ "$INFECTED_FOUND" -eq 1 ]; then
    REPORT_CONTENT=$(printf "%b" "$FILTERED_REPORT")

    [ -z "$REPORT_CONTENT" ] && REPORT_CONTENT="ClamAV detected infections."

    $MAILJET_SCRIPT "ClamAV Alert on $HOSTNAME" "$REPORT_CONTENT" "ClamAV"
fi

rm -f "$TMP_REPORT"
