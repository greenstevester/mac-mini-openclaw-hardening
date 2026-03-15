# Homebrew for Multiple Non-Admin macOS Users — Option A

This guide sets up **one shared Homebrew installation** under `/opt/homebrew` so that:

- all users can **run** Homebrew-installed tools
- only the admin-owned Homebrew account can **install, update, or upgrade**
- non-admin users do **not** get write access to the Homebrew tree

This is the safer multi-user model on macOS.

---

## Files in this bundle

- `setup-homebrew-shared-readonly.zsh` — setup automation script
- `homebrew-multiuser-option-a-guide.md` — this guide

---

## Before you begin

### Assumptions
- You are on **Apple Silicon** macOS, so Homebrew is installed at `/opt/homebrew`
- Homebrew is already installed once from an admin account
- You want all users to have access to installed tools like `git`, `wget`, `jq`, `fd`, `ripgrep`, etc.
- You do **not** want non-admin users to run `brew install` or `brew upgrade`

### What this approach does not do
- It does not allow non-admin users to manage the Homebrew installation
- It does not solve every GUI app (`brew install --cask`) permission issue, because some apps target `/Applications`

---

## Step-by-step

## 1) Confirm Homebrew is installed where expected

From an admin account:

```sh
ls -ld /opt/homebrew
/opt/homebrew/bin/brew --version
```

You should see the Homebrew directory and a valid version output.

If `/opt/homebrew/bin/brew` does not exist, install Homebrew first.

---

## 2) Review the automation script

The setup script is:

```sh
setup-homebrew-shared-readonly.zsh
```

What it does:

1. verifies `/opt/homebrew` exists
2. detects the current owner and group of the Homebrew tree
3. resets conservative permissions
4. adds Homebrew shell initialization to:
   - `/etc/zprofile`
   - `/etc/profile`
5. leaves installed binaries executable for all users

---

## 3) Run the script as admin

Open Terminal and run:

```sh
cd /path/to/the/downloaded/files
chmod +x setup-homebrew-shared-readonly.zsh
sudo ./setup-homebrew-shared-readonly.zsh
```

You will be prompted for your admin password.

---

## 4) Log out and back in for each non-admin user

This matters because `/etc/zprofile` and `/etc/profile` are read on a new login shell.

After logging back in, test from a non-admin account:

```sh
command -v brew
brew --prefix
echo $PATH
```

Expected:
- `command -v brew` returns `/opt/homebrew/bin/brew`
- `brew --prefix` returns `/opt/homebrew`

---

## 5) Confirm users can run installed packages

From a non-admin account, test a tool that was installed previously by Homebrew.

Examples:

```sh
which git
which jq
which wget
which rg
```

If one of those tools is installed, it should resolve into `/opt/homebrew/bin/...`.

---

## 6) Confirm non-admin users cannot modify Homebrew

From a non-admin account, try:

```sh
brew update
```

or

```sh
brew install tree
```

Expected:
- command should fail with permissions-related errors
- that is the intended result for this model

Users can use installed tools, but only the Homebrew-maintainer admin account should change the package set.

---

## 7) Optional: check permissions

From the admin account:

```sh
ls -ld /opt/homebrew
ls -ld /opt/homebrew/bin
ls -l /opt/homebrew/bin/brew
```

Typical healthy outcome:
- directories are readable and traversable by everyone
- binaries are executable by everyone
- ownership stays with the admin-maintained account and group

---

## 8) Ongoing maintenance model

Use one admin account as the Homebrew maintainer.

Typical workflow:

```sh
brew update
brew upgrade
brew cleanup
```

Do that only from the admin-owned Homebrew account.

Non-admin users then automatically benefit from already-installed and upgraded tools on next use.

---

## Troubleshooting

## `brew` is not found for a non-admin user
Check:

```sh
grep -n 'brew shellenv' /etc/zprofile /etc/profile
```

Then open a new login shell:

```sh
zsh -l
command -v brew
```

If needed, reboot or fully log out and back in.

---

## Tool is installed but still not found
Check whether the binary actually exists:

```sh
ls /opt/homebrew/bin
```

Then inspect PATH:

```sh
echo $PATH
```

If `/opt/homebrew/bin` is missing, the shell init files were not loaded.

---

## Non-admin user can run `brew install`
That usually means the Homebrew tree is too permissive.

Check:

```sh
ls -ld /opt/homebrew
find /opt/homebrew -maxdepth 2 -ls | head
```

Then re-run the script with `sudo`.

---

## Cask installs fail for non-admin users
That is expected in many cases. GUI app installs often require writes to protected system locations such as `/Applications`.

Keep cask operations limited to the admin-maintainer account.

---

## Recommended usage pattern

For shared Macs or Macs with multiple local accounts, use this model:

- install Homebrew once
- expose it globally in login shell config
- let standard users run installed tools
- restrict Homebrew maintenance to one admin-owned account

That gives you predictable behavior with fewer permission issues.

---

## Quick test checklist

From a non-admin account:

```sh
command -v brew
brew --prefix
which git
which jq
which rg
```

From the admin-maintainer account:

```sh
brew update
brew upgrade
```

---

## Rollback

To remove the global shell initialization, edit these files and delete the Homebrew block:

```sh
sudo nano /etc/zprofile
sudo nano /etc/profile
```

To inspect permissions without changing them:

```sh
ls -ld /opt/homebrew /opt/homebrew/bin
```

---

## Notes

This setup is designed for **shared usage of installed command-line tools**, not for collaborative administration of Homebrew itself.
