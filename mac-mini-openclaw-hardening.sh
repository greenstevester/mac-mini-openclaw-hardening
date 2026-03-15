#!/bin/zsh
set -euo pipefail

# Mac mini hardening helper for an OpenClaw host.
# Review before running. Some actions require sudo and may prompt.
# This script avoids turning off SSH password auth unless an authorized_keys file exists and is non-empty.

OPENCLAW_USER="${OPENCLAW_USER:-openclawsvc}"
SSH_ALLOW_USER="${SSH_ALLOW_USER:-$USER}"
SET_HOSTNAME="${SET_HOSTNAME:-}"
PUBKEY_FILE="${PUBKEY_FILE:-$HOME/.ssh/mac-mini-bruce-id_ed25519.pub}"
ADMIN_HOME="${ADMIN_HOME:-$HOME}"

log() { print -P "%F{cyan}==>%f $*"; }
warn() { print -P "%F{yellow}WARNING:%f $*"; }
ok() { print -P "%F{green}OK:%f $*"; }

require_sudo() {
  sudo -v
}

backup_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    sudo cp "$f" "$f.bak.$(date +%Y%m%d-%H%M%S)"
  fi
}

append_if_missing() {
  local line="$1"
  local file="$2"
  if ! sudo grep -Eq "^[[:space:]]*${line//\//\\/}([[:space:]]+.*)?$" "$file" 2>/dev/null; then
    print -- "$line" | sudo tee -a "$file" >/dev/null
  fi
}

set_or_replace_sshd_option() {
  local key="$1"
  local value="$2"
  local file="/etc/ssh/sshd_config"

  if sudo grep -Eq "^[#[:space:]]*${key}[[:space:]]+" "$file"; then
    sudo perl -0pi -e "s|^[#\s]*${key}\s+.*$|${key} ${value}|mg" "$file"
  else
    print -- "${key} ${value}" | sudo tee -a "$file" >/dev/null
  fi
}

log "Checking macOS version and current state"
sw_vers
echo
scutil --get ComputerName || true
scutil --get LocalHostName || true
scutil --get HostName || true
echo
fdesetup status || true
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate || true
sudo systemsetup -getremotelogin || true
pmset -g || true
echo

require_sudo

if [[ -n "$SET_HOSTNAME" ]]; then
  log "Setting host/computer names to: $SET_HOSTNAME"
  sudo scutil --set ComputerName "$SET_HOSTNAME"
  sudo scutil --set LocalHostName "$SET_HOSTNAME"
  sudo scutil --set HostName "$SET_HOSTNAME"
  ok "Hostname updated"
fi

log "Ensuring dedicated standard user exists: $OPENCLAW_USER"
if id "$OPENCLAW_USER" >/dev/null 2>&1; then
  ok "User $OPENCLAW_USER already exists"
else
  warn "You will be prompted to set a password for $OPENCLAW_USER"
  sudo sysadminctl -addUser "$OPENCLAW_USER" -fullName "OpenClaw Service" -password -
  ok "Created user $OPENCLAW_USER"
fi

if dseditgroup -o checkmember -m "$OPENCLAW_USER" admin 2>/dev/null | grep -q "yes"; then
  warn "$OPENCLAW_USER is in admin group; removing it"
  sudo dseditgroup -o edit -d "$OPENCLAW_USER" -t user admin
  ok "Removed $OPENCLAW_USER from admin group"
else
  ok "$OPENCLAW_USER is not an admin"
fi

log "Turning on macOS Application Firewall"
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on >/dev/null
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

log "Enabling stealth mode"
sudo defaults write /Library/Preferences/com.apple.alf stealthenabled -int 1
sudo pkill -HUP socketfilterfw || true
ok "Stealth mode requested"

log "Enabling Remote Login (SSH)"
sudo systemsetup -setremotelogin on >/dev/null
sudo systemsetup -getremotelogin

log "Preparing SSH directory and permissions for current admin user: $USER"
mkdir -p "$ADMIN_HOME/.ssh"
chmod 700 "$ADMIN_HOME/.ssh"
touch "$ADMIN_HOME/.ssh/authorized_keys"
chmod 600 "$ADMIN_HOME/.ssh/authorized_keys"

if [[ -f "$PUBKEY_FILE" ]]; then
  if ! grep -Fqx "$(cat "$PUBKEY_FILE")" "$ADMIN_HOME/.ssh/authorized_keys"; then
    cat "$PUBKEY_FILE" >> "$ADMIN_HOME/.ssh/authorized_keys"
    ok "Added public key from $PUBKEY_FILE to authorized_keys"
  else
    ok "Public key already present in authorized_keys"
  fi
else
  warn "Public key file not found: $PUBKEY_FILE"
  warn "SSH password auth will NOT be disabled unless authorized_keys is non-empty"
fi

log "Tightening shell and SSH file permissions"
chmod 600 "$ADMIN_HOME/.ssh/authorized_keys"
chmod 600 "$ADMIN_HOME/.zshenv" 2>/dev/null || true
chmod 600 "$ADMIN_HOME/.zshrc" 2>/dev/null || true
chmod 644 "$ADMIN_HOME"/.ssh/*.pub 2>/dev/null || true

log "Backing up and hardening sshd_config"
backup_file /etc/ssh/sshd_config
set_or_replace_sshd_option "PermitRootLogin" "no"
set_or_replace_sshd_option "PubkeyAuthentication" "yes"
set_or_replace_sshd_option "UsePAM" "yes"
set_or_replace_sshd_option "MaxAuthTries" "3"
set_or_replace_sshd_option "X11Forwarding" "no"
set_or_replace_sshd_option "AllowUsers" "$SSH_ALLOW_USER"

if [[ -s "$ADMIN_HOME/.ssh/authorized_keys" ]]; then
  log "authorized_keys is non-empty; disabling password-style SSH auth"
  set_or_replace_sshd_option "PasswordAuthentication" "no"
  set_or_replace_sshd_option "KbdInteractiveAuthentication" "no"
  set_or_replace_sshd_option "ChallengeResponseAuthentication" "no"
else
  warn "authorized_keys is empty; leaving password authentication unchanged to avoid lockout"
fi

log "Restarting sshd"
sudo launchctl stop com.openssh.sshd || true
sudo launchctl start com.openssh.sshd
ok "sshd restarted"

log "Applying power settings for a headless service box"
sudo pmset -a sleep 0 disksleep 0 displaysleep 30 powernap 0
pmset -g custom

log "Showing listening ports"
sudo lsof -i -P -n | grep LISTEN || true

log "Checking FileVault status"
fdesetup status || true
if ! fdesetup status 2>/dev/null | grep -qi "On"; then
  warn "FileVault is not enabled. Turn it on manually in System Settings > Privacy & Security > FileVault."
fi

cat <<EOF

Done.

Recommended next steps:
1. Install Little Snitch and start with monitoring/approval mode.
2. Run OpenClaw only in the dedicated user: $OPENCLAW_USER
3. Bind OpenClaw to 127.0.0.1 only.
4. Access it remotely using SSH tunneling or Tailscale, not an open LAN port.
5. Test SSH with:
   ssh -i ~/.ssh/$(basename "$PUBKEY_FILE" .pub) -o IdentitiesOnly=yes ${SSH_ALLOW_USER}@$(scutil --get LocalHostName 2>/dev/null || hostname).local

Note:
- This script does NOT enable FileVault automatically.
- This script does NOT grant Accessibility, Full Disk Access, or Screen Recording.
- Review /etc/ssh/sshd_config after running.
EOF
