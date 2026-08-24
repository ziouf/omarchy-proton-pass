// Lightweight translation catalog for the ziouf.proton-pass plugin.
// The system locale selects the language; English doubles as the fallback.
// Keys use %1..%9 placeholders, filled with String.arg() at the call site.

.pragma library

var catalogs = {
  en: {
    "error.detailTimeout": "The request timed out — try again.",
    "search.reset": "Reset search",
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

  zh: {
    "error.detailTimeout": "请求超时 — 请重试。",
    "search.reset": "重置搜索",
    // Session states
    "status.unlocked": "会话已解锁",
    "status.locked": "会话已锁定",
    "status.checking": "检查中…",
    "status.loggedOut": "未登录",

    // Actions
    "action.lock": "锁定",
    "action.createLockCode": "创建锁定码",
    "action.unlock": "解锁",
    "action.login": "登录",
    "action.refresh": "刷新",

    // Navigation
    "nav.vaults": "保管库",
    "vault.all": "所有保管库",
    "vault.allShort": "全部",
    "search.vaults": "搜索保管库…",
    "search.filterIn": "在 %1 中筛选…",
    "vault.noneAccessible": "没有可用的保管库。",
    "vault.hintLockedOrOut": "请登录或解锁后继续。",
    "vault.loading": "正在加载保管库…",
    "items.noneAtAll": "保管库中没有任何项目。",
    "items.noneHere": "此处没有项目。",
    "detail.decrypting": "正在解密项目…",
    "detail.noFields": "没有可显示的字段。",
    "field.empty": "（空）",
    "field.copyValue": "复制值",

    // Copy actions
    "copy.username": "复制用户名",
    "copy.password": "复制密码",
    "copy.totp": "复制 TOTP 验证码",

    // Item types
    "type.login": "登录",
    "type.alias": "别名",
    "type.note": "安全笔记",
    "type.credit_card": "银行卡",
    "type.identity": "身份信息",
    "type.ssh_key": "SSH 密钥",
    "type.wifi": "Wi-Fi",
    "type.other": "其他",

    // Errors & misc
    "error.detailRead": "无法读取项目 — 会话已锁定或项目不可访问。",
    "error.detailParse": "pass-cli 返回内容无法解析。",
    "error.actionFailed": "操作失败",
    "totp.currentHint": "（复制时获取当前验证码）",
    "field.extraFallback": "字段",

    // Field labels shown in the item detail view
    "field.email": "邮箱",
    "field.username": "用户名",
    "field.password": "密码",
    "field.urls": "URL 列表",
    "field.url": "URL",
    "field.totp": "TOTP",
    "field.content": "内容",
    "field.note": "笔记",
    "field.cardholder": "持卡人",
    "field.number": "卡号",
    "field.cvv": "CVV",
    "field.expiration": "有效期",
    "field.ssid": "SSID",
    "field.pin": "PIN 码",
    "field.publickey": "公钥",
    "field.privatekey": "私钥",
    "field.fingerprint": "指纹",

    // Notifications (shared wording with the shell scripts)
    "notify.copied": "已复制",
    "notify.copyFailed": "复制失败",
    "notify.readFailed": "读取失败",
    "notify.locking": "锁定中",
    "notify.copyOf": "正在复制 %1",
    "notify.actionFailed": "%1 失败（代码 %2）",
    "notify.missingPassCli": "未找到 pass-cli",
    "notify.installHint": "请安装 proton-pass-cli。",
    "notify.missingWlCopy": "缺少 wl-copy",
    "notify.wlClipboardNeeded": "需要 wl-clipboard 才能复制。",
    "notify.totpLabel": "TOTP 验证码",
    "notify.passwordLabel": "密码",
    "notify.usernameLabel": "用户名",
    "notify.forItem": "%2 的 %1",
    "notify.ofItem": "已复制 %2 的 %1（%3 秒）",
    "unit.seconds": "秒"
  },

  fr: {
    "error.detailTimeout": "Délai dépassé — réessaie.",
    "search.reset": "Réinitialiser la recherche",
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
