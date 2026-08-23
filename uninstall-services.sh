#!/bin/bash
# uninstall-services.sh — revert everything installed by install-services.sh.
# The plugin itself is removed with `omarchy plugin remove ziouf.proton-pass`.

set -uo pipefail

SYSTEMD_DIR="${HOME}/.config/systemd/user"
ENV_FILE="${HOME}/.config/environment.d/90-proton-pass.conf"

for unit in proton-pass-ssh-agent.service proton-pass-session-guard.service; do
  systemctl --user disable --now "$unit" 2>/dev/null || true
  rm -f "$SYSTEMD_DIR/$unit"
done

systemctl --user disable --now proton-pass-cache.timer 2>/dev/null || true
rm -f "$SYSTEMD_DIR/proton-pass-cache.service" "$SYSTEMD_DIR/proton-pass-cache.timer"
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/ziouf.proton-pass"

rm -f "$ENV_FILE"
systemctl --user daemon-reload

pkill -f "pass-cli ssh-agent start" 2>/dev/null || true

echo "Removed services, environment override, and stopped the pass-cli SSH agent."
echo "Remove the plugin itself with: omarchy plugin remove ziouf.proton-pass"
