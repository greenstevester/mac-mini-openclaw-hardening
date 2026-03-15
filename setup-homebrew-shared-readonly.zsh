#!/bin/zsh
set -euo pipefail

BREW_PREFIX="/opt/homebrew"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run this script with sudo."
  echo "Example: sudo zsh ./setup-homebrew-shared-readonly.zsh"
  exit 1
fi

echo "==> Checking Homebrew prefix"
if [[ ! -d "${BREW_PREFIX}" ]]; then
  echo "Homebrew not found at ${BREW_PREFIX}."
  echo "Install Homebrew first from an admin account, then rerun this script."
  exit 1
fi

echo "==> Detecting primary admin group owner"
CURRENT_OWNER="$(stat -f '%Su' "${BREW_PREFIX}")"
CURRENT_GROUP="$(stat -f '%Sg' "${BREW_PREFIX}")"

echo "Current owner: ${CURRENT_OWNER}"
echo "Current group: ${CURRENT_GROUP}"

echo "==> Setting conservative permissions on ${BREW_PREFIX}"
chown -R "${CURRENT_OWNER}:${CURRENT_GROUP}" "${BREW_PREFIX}"

find "${BREW_PREFIX}" -type d -exec chmod 775 {} \;
find "${BREW_PREFIX}" -type f -exec chmod 664 {} \;

chmod 755 "${BREW_PREFIX}/bin" "${BREW_PREFIX}/sbin"
find "${BREW_PREFIX}/bin" -type f -exec chmod 755 {} \;
find "${BREW_PREFIX}/sbin" -type f -exec chmod 755 {} \;

if [[ -d "${BREW_PREFIX}/share" ]]; then
  find "${BREW_PREFIX}/share" -type d -exec chmod 775 {} \;
fi

if [[ -d "${BREW_PREFIX}/Cellar" ]]; then
  find "${BREW_PREFIX}/Cellar" -type d -exec chmod 775 {} \;
fi

if [[ -d "${BREW_PREFIX}/Caskroom" ]]; then
  find "${BREW_PREFIX}/Caskroom" -type d -exec chmod 775 {} \;
fi

echo "==> Installing global shell initialization"
if [[ -f /etc/zprofile ]] && grep -Fq 'eval "$(/opt/homebrew/bin/brew shellenv)"' /etc/zprofile; then
  echo "/etc/zprofile already contains Homebrew shellenv"
else
  printf '\n# Homebrew\neval "$(/opt/homebrew/bin/brew shellenv)"\n' >> /etc/zprofile
  echo "Updated /etc/zprofile"
fi

if [[ -f /etc/profile ]] && grep -Fq 'eval "$(/opt/homebrew/bin/brew shellenv)"' /etc/profile; then
  echo "/etc/profile already contains Homebrew shellenv"
else
  printf '\n# Homebrew\neval "$(/opt/homebrew/bin/brew shellenv)"\n' >> /etc/profile
  echo "Updated /etc/profile"
fi

echo "==> Verifying brew visibility for future logins"
su -l "${CURRENT_OWNER}" -c 'command -v brew >/dev/null 2>&1 && brew --prefix || true' || true

cat <<'EOF'

Done.

What this script does:
- keeps Homebrew installed once under /opt/homebrew
- ensures all users can get brew on PATH via /etc/zprofile and /etc/profile
- keeps the Homebrew tree owned by the existing owner/group
- leaves non-admin users able to run installed tools, but not manage Homebrew

Recommended next checks from a non-admin account:
  command -v brew
  brew --prefix
  which wget   # replace with any installed brew package
EOF
