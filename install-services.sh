#!/bin/bash
# install-services.sh — optional system integration for the ziouf.proton-pass
# Omarchy plugin:
#
#   1. systemd user service running the pass-cli SSH agent
#   2. systemd user service locking the pass-cli session when the desktop locks
#   3. SSH_AUTH_SOCK exported session-wide via environment.d
#
# Run from anywhere: paths are resolved relative to this script.

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEMD_DIR="${HOME}/.config/systemd/user"
ENV_DIR="${HOME}/.config/environment.d"

[[ -x "$(command -v pass-cli)" ]] || {
  echo "pass-cli is required (pacman -S proton-pass-cli or yay -S proton-pass-cli)." >&2
  exit 1
}

install_unit() {
  install -Dm644 "$PLUGIN_DIR/systemd/$1" "$SYSTEMD_DIR/$1"
}

install_unit proton-pass-ssh-agent.service
install_unit proton-pass-session-guard.service
install_unit proton-pass-cache.service
install_unit proton-pass-cache.timer

mkdir -p "$ENV_DIR"
printf 'SSH_AUTH_SOCK=%%h/.ssh/proton-pass-agent.sock\n' > "$ENV_DIR/90-proton-pass.conf"

systemctl --user daemon-reload
systemctl --user enable --now proton-pass-ssh-agent.service proton-pass-session-guard.service
systemctl --user enable --now proton-pass-cache.timer
systemctl --user set-environment SSH_AUTH_SOCK="$HOME/.ssh/proton-pass-agent.sock"

echo "Installed and started:"
echo "  - proton-pass-ssh-agent.service    (SSH agent on ~/.ssh/proton-pass-agent.sock)"
echo "  - proton-pass-session-guard.service (locks pass-cli when the desktop locks)"
echo "  - proton-pass-cache.timer           (metadata cache for instant autocomplete)"
echo "  - $ENV_DIR/90-proton-pass.conf      (SSH_AUTH_SOCK for new sessions)"
echo
echo "Note: with SSH_AUTH_SOCK set, ssh uses keys stored in Proton Pass."
echo "Import an existing key with:"
echo "  pass-cli item create ssh-key import --from-private-key ~/.ssh/id_ed25519 --title \"\$(hostname)\""
