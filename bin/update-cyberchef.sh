#!/usr/bin/env bash
set -euo pipefail

echo "== CyberChef update =="

# ---- Config ----
DIR="/var/www/cyberchef"
TMP_DIR="/tmp"
API_URL="https://api.github.com/repos/gchq/CyberChef/releases/latest"

# ---- Token retrieval ----
TOKEN=""

if command -v secret-tool >/dev/null 2>&1; then
    TOKEN=$(secret-tool lookup service updateme username github 2>/dev/null || true)
fi

if [ -z "$TOKEN" ] && [ -n "${GITHUB_TOKEN:-}" ]; then
    TOKEN="$GITHUB_TOKEN"
fi

if [ -z "$TOKEN" ]; then
    echo "Error: No GitHub token available" >&2
    exit 1
fi

AUTH_HEADER="Authorization: Bearer $TOKEN"

# ---- Fetch latest release info ----
JSON=$(curl -fsSL -H "$AUTH_HEADER" "$API_URL")

VER=$(echo "$JSON" | jq -r '.tag_name')
echo "Latest version: $VER"

# ---- Check current version ----
if [ ! -f "$DIR/.version" ] || ! grep -q "$VER" "$DIR/.version"; then

    echo "Updating CyberChef..."

    URL=$(echo "$JSON" | jq -r '.assets[] | select(.name | endswith(".zip")) | .browser_download_url' | head -n1)

    if [ -z "$URL" ]; then
        echo "Error: Could not find download URL" >&2
        exit 1
    fi

    FILE="$TMP_DIR/$(basename "$URL")"

    # ---- Download ----
    curl -fsSL "$URL" -o "$FILE"

    # ---- Extract ----
    unzip -q -o "$FILE" -d "$DIR"

    # ---- Normalize filename ----
    mv -f "$DIR"/CyberChef_*.html "$DIR/index.html"

    # ---- Save version ----
    echo "$VER" > "$DIR/.version"

    # ---- Cleanup ----
    rm -f "$FILE"

    echo "Installed version $VER"

else
    echo "Already up-to-date ($VER)"
fi
