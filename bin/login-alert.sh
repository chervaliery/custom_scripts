#!/bin/bash
#
# PAM login alert via Mailjet
# Triggered by pam_exec.so on session open.
# Sends an email when a monitored user opens a session.
#

USER_LIST_FILE="/etc/login-alert-users"
MAILJET_SCRIPT="/usr/local/bin/mailjet-send"


# --- Only act on session open ---
[ "$PAM_TYPE" != "open_session" ] && exit 0

# --- Only alert for users listed in $USER_LIST_FILE ---
[ -r "$USER_LIST_FILE" ] || exit 0

matched=0
while IFS= read -r line || [ -n "$line" ]; do
    # trim leading/trailing whitespace
    user="${line#"${line%%[![:space:]]*}"}"
    user="${user%"${user##*[![:space:]]}"}"
    # skip empty lines and comments
    [ -z "$user" ] && continue
    case "$user" in \#*) continue ;; esac
    if [ "$user" = "$PAM_USER" ]; then
        matched=1
        break
    fi
done < "$USER_LIST_FILE"

[ "$matched" -eq 0 ] && exit 0

# --- Gather context ---
HOSTNAME=$(hostname)
DATE=$(date '+%Y-%m-%d %H:%M:%S %Z')
SRC_IP="${PAM_RHOST:-local/console}"
SERVICE="${PAM_SERVICE:-unknown}"

BODY=$(cat <<EOF
User ${PAM_USER} logged in.

Host: ${HOSTNAME}
Date: ${DATE}
Source IP: ${SRC_IP}
Service: ${SERVICE}
EOF
)

$MAILJET_SCRIPT "[ALERT] ${PAM_USER} login on ${HOSTNAME}" "$BODY" "Server Monitor" > /dev/null 2>&1 &

exit 0
