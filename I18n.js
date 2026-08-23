// Lightweight translation catalog for the ziouf.proton-pass plugin.
// The system locale selects the language; English doubles as the fallback.
// Keys use %1..%9 placeholders, filled with String.arg() at the call site.

.pragma library

var catalogs = {
  en: {
    // Session states
    "status.unlocked": "Session unlocked",
    "status.locked": "Session locked",
    "status.checking": "Checking…",
    "status.loggedOut": "Not signed in",

    // Actions
    "action.lock": "Lock",
    "action.createLockCode": "Create lock code",
    "action.unlock": "Unlock",
    "action.login": "Sign in",
    "action.refresh": "Refresh",

    // Navigation
    "nav.vaults": "Vaults",
    "vault.all": "All vaults",
    "vault.allShort": "All",
    "search.vaults": "Search vaults…",
    "search.filterIn": "Filter in %1…",
    "vault.noneAccessible": "No vault available.",
    "vault.hintLockedOrOut": "Sign in or unlock to continue.",
    "vault.loading": "Loading vaults…",
    "items.noneAtAll": "No items in any vault.",
    "items.noneHere": "No items here.",
    "detail.decrypting": "Decrypting item…",
    "detail.noFields": "No displayable fields.",
    "field.empty": "(empty)",
    "field.copyValue": "Copy value",

    // Copy actions
    "copy.username": "Copy username",
    "copy.password": "Copy password",
    "copy.totp": "Copy TOTP code",

    // Item types
    "type.login": "Login",
    "type.alias": "Alias",
    "type.note": "Secure note",
    "type.credit_card": "Credit card",
    "type.identity": "Identity",
    "type.ssh_key": "SSH key",
    "type.wifi": "Wi-Fi",
    "type.other": "Other",

    // Errors & misc
    "error.detailRead": "Cannot read item — locked session or inaccessible item.",
    "error.detailParse": "Unreadable pass-cli response.",
    "error.actionFailed": "Action failed",
    "totp.currentHint": "(current code on copy)",
    "field.extraFallback": "Field",

    // Field labels shown in the item detail view
    "field.email": "Email",
    "field.username": "Username",
    "field.password": "Password",
    "field.urls": "URLs",
    "field.url": "URL",
    "field.totp": "TOTP",
    "field.content": "Content",
    "field.note": "Note",
    "field.cardholder": "Cardholder",
    "field.number": "Number",
    "field.cvv": "CVV",
    "field.expiration": "Expiration",
    "field.ssid": "SSID",
    "field.pin": "PIN",
    "field.publickey": "Public key",
    "field.privatekey": "Private key",
    "field.fingerprint": "Fingerprint",

    // Notifications (shared wording with the shell scripts)
    "notify.copied": "Copied",
    "notify.copyFailed": "Copy failed",
    "notify.readFailed": "Failed to read",
    "notify.locking": "Locking",
    "notify.copyOf": "Copying %1",
    "notify.actionFailed": "%1 failed (exit code %2)",
    "notify.missingPassCli": "pass-cli not found",
    "notify.installHint": "Install proton-pass-cli.",
    "notify.missingWlCopy": "wl-copy missing",
    "notify.wlClipboardNeeded": "wl-clipboard is required to copy.",
    "notify.totpLabel": "TOTP code",
    "notify.passwordLabel": "password",
    "notify.usernameLabel": "username",
    "notify.forItem": "%1 for \"%2\"",
    "notify.ofItem": "%1 of \"%2\" (%3 s)",
    "unit.seconds": "s"
  },

  fr: {
    "status.unlocked": "Session déverrouillée",
    "status.locked": "Session verrouillée",
    "status.checking": "Vérification…",
    "status.loggedOut": "Non connecté",

    "action.lock": "Verrouiller",
    "action.createLockCode": "Créer un code",
    "action.unlock": "Déverrouiller",
    "action.login": "Connexion",
    "action.refresh": "Actualiser",

    "nav.vaults": "Coffres",
    "vault.all": "Tous les coffres",
    "vault.allShort": "Tous",
    "search.vaults": "Rechercher un coffre…",
    "search.filterIn": "Filtrer dans %1…",
    "vault.noneAccessible": "Aucun coffre disponible.",
    "vault.hintLockedOrOut": "Connecte-toi ou déverrouille pour continuer.",
    "vault.loading": "Chargement des coffres…",
    "items.noneAtAll": "Aucun élément dans les coffres.",
    "items.noneHere": "Aucun élément ici.",
    "detail.decrypting": "Déchiffrement de l'élément…",
    "detail.noFields": "Aucun champ affichable.",
    "field.empty": "(vide)",
    "field.copyValue": "Copier la valeur",

    "copy.username": "Copier l'identifiant",
    "copy.password": "Copier le mot de passe",
    "copy.totp": "Copier le code TOTP",

    "type.login": "Connexion",
    "type.alias": "Alias",
    "type.note": "Note sécurisée",
    "type.credit_card": "Carte bancaire",
    "type.identity": "Identité",
    "type.ssh_key": "Clé SSH",
    "type.wifi": "Wi-Fi",
    "type.other": "Autre",

    "error.detailRead": "Lecture impossible — session verrouillée ou élément inaccessible.",
    "error.detailParse": "Réponse illisible de pass-cli.",
    "error.actionFailed": "Échec de l'action",
    "totp.currentHint": "(code actuel à la copie)",
    "field.extraFallback": "Champ",

    // Field labels shown in the item detail view
    "field.email": "E-mail",
    "field.username": "Identifiant",
    "field.password": "Mot de passe",
    "field.urls": "URLs",
    "field.url": "URL",
    "field.totp": "TOTP",
    "field.content": "Contenu",
    "field.note": "Note",
    "field.cardholder": "Titulaire",
    "field.number": "Numéro",
    "field.cvv": "CVV",
    "field.expiration": "Expiration",
    "field.ssid": "SSID",
    "field.pin": "PIN",
    "field.publickey": "Clé publique",
    "field.privatekey": "Clé privée",
    "field.fingerprint": "Empreinte",

    "notify.copied": "Copié",
    "notify.copyFailed": "La copie a échoué",
    "notify.readFailed": "Échec de lecture",
    "notify.locking": "Verrouillage",
    "notify.copyOf": "Copie de %1",
    "notify.actionFailed": "%1 a échoué (code %2)",
    "notify.missingPassCli": "pass-cli introuvable",
    "notify.installHint": "Installez proton-pass-cli.",
    "notify.missingWlCopy": "wl-copy manquant",
    "notify.wlClipboardNeeded": "wl-clipboard est requis pour copier.",
    "notify.totpLabel": "code TOTP",
    "notify.passwordLabel": "mot de passe",
    "notify.usernameLabel": "identifiant",
    "notify.forItem": "%1 pour « %2 »",
    "notify.ofItem": "%1 de « %2 » (%3 s)",
    "unit.seconds": "s"
  }
}

// Extract the ISO language prefix from a locale name such as
// "fr_FR.UTF-8", "en_US", "fr" or "C".
function normalize(localeName) {
  var text = String(localeName || "").trim().toLowerCase()
  if (text === "" || text === "c" || text === "posix") return "en"
  var match = text.match(/^([a-z]{2,3})(?:[_.@-]|$)/)
  return match ? match[1] : "en"
}

// Translate key within the given language; falls back to English, then to
// the key itself so a missing entry can never render as blank.
function tr(lang, key) {
  var catalog = catalogs[String(lang || "en")]
  if (catalog && catalog[key] !== undefined && catalog[key] !== "") return catalog[key]
  var fallback = catalogs.en
  return fallback[key] !== undefined ? fallback[key] : key
}
