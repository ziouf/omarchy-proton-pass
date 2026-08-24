#!/bin/bash
# uninstall-services.sh — revert everything installed by install-services.sh.
# User-scope only: refuses root. The plugin itself is removed with
# `omarchy plugin remove ziouf.proton-pass`.
#
# Usage:
#   uninstall-services.sh [--ssh-agent] [--session-guard] [--cache] [--all]
#                         [--dry-run] [--yes]

set -euo pipefail

SYSTEMD_DIR="${HOME}/.config/systemd/user"
ENV_FILE="${HOME}/.config/environment.d/90-proton-pass.conf"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ziouf.proton-pass"

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
    -h|--help)       sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)               echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done
(( want_all )) && { want_agent=1; want_guard=1; want_cache=1; }
(( want_agent || want_guard || want_cache )) || { want_agent=1; want_guard=1; want_cache=1; }

plan=()
(( want_agent )) && plan+=("disable:proton-pass-ssh-agent.service" "rmunit:proton-pass-ssh-agent.service" "rmenv:1")
(( want_guard )) && plan+=("disable:proton-pass-session-guard.service" "rmunit:proton-pass-session-guard.service")
(( want_cache )) && plan+=("disable-timer:proton-pass-cache.timer" "rmunit:proton-pass-cache.service" "rmunit:proton-pass-cache.timer" "rmcache:1")
plan+=("daemon-reload:1")

echo "Planned actions:"
for step in "${plan[@]}"; do
  case "${step%%:*}" in
    disable)     echo "  → systemctl --user disable --now ${step#*:}" ;;
    disable-timer) echo "  → systemctl --user disable --now ${step#*:}" ;;
    rmunit)      echo "  → remove $SYSTEMD_DIR/${step#*:}" ;;
    rmenv)       echo "  → remove $ENV_FILE" ;;
    rmcache)     echo "  → remove $CACHE_DIR" ;;
    daemon-reload) echo "  → systemctl --user daemon-reload" ;;
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
    disable)
      echo "→ systemctl --user disable --now $value"
      systemctl --user disable --now "$value" 2>/dev/null || true
      ;;
    disable-timer)
      echo "→ systemctl --user disable --now $value"
      systemctl --user disable --now "$value" 2>/dev/null || true
      ;;
    rmunit)
      echo "→ remove $SYSTEMD_DIR/$value"
      rm -f "$SYSTEMD_DIR/$value"
      ;;
    rmenv)
      echo "→ remove $ENV_FILE"
      rm -f "$ENV_FILE"
      ;;
    rmcache)
      echo "→ remove $CACHE_DIR"
      rm -rf "$CACHE_DIR"
      ;;
    daemon-reload)
      echo "→ systemctl --user daemon-reload"
      systemctl --user daemon-reload
      ;;
  esac
done

echo
echo "Removed the selected components and stopped the pass-cli SSH agent."
echo "Remove the plugin itself with: omarchy plugin remove ziouf.proton-pass"
