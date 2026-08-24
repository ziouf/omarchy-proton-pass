# Proton Pass for Omarchy

[Proton Pass CLI](https://github.com/protonpass/pass-cli) as a system-wide
secret provider for [Omarchy](https://omarchy.org): session status in the bar,
vault navigation, typed items, field-level detail view, clipboard copy with
auto-clear, an SSH agent service, and pass-cli session locking tied to the
desktop lock.

![category](https://img.shields.io/badge/category-Security-blue)

> **Scope & security:** the plugin never installs packages, never runs as
> root and never writes secrets to disk. See [SECURITY.md](SECURITY.md) for
> the full capability declaration.

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
- **Global picker (`pass-pick`)** — a fuzzy-search menu summonable from
  anywhere (keybinding, Omarchy menu, CLI): every result is labelled with its
  item type (Login, Alias, Secure note, Credit card, Identity, SSH key,
  Wi-Fi); pick an item, then the field to copy, autotype it into the focused
  window, or jump to the panel detail.
- **Metadata cache** — a systemd timer refreshes `~/.cache/ziouf.proton-pass/
  items.json` (ids, titles, vaults — never secrets, mode 0600) so the picker
  and the panel open instantly.
- **Launcher menu entries** — optional snippet to drive the plugin from the
  Omarchy menu (search / lock / unlock / login).

## Languages

The interface and notifications follow the system locale
(`LC_ALL` > `LC_MESSAGES` > `LANG`): **English**, **Français** and
**简体中文** are bundled. Any other locale falls back to English. Adding a
language is a single block in `I18n.js`.

## Requirements

- [Omarchy](https://omarchy.org)
- [`proton-pass-cli`](https://aur.archlinux.org/packages/proton-pass-cli) from
  the AUR — **a prerequisite you install yourself**; the plugin never invokes
  a package manager (e.g. `yay -S proton-pass-cli`)
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

Components can be selected individually (`--ssh-agent`, `--session-guard`,
`--cache`, `--all`), previewed with `--dry-run`, and run without the
confirmation prompt using `--yes`. The script refuses to run as root.

This installs the selected systemd user services and — with the SSH agent —
exports `SSH_AUTH_SOCK` session-wide
(`~/.config/environment.d/90-proton-pass.conf`). New sessions then resolve
SSH keys stored in your Proton Pass vaults.

> Import existing keys so ssh keeps working:
> `pass-cli item create ssh-key import --from-private-key ~/.ssh/id_ed25519 --title "$(hostname)"`

### Global keybinding

Add to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + ALT + P", "Proton Pass",
       "$HOME/.config/omarchy/plugins/ziouf.proton-pass/scripts/pass-pick")
```

`SUPER + ALT + P` then opens the searchable picker from anywhere: type to
filter, pick an item, choose what to do (copy username / password / TOTP,
autotype, open details). Secrets are copied with the
`x-kde-passwordManagerHint` flag so the Omarchy clipboard manager excludes
them from history.

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
    "label": "Rechercher un secret (copier)",
    "action": "$HOME/.config/omarchy/plugins/ziouf.proton-pass/scripts/pass-pick"
  },
  "trigger.pass.panel": {
    "icon": "\uf084",
    "label": "Parcourir les coffres (panneau)",
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

## IPC reference

Drive the plugin from scripts or keybindings:

```bash
omarchy-shell ziouf.proton-pass toggle              # open/close the panel
omarchy-shell ziouf.proton-pass refresh             # re-probe + re-list
omarchy-shell ziouf.proton-pass lock                # lock the pass-cli session
omarchy-shell ziouf.proton-pass unlock              # unlock (floating terminal)
omarchy-shell ziouf.proton-pass login               # web login (floating terminal)
omarchy-shell ziouf.proton-pass openItem <itemId>   # open the panel on an item's detail
```

## Troubleshooting

- **Picker shows no items** — refresh the cache:
  `~/.config/omarchy/plugins/ziouf.proton-pass/scripts/pass-cache-update`
- **Picker results are stale** — the cache refreshes every 15 minutes
  (`proton-pass-cache.timer`) and refreshes in the background when older;
  force it with the command above.
- **SSH uses the wrong keys** — with `install-services.sh`, `SSH_AUTH_SOCK`
  points at the Proton Pass agent; import your local keys into a vault or
  remove `~/.config/environment.d/90-proton-pass.conf`.
- **Unlock fails after suspend** ("there is no session") — a locked session
  is destroyed server-side once the lock idle timeout elapses (15 min max,
  see `pass-cli session create-lock --idle-timeout 900`). This is by design:
  after a long suspend the panel offers **Sign in** again instead of
  unlock. Short suspends under the timeout keep the session recoverable.

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
- Autotype types into whatever window has focus after a 3-second heads-up;
  it never presses Enter. Point it at a trusted window.
- Copies are byte-exact (multiline values and special characters survive);
  the TOTP quick action disappears once pass-cli confirms an item carries
  no TOTP code.

## License

MIT — see [LICENSE](LICENSE).
