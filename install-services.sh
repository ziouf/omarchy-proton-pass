#!/bin/bash
# install-services.sh — optional system integration for the ziouf.proton-pass
# Omarchy plugin. User-scope only: refuses root, never installs packages.
# See SECURITY.md for the full capability declaration.
#
# Usage:
#   install-services.sh [--ssh-agent] [--session-guard] [--cache] [--all]
#                       [--dry-run] [--yes]
#
# Components:
#   --ssh-agent      pass-cli SSH agent unit + SSH_AUTH_SOCK session export
#   --session-guard  lock the pass-cli session when the desktop locks
#   --cache          metadata cache refresh timer (instant autocomplete)
#   --all            every component (default when none is given)
#
#   --dry-run        print the planned actions without running them
#   --yes, -y        skip the confirmation prompt (non-interactive)

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEMD_DIR="${HOME}/.config/systemd/user"
ENV_DIR="${HOME}/.config/environment.d"

(( EUID != 0 )) || {
  echo "Refusing to run as root: these services are user-scope by design." >&2
  exit 1
}

want_agent=0 want_guard=0 want_cache=0 want_all=0 dry_run=0 assume_yes=0
while (( $# > 0 )); do
  case "$1" in
    --ssh-agent)     want_agent=1 ;;
    --session-guard) want_guard=1 ;;
    --cache)         want_cache=1 ;;
    --all)           want_all=1 ;;
    --dry-run)       dry_run=1 ;;
    --yes|-y)        assume_yes=1 ;;
    -h|--help)       sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)               echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done
(( want_all )) && { want_agent=1; want_guard=1; want_cache=1; }
(( want_agent || want_guard || want_cache )) || { want_agent=1; want_guard=1; want_cache=1; }

command -v pass-cli >/dev/null 2>&1 || {
  echo "pass-cli is required — install it yourself first (see README, Requirements)." >&2
  exit 1
}

# ---------------------------------------------------------------- action plan
# Each step is "kind:value"; execute_plan() dispatches on the kind.
plan=()
(( want_agent )) && plan+=("unit:proton-pass-ssh-agent.service" "env:1")
(( want_guard )) && plan+=("unit:proton-pass-session-guard.service")
(( want_cache )) && plan+=("unit:proton-pass-cache.service" "unit:proton-pass-cache.timer")
plan+=("daemon-reload:1")

enable_units=""
(( want_agent )) && enable_units+=" proton-pass-ssh-agent.service"
(( want_guard )) && enable_units+=" proton-pass-session-guard.service"
(( want_cache )) && enable_units+=" proton-pass-cache.timer"
plan+=("enable:$enable_units")
(( want_agent )) && plan+=("set-env:1")

echo "Planned actions:"
for step in "${plan[@]}"; do
  case "${step%%:*}" in
    unit)         echo "  → install systemd/${step#*:}" ;;
    env)          echo "  → export SSH_AUTH_SOCK session-wide (environment.d)" ;;
    daemon-reload) echo "  → systemctl --user daemon-reload" ;;
    enable)       echo "  → systemctl --user enable --now${step#*:}" ;;
    set-env)      echo "  → systemctl --user set-environment SSH_AUTH_SOCK" ;;
  esac
done

if (( dry_run )); then
  echo "Dry run — nothing was changed."
  exit 0
fi

if (( ! assume_yes )) && [[ -t 0 ]]; then
  read -r -p "Proceed? [y/N] " answer
  [[ $answer =~ ^[Yy] ]] || { echo "Aborted."; exit 0; }
fi

for step in "${plan[@]}"; do
  kind="${step%%:*}"; value="${step#*:}"
  case "$kind" in
    unit)
      echo "→ install systemd/$value"
      install -Dm644 "$PLUGIN_DIR/systemd/$value" "$SYSTEMD_DIR/$value"
      ;;
    env)
      echo "→ export SSH_AUTH_SOCK session-wide"
      mkdir -p "$ENV_DIR"
      printf 'SSH_AUTH_SOCK=%%h/.ssh/proton-pass-agent.sock\n' > "$ENV_DIR/90-proton-pass.conf"
      ;;
    daemon-reload)
      echo "→ systemctl --user daemon-reload"
      systemctl --user daemon-reload
      ;;
    enable)
      echo "→ systemctl --user enable --now$value"
      # shellcheck disable=SC2086
      systemctl --user enable --now $value
      ;;
    set-env)
      echo "→ systemctl --user set-environment SSH_AUTH_SOCK"
      systemctl --user set-environment SSH_AUTH_SOCK="$HOME/.ssh/proton-pass-agent.sock"
      ;;
  esac
done

echo
echo "Done. Components installed:"
(( want_agent )) && echo "  - proton-pass-ssh-agent.service    (SSH agent on ~/.ssh/proton-pass-agent.sock)"
(( want_guard )) && echo "  - proton-pass-session-guard.service (locks pass-cli when the desktop locks)"
(( want_cache )) && echo "  - proton-pass-cache.timer           (metadata cache for instant autocomplete)"
if (( want_agent )); then
  echo
  echo "Note: with SSH_AUTH_SOCK set, ssh uses keys stored in Proton Pass."
  echo "Import an existing key with:"
  echo "  pass-cli item create ssh-key import --from-private-key ~/.ssh/id_ed25519 --title \"\$(hostname)\""
fi
