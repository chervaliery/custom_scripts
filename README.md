# Custom Scripts

Collection of system administration and monitoring scripts.

## Installation

Create symlinks to make scripts accessible system-wide:

```bash
sudo ln -s /opt/custom_scripts/bin/mailjet-send /usr/local/bin/mailjet-send
sudo ln -s /opt/custom_scripts/bin/login-alert.sh /usr/local/bin/login-alert.sh
sudo ln -s /opt/custom_scripts/bin/clamav_scan.sh /usr/local/bin/clamav_scan.sh
sudo ln -s /opt/custom_scripts/bin/mysql_backup.sh /usr/local/bin/mysql_backup.sh
sudo ln -s /opt/custom_scripts/bin/update-cyberchef.sh /usr/local/bin/update-cyberchef.sh
sudo ln -s /opt/custom_scripts/bin/vpn /usr/local/bin/vpn
```

## Scripts

| Script                                           | Description                           |
|--------------------------------------------------|---------------------------------------|
| [`mailjet-send`](bin/mailjet-send)               | Send emails via Mailjet API           |
| [`login-alert.sh`](bin/login-alert.sh)           | PAM hook for login notifications      |
| [`clamav_scan.sh`](bin/clamav_scan.sh)           | ClamAV scanner with whitelist support |
| [`mysql_backup.sh`](bin/mysql_backup.sh)         | MySQL database backup utility         |
| [`update-cyberchef.sh`](bin/update-cyberchef.sh) | Auto-update CyberChef web interface   |
| [`vpn`](bin/vpn)                                 | WireGuard VPN management              |

## Configuration

Each script that needs credentials or settings is configured independently below.
Credentials live in per-concern files under `/etc/custom_scripts/`; create the
directory once:

```bash
sudo mkdir -p /etc/custom_scripts
```

### mailjet-send

Sends mail for `mailjet-send` itself and, indirectly, for `login-alert.sh` and
`clamav_scan.sh` — configure it first. Copy the template and set the values:

```bash
sudo cp etc/custom_scripts/mailjet.env.example /etc/custom_scripts/mailjet.env
sudo chmod 600 /etc/custom_scripts/mailjet.env
```

| Variable             | Purpose                       |
|----------------------|-------------------------------|
| `MAILJET_API_KEY`    | Mailjet API key               |
| `MAILJET_SECRET_KEY` | Mailjet secret key            |
| `EMAIL_FROM`         | Sender address                |
| `EMAIL_TO`           | Recipient address for alerts  |

### mysql_backup.sh

Reads `DB_USER` and `DB_PASS` from `/etc/custom_scripts/mysql_backup.env`. Backups are
written to `/opt/mysql_export` and kept for 15 days.

```bash
sudo cp etc/custom_scripts/mysql_backup.env.example /etc/custom_scripts/mysql_backup.env
sudo chmod 600 /etc/custom_scripts/mysql_backup.env
```

### clamav_scan.sh

The scanner reads three configuration files under `/etc/clamav/`:

| File                                | Format                     | Purpose                                                    |
|-------------------------------------|----------------------------|------------------------------------------------------------|
| `/etc/clamav/scan_dirs.conf`        | one directory per line     | Directories to scan (blank lines and `#` comments allowed) |
| `/etc/clamav/whitelist_paths.txt`   | one absolute path per line | File paths to ignore even if flagged                       |
| `/etc/clamav/whitelist_hashes.txt`  | one SHA-256 hash per line  | File hashes to ignore even if flagged                      |

Set up the scan directories (an example is provided in this repo) and create the
initially empty whitelist files:

```bash
sudo cp etc/clamav/scan_dirs.conf.example /etc/clamav/scan_dirs.conf
sudo "$EDITOR" /etc/clamav/scan_dirs.conf
sudo touch /etc/clamav/whitelist_paths.txt /etc/clamav/whitelist_hashes.txt
```

To whitelist a false positive, append its full path to `whitelist_paths.txt`, or its
SHA-256 hash (`sha256sum <file>`) to `whitelist_hashes.txt`. The scan runs
non-interactively (e.g. from cron) and emails a filtered report via `mailjet-send`
only when non-whitelisted infections are found.

### login-alert.sh

Emails an alert whenever a *monitored* user opens a PAM session.

1. List the monitored users in `/etc/login-alert-users`, one username per line
   (blank lines and `#` comments are ignored):

   ```bash
   sudo cp etc/login-alert-users.example /etc/login-alert-users
   sudo "$EDITOR" /etc/login-alert-users
   ```

2. Hook the script into PAM by adding this line to the relevant service (e.g.
   `/etc/pam.d/sshd`, or `/etc/pam.d/common-session` for all sessions):

   ```bash
   echo 'session optional pam_exec.so seteuid /usr/local/bin/login-alert.sh' | sudo tee -a /etc/pam.d/common-session
   ```

The script only acts on `open_session` events and exits silently for users not in
the list.

### update-cyberchef.sh

Fetches the latest CyberChef release from GitHub into `/var/www/cyberchef`. GitHub's
API requires authentication, so create a Personal Access Token and store it in the
system keyring:

1. Create a **fine-grained personal access token** at
   <https://github.com/settings/personal-access-tokens> (public-repo read access is
   sufficient for downloading releases).

2. Store it with `secret-tool` under the service/username the script looks up:

   ```bash
   secret-tool store --label="GitHub CyberChef updater" service updateme username github
   ```

   You will be prompted to paste the token. As a fallback, the script also accepts
   the token via the `GITHUB_TOKEN` environment variable.

### vpn

Manages a WireGuard interface (`wg0`) while keeping the private key encrypted at rest.
The key is stored GPG-symmetric-encrypted at `/etc/wireguard/wg0.key.gpg` and decrypted
into the running interface only (never written to disk).

Create the encrypted key once, from your existing `wg0.conf`:

```bash
# take the PrivateKey value out of wg0.conf first, then:
echo 'KEC...your_private_key...' > /tmp/wg.key
sudo gpg --symmetric --cipher-algo AES256 -o /etc/wireguard/wg0.key.gpg /tmp/wg.key
shred -u /tmp/wg.key
```

Then remove the `PrivateKey` line from `/etc/wireguard/wg0.conf` so the key exists only
in the encrypted file. Usage:

```bash
vpn up      # prompts for the GPG passphrase, brings wg0 up, injects the key
vpn down
vpn status
```
