# Proton Pass for Omarchy

[Proton Pass CLI](https://github.com/protonpass/pass-cli) as a system-wide
secret provider for [Omarchy](https://omarchy.org): session status in the bar,
vault navigation, typed items, field-level detail view, clipboard copy with
auto-clear, an SSH agent service, and pass-cli session locking tied to the
desktop lock.

![category](https://img.shields.io/badge/category-Security-blue)

## Features

- **Bar widget** — a key icon reflecting the pass-cli session state
  (logged out / locked / unlocked). Right click locks the session, middle
  click refreshes.
- **Three-level panel**
  1. *Vaults* with item counts and a search filter
  2. *Typed items* — logins, aliases, secure notes, credit cards, identities,
     SSH keys and Wi-Fi credentials each get their own icon and label; quick
     actions (username / password / TOTP) on login rows
  3. *Field detail* — every decrypted field of the selected item, sensitive
     values masked until copied
- **Safe clipboard** — values are copied through a `0600` tmpfs buffer (never
  passed as process arguments) and the clipboard is cleared automatically
  after a configurable delay.
- **Optional system services**
  - `proton-pass-ssh-agent.service`: run pass-cli as your SSH agent
  - `proton-pass-session-guard.service`: lock the pass-cli session whenever
    the Omarchy desktop locks
- **Launcher menu entries** — optional snippet to drive the plugin from the
  Omarchy menu (search / lock / unlock / login).

## Requirements

- [Omarchy](https://omarchy.org)
- [`proton-pass-cli`](https://aur.archlinux.org/packages/proton-pass-cli) from
  the AUR: `yay -S proton-pass-cli` (or `pacman -S proton-pass-cli` if you use
  a helper that builds it into your repos)
- A Proton Pass account, authenticated once with `pass-cli login`
- `wl-clipboard` (present on stock Omarchy) for clipboard support

## Installation

### Plugin

```bash
omarchy plugin add https://github.com/ziouf/omarchy-proton-pass
```

The widget appears in the bar (right section by default; move it with
`omarchy bar move ziouf.proton-pass --section right`). Log in once from the
panel ("Connexion" button) or directly:

```bash
pass-cli login
```

Recommended hardening — create a lock code so the session can be locked:

```bash
pass-cli session create-lock
```

### Optional system services (SSH agent + lock-on-screen-lock)

```bash
~/.config/omarchy/plugins/ziouf.proton-pass/install-services.sh
```

This installs two systemd user services and exports `SSH_AUTH_SOCK`
session-wide (`~/.config/environment.d/90-proton-pass.conf`). New sessions
then resolve SSH keys stored in your Proton Pass vaults.

> Import existing keys so ssh keeps working:
> `pass-cli item create ssh-key import --from-private-key ~/.ssh/id_ed25519 --title "$(hostname)"`

### Optional Omarchy menu shortcuts

Append to `~/.config/omarchy/extensions/omarchy-menu.jsonc`:

```jsonc
{
  "trigger.pass": {
    "icon": "\uf084",
    "label": "Proton Pass",
    "aliases": ["pass", "passwords", "secrets", "proton-pass"]
  },
  "trigger.pass.search": {
    "icon": "\udb80\udc49",
    "label": "Rechercher un secret",
    "action": "omarchy-shell ziouf.proton-pass toggle"
  },
  "trigger.pass.lock": {
    "icon": "\uf023",
    "label": "Verrouiller la session",
    "when": "timeout 10 pass-cli info 2>/dev/null | grep -qi 'has lock: yes'",
    "action": "omarchy-shell ziouf.proton-pass lock"
  },
  "trigger.pass.unlock": {
    "icon": "\uf09c",
    "label": "Déverrouiller la session",
    "when": "pass-cli info 2>&1 | grep -qi locked",
    "action": "omarchy-shell ziouf.proton-pass unlock"
  },
  "trigger.pass.login": {
    "icon": "\ue282",
    "label": "Connexion Proton Pass",
    "when": "! timeout 10 pass-cli info >/dev/null 2>&1",
    "action": "omarchy-shell ziouf.proton-pass login"
  }
}
```

(If the file already exists, merge these keys inside the top-level object.)

## Uninstallation

Remove the optional services first, if installed:

```bash
~/.config/omarchy/plugins/ziouf.proton-pass/uninstall-services.sh
```

Then remove the plugin:

```bash
omarchy plugin remove ziouf.proton-pass
```

Leftovers you may want to clean manually:

- `~/.config/environment.d/90-proton-pass.conf` (handled by
  `uninstall-services.sh`)
- the widget entry in `~/.config/omarchy/shell.json`, if it was added to the
  bar layout manually
- menu entries in `~/.config/omarchy/extensions/omarchy-menu.jsonc`

## Settings

| Key                   | Default | Description                                    |
|-----------------------|---------|------------------------------------------------|
| `refreshIntervalSec`  | 60      | Session status polling interval                |
| `clipboardTimeoutSec` | 30      | Seconds before the clipboard is cleared (0=never) |
| `showTotp`            | true    | Offer the TOTP copy action on login items      |

## Security notes

- Secrets never touch disk outside of pass-cli's own encrypted storage; the
  clipboard buffer lives in `$XDG_RUNTIME_DIR` (tmpfs, mode 600) and is
  shredded right after the copy.
- Clipboard auto-clear only wipes the clipboard if our value is still there.
- The session guard locks the CLI session server-side via
  `pass-cli session lock`; it requires a lock code created beforehand with
  `pass-cli session create-lock`.

## License

MIT — see [LICENSE](LICENSE).
