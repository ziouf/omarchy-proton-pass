#!/usr/bin/env bash
# pass-bootstrap-pat.sh — one-time setup for the perpetual Proton Pass keepalive.
#
# Creates a Proton Pass personal access token (PAT) and stores it in the login
# keyring (Secret Service) under service=proton-pass-pat. The health timer
# (proton-pass-ssh-agent-health.timer) reads it back and runs
# `pass-cli login --pat` non-interactively whenever the session has died, so the
# session is revived without a browser. Without a stored PAT the keepalive is a
# no-op and the session dies on its server-side TTL.
#
# The PAT is held only transiently in memory; it is never written to disk.
#
# Idempotent: if a PAT is already stored, it does nothing.
#
# Usage: pass-bootstrap-pat.sh [--name NAME] [--expiration EXPIRATION]
#   NAME        token label (default: omarchy)
#   EXPIRATION  1h|1d|1w|1m|3m|6m|1y (default: 1y; renew with
#               `pass-cli personal-access-token renew` before it expires)
set -euo pipefail
export PROTON_PASS_LINUX_KEYRING=dbus

name="omarchy"
expiration="1y"
while (( $# > 0 )); do
  case "$1" in
    --name)       name="$2"; shift 2 ;;
    --expiration) expiration="$2"; shift 2 ;;
    -h|--help)    sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)           echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if secret-tool lookup service proton-pass-pat >/dev/null 2>&1; then
  echo "PAT already present in the keyring — nothing to do."
  exit 0
fi

echo "Opening the Proton Pass web login — complete it in your browser…"
pass-cli login

echo "Creating a personal access token (name=${name}, expiration=${expiration})…"
pat="$(pass-cli personal-access-token create --name "$name" --expiration "$expiration" --output json 2>/dev/null \
      | grep -oE 'pst_[A-Za-z0-9+/=_-]+::[A-Za-z0-9+/=_-]+' | head -1 || true)"

if [ -z "$pat" ]; then
  echo "ERROR: could not extract the PAT from the create output." >&2
  exit 1
fi

printf '%s' "$pat" | secret-tool store --label='proton-pass PAT' service proton-pass-pat
unset pat

# Record the expiry so the health timer can warn before it lapses. Renewal
# needs a browser re-login: pass-cli forbids renewing a PAT from a PAT session.
case "$expiration" in
  1h) secs=3600 ;;
  1d) secs=86400 ;;
  1w) secs=604800 ;;
  1m) secs=2592000 ;;
  3m) secs=7776000 ;;
  6m) secs=15552000 ;;
  1y) secs=31536000 ;;
  *)  secs=31536000 ;;
esac
cache="${XDG_CACHE_HOME:-$HOME/.cache}/ziouf.proton-pass"
mkdir -p "$cache"
echo $(( $(date +%s) + secs )) > "$cache/pat-expires"
rm -f "$cache/pat-warned"

# Grant the PAT editor access to every vault. PAT sessions are scoped: a PAT
# with no grants sees zero vaults, which breaks vault sync and the SSH agent.
echo "Granting the PAT editor access to all vaults…"
pass-cli vault list --output json 2>/dev/null \
  | jq -r '.vaults[].name' 2>/dev/null \
  | while IFS= read -r v; do
      [ -n "$v" ] && pass-cli personal-access-token access grant \
        --personal-access-token-name "$name" --vault-name "$v" --role editor >/dev/null 2>&1 || true
    done

if secret-tool lookup service proton-pass-pat >/dev/null 2>&1; then
  echo "PAT stored. The health timer will now revive the session automatically."
else
  echo "ERROR: PAT not found after storing." >&2
  exit 1
fi
