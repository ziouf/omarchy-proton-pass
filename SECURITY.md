# Security & scope

This document declares what the **ziouf.proton-pass** plugin can and cannot
do, so a marketplace review (or a curious user) can verify its scope in one
place. The automated marketplace baseline flags three capabilities for this
plugin; each is declared and justified below.

## Capability declaration

| Capability | Trigger | Reality |
|---|---|---|
| `package-manager` | `README.md` and `install-services.sh` mention `yay` / `pacman` | **Documentation only.** The plugin never invokes a package manager. `proton-pass-cli` is a prerequisite the **user installs themselves**; the scripts only print a pointer to the README when it is missing. |
| `installer` | `install-services.sh`, `uninstall-services.sh` | **True by nature, user-scope by design.** Two optional scripts that copy unit files into `~/.config/systemd/user/`, write one `environment.d` file, and toggle the matching user units. Both refuse to run as root, support `--dry-run`, and act only on components selected via flags. |
| `service-management` | `systemctl --user` calls and bundled unit files | **True and intentional.** Three user units: `proton-pass-ssh-agent.service` (pass-cli as SSH agent), `proton-pass-session-guard.service` (locks the pass-cli session when the desktop locks), `proton-pass-cache.service` + `.timer` (metadata refresh). Everything is `systemctl --user`; nothing touches the system bus or other services. |

## What this plugin never does

- Never runs `sudo`, `pkexec`, or anything as root
- Never installs, upgrades, or removes a package
- Never downloads or executes remote code (no `curl | bash`)
- Never writes secrets to disk — secret storage belongs to pass-cli's own
  encrypted store; clipboard values transit through a `0600` tmpfs buffer
  that is shredded immediately after the copy
- Never sends telemetry; the only network traffic is pass-cli talking to
  Proton's API

## File-by-file surface

| Path | Touches |
|---|---|
| `manifest.json`, `Pass.qml`, `Main.qml`, `I18n.js` | Bar widget + panel; spawns `pass-cli`, `wl-copy`, `notify-send`, `omarchy-shell`, `wtype` |
| `scripts/copy-secret`, `scripts/copy-value` | Clipboard copy via `0600` tmpfs buffer + auto-clear; `x-kde-passwordManagerHint` set so the Omarchy clipboard manager excludes secrets from history |
| `scripts/pass-cache-update` | Writes `~/.cache/ziouf.proton-pass/items.json` (mode `0600`): item ids, titles, vault names, types — **never secrets** |
| `scripts/pass-pick`, `scripts/pass-autotype` | Read the cache; summon the Omarchy menu picker; `wtype` types into the focused window after a 3-second notice |
| `scripts/pass-session-guard` | Polls the desktop lock state; runs `pass-cli session lock` on lock |
| `scripts/install-services.sh`, `uninstall-services.sh` | `~/.config/systemd/user/proton-pass-*`, `~/.config/environment.d/90-proton-pass.conf`, `~/.cache/ziouf.proton-pass/` (uninstall only) |
| `systemd/*.service`, `systemd/*.timer` | The three user units described above |

## Environment changes

The only environment mutation is `SSH_AUTH_SOCK` (set via
`~/.config/environment.d/90-proton-pass.conf` and
`systemctl --user set-environment`) so that ssh resolves keys stored in
Proton Pass. It is installed only with the `--ssh-agent` component and is
removed by `uninstall-services.sh`.
