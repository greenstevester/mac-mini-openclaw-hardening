# Mac mini OpenClaw hardening kit

This kit contains a cautious shell script to harden a Mac mini before installing OpenClaw.

## Files
- `mac-mini-openclaw-hardening.sh` — the hardening script
- `README-mac-mini-openclaw-hardening.md` — this guide

## What the script does
- Optionally sets the Mac hostname
- Creates a dedicated standard user called `openclawsvc` if it does not already exist
- Ensures that account is **not** an admin
- Turns on the macOS Application Firewall
- Enables stealth mode
- Enables Remote Login (SSH)
- Prepares `~/.ssh`, `authorized_keys`, and secure file permissions
- Adds your public key to `authorized_keys` if present
- Backs up `/etc/ssh/sshd_config`
- Hardens SSH settings
- Disables password-based SSH auth **only if** `authorized_keys` is non-empty
- Applies practical `pmset` settings for a headless service box
- Prints listening ports and current status checks

## What it does not do
- It does **not** enable FileVault automatically
- It does **not** install Little Snitch
- It does **not** grant sensitive macOS permissions like Full Disk Access, Accessibility, or Screen Recording
- It does **not** install OpenClaw

## Before you run it
Make sure your public key exists. The script defaults to:

```bash
~/.ssh/mac-mini-bruce-id_ed25519.pub
```

If your key is elsewhere, pass it in as an environment variable.

## Recommended run sequence

### 1) Review the script
```bash
less mac-mini-openclaw-hardening.sh
```

### 2) Make it executable
```bash
chmod +x mac-mini-openclaw-hardening.sh
```

### 3) Run it with defaults
```bash
./mac-mini-openclaw-hardening.sh
```

### 4) Run it with a custom hostname
```bash
SET_HOSTNAME=mac-mini-bruce ./mac-mini-openclaw-hardening.sh
```

### 5) Run it with a custom public key path
```bash
PUBKEY_FILE="$HOME/.ssh/my-other-key.pub" ./mac-mini-openclaw-hardening.sh
```

### 6) Run it with a different SSH login allowlist user
By default, the script sets `AllowUsers` in `sshd_config` to the current shell user.

```bash
SSH_ALLOW_USER=bruce ./mac-mini-openclaw-hardening.sh
```

## After the script
### Turn on FileVault if needed
System Settings → Privacy & Security → FileVault

### Install Little Snitch
Suggested approach:
- start in an approval/monitoring mode
- allow Apple system services you trust
- allow SSH and Tailscale if you use them
- allow OpenClaw only to destinations you intentionally need
- deny or review broad outbound traffic from helper processes

### Run OpenClaw in the dedicated account
Use the separate `openclawsvc` account and keep the service bound to `127.0.0.1`.

### Remote access
Prefer:
- SSH tunneling
- Tailscale

Avoid:
- exposing OpenClaw on `0.0.0.0`
- router port forwarding

## Safe SSH test command
Use this from your client machine to avoid the “too many authentication failures” problem:

```bash
ssh -i ~/.ssh/mac-mini-bruce-id_ed25519 -o IdentitiesOnly=yes bruce@mac-mini-bruce.local
```

Adjust the key path and hostname as needed.

## Suggested OpenClaw stance
- dedicated non-admin macOS account
- localhost binding only
- minimum macOS permissions
- minimum integrations
- no Full Disk Access unless truly required
