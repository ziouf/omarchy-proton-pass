import QtQuick
import Quickshell
import Quickshell.Io

// Data layer of the Proton Pass bar widget. Every pass-cli exchange lives
// here so the display side only reads plain properties:
//
//   status     "logged-out" | "locked" | "unlocked" | "checking"
//   account    signed-in email, when known
//   items      [{ itemId, shareId, vault, title, hasTotp }]
//
// The session probe is `pass-cli info`: exit 0 means a local session exists.
// A locked session makes API calls fail with a "locked" complaint, and that
// wording is what separates locked from logged-out. Listing items needs a
// vault, so a full refresh walks `vault list` and then `item list` per vault,
// keeping only Active entries.

Item {
  id: root
  visible: false

  property var settings: ({})

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string scriptDir: home + "/.config/omarchy/plugins/ziouf.proton-pass/scripts"

  property string status: "checking"
  property string account: ""
  property bool hasLockCode: false
  property var items: []
  property var vaults: []
  property bool itemsLoading: false
  property int dataRevision: 0

  // Item detail (third navigation level).
  property var currentItem: null
  property var detailFields: []
  property bool detailLoading: false
  property string detailError: ""

  // ------------------------------------------------------------- settings

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  readonly property int refreshIntervalSec: Math.max(15, Number(setting("refreshIntervalSec", 60)))
  readonly property int clipboardTimeoutSec: Number(setting("clipboardTimeoutSec", 30))
  readonly property bool showTotp: setting("showTotp", true) !== false

  Timer {
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.probeSession()
  }

  // -------------------------------------------------------- session probe

  property string probeStdout: ""
  property string probeStderr: ""

  Process {
    id: probeProcess
    running: false

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.probeStdout = text
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.probeStderr = text
    }

    onExited: function(exitCode) {
      root.applyProbe(exitCode)
    }
  }

  function probeSession() {
    if (probeProcess.running) return
    probeStdout = ""
    probeStderr = ""
    probeProcess.command = ["pass-cli", "info"]
    probeProcess.running = true
  }

  function applyProbe(exitCode) {
    var out = String(root.probeStdout || "")
    var err = String(root.probeStderr || "")
    var combined = (out + "\n" + err).toLowerCase()

    if (exitCode !== 0) {
      console.log("ziouf.proton-pass/probe exit=" + exitCode +
                  " out=" + JSON.stringify(out.slice(0, 200)) +
                  " err=" + JSON.stringify(err.slice(0, 200)))
      if (combined.indexOf("lock") >= 0 && combined.indexOf("unlock") < 0) {
        root.status = "locked"
      } else if (combined.indexOf("not logged") >= 0 || combined.indexOf("no session") >= 0
                 || combined.indexOf("log in") >= 0 || combined.indexOf("login required") >= 0
                 || combined.indexOf("session expired") >= 0) {
        console.log("ziouf.proton-pass/probe -> logged-out (clearing state)")
        root.status = "logged-out"
        root.account = ""
        root.hasLockCode = false
        if (root.items.length > 0 || root.vaults.length > 0) {
          root.items = []
          root.vaults = []
          root.dataRevision++
        }
      } else {
        // An unknown failure (offline, update pending…) keeps the last known
        // state rather than flapping the bar icon on every transient error.
        if (root.status === "checking") root.status = "logged-out"
      }
      return
    }

    root.status = "unlocked"
    var emailMatch = out.match(/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/)
    if (emailMatch) root.account = emailMatch[0]
    root.hasLockCode = /has lock\s*:?\s*yes/i.test(out)
  }

  // ------------------------------------------------------------ item walk

  // One refresh fans out into one `item list` run per vault. Results are
  // accumulated in itemAccumulator and published once the last vault lands.
  property var pendingVaults: []
  property var itemAccumulator: []

  property string processStdout: ""

  Process {
    id: walkProcess
    running: false

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.processStdout = text
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim() !== "") console.warn("ziouf.proton-pass", text.trim())
    }

    onExited: function(exitCode) { root.walkExited(exitCode) }
  }

  function refreshItems() {
    if (walkProcess.running) return
    root.itemsLoading = true
    root.itemAccumulator = []
    root.processStdout = ""
    walkProcess.command = ["pass-cli", "vault", "list", "--output", "json"]
    walkProcess.running = true
  }

  function walkExited(exitCode) {
    var output = String(root.processStdout)
    root.processStdout = ""

    console.log("ziouf.proton-pass/walk exit=" + exitCode +
                " itemRun=" + isItemListRun() +
                " pending=" + root.pendingVaults.length +
                " acc=" + root.itemAccumulator.length +
                " vaults=" + root.vaults.length)

    if (exitCode !== 0) {
      root.itemsLoading = false
      root.pendingVaults = []
      applyProbe(exitCode)
      return
    }

    // First leg of the walk: publish the queue of vaults to enumerate.
    if (root.pendingVaults.length === 0 && root.itemAccumulator.length === 0 && !isItemListRun()) {
      var names = parseVaultNames(output)
      root.vaults = names
      // Distinct array: runNextVault() shifts the queue, and a shared
      // reference would drain the displayed vault list as the walk consumes it.
      root.pendingVaults = names.slice()
      if (names.length === 0) {
        root.publishItems()
        return
      }
      runNextVault()
      return
    }

    accumulateItems(output)

    if (root.pendingVaults.length > 0) {
      runNextVault()
    } else {
      root.publishItems()
    }
  }

  // The walk reuses one Process for both command kinds; remember which kind
  // produced the output we are holding.
  function isItemListRun() {
    var cmd = walkProcess.command || []
    return cmd[1] === "item"
  }

  function runNextVault() {
    if (root.pendingVaults.length === 0) {
      root.publishItems()
      return
    }
    var vaultName = root.pendingVaults.shift()
    root.processStdout = ""
    walkProcess.command = ["pass-cli", "item", "list", vaultName, "--output", "json"]
    walkProcess.running = true
  }

  function parseVaultNames(output) {
    var parsed = null
    try {
      parsed = JSON.parse(String(output || ""))
    } catch (e) {
      console.warn("ziouf.proton-pass", "vault list JSON parse failed:", e)
      return []
    }
    var arr = Array.isArray(parsed) ? parsed : (parsed && parsed.vaults ? parsed.vaults : [])
    var names = []
    for (var i = 0; i < arr.length; i++) {
      var name = String(arr[i] && arr[i].name ? arr[i].name : "").trim()
      if (name !== "") names.push(name)
    }
    return names
  }

  function accumulateItems(output) {
    var parsed = null
    try {
      parsed = JSON.parse(String(output || ""))
    } catch (e) {
      console.warn("ziouf.proton-pass", "item list JSON parse failed:", e)
      return
    }
    var arr = Array.isArray(parsed) ? parsed : (parsed && parsed.items ? parsed.items : [])
    var currentVault = String(walkProcess.command[3] || "")
    for (var i = 0; i < arr.length; i++) {
      var raw = arr[i] || {}
      if (String(raw.state || "Active").toLowerCase() === "trashed") continue
      var title = String(raw.title || "").trim()
      if (title === "") continue
      root.itemAccumulator.push({
        itemId: String(raw.id || ""),
        shareId: String(raw.share_id || raw.shareId || ""),
        vault: currentVault,
        title: title,
        itemType: String(raw.item_type || raw.type || ""),
        username: "",
        hasTotp: false
      })
    }
  }

  function publishItems() {
    var result = root.itemAccumulator.slice()
    result.sort(function(a, b) { return a.title.localeCompare(b.title) })
    root.items = result
    root.dataRevision++
    root.itemsLoading = false
  }

  // --------------------------------------------------------- item detail

  property string detailStdout: ""

  Process {
    id: detailProcess
    running: false

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.detailStdout = text
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim() !== "") console.warn("ziouf.proton-pass/detail", text.trim())
    }

    onExited: function(exitCode) {
      root.detailLoading = false
      if (exitCode !== 0) {
        root.detailError = "Lecture impossible — session verrouillée ou élément inaccessible."
        return
      }
      root.parseDetail(root.detailStdout)
    }
  }

  function loadDetail(item) {
    if (detailProcess.running) return
    root.currentItem = item
    root.detailFields = []
    root.detailError = ""
    root.detailLoading = true
    root.detailStdout = ""
    var vault = String(item.shareId || item.vault || "")
    var ref = String(item.itemId || item.title || "")
    detailProcess.command = ["pass-cli", "item", "view", "--output", "json",
                             "pass://" + vault + "/" + ref]
    detailProcess.running = true
  }

  function prettifyKey(key) {
    var map = {
      "email": "E-mail", "username": "Identifiant", "password": "Mot de passe",
      "urls": "URLs", "url": "URL", "totp_uri": "TOTP", "content": "Contenu",
      "cardholder": "Titulaire", "number": "Numéro", "cvv": "CVV",
      "expirationdate": "Expiration", "ssid": "SSID", "pin": "PIN",
      "publickey": "Clé publique", "privatekey": "Clé privée",
      "fingerprint": "Empreinte"
    }
    var k = String(key || "").toLowerCase()
    if (map[k]) return map[k]
    return String(key || "").replace(/_/g, " ").replace(/^./, function(c) { return c.toUpperCase() })
  }

  function parseDetail(output) {
    var parsed = null
    try {
      parsed = JSON.parse(String(output || ""))
    } catch (e) {
      root.detailError = "Réponse illisible de pass-cli."
      return
    }
    var it = (parsed && parsed.item) || {}
    var content = it.content || {}
    var inner = content.content || {}

    var rows = []

    // The typed payload sits under exactly one non-null key: Login, Note,
    // CreditCard, Identity, Alias, SshKey, or Wifi. Scalars become copy
    // rows; nested objects and passkey arrays are skipped.
    var typeObj = null
    for (var key in inner) {
      if (inner[key] !== null && typeof inner[key] === "object") { typeObj = inner[key]; break }
    }

    if (String(content.note || "").trim() !== "") {
      rows.push({ label: "Note", field: "", value: String(content.note), hidden: false, multiline: true })
    }

    if (typeObj) {
      for (var f in typeObj) {
        var v = typeObj[f]
        if (v === null || v === undefined || v === "") continue
        if (Array.isArray(v)) {
          var strs = []
          for (var i = 0; i < v.length; i++)
            if (typeof v[i] === "string" && v[i] !== "") strs.push(v[i])
          if (strs.length > 0)
            rows.push({ label: prettifyKey(f), field: f, value: strs.join("\n"),
                        hidden: false, multiline: strs.join("\n").length > 48 })
        } else if (typeof v === "object") {
          continue
        } else if (f === "totp_uri") {
          rows.push({ label: "TOTP", field: "totp", value: "(code actuel à la copie)",
                      hidden: false, multiline: false })
        } else {
          var text = String(v)
          var hiddenKey = /password|secret|cvv|private|pin/i.test(f)
          rows.push({ label: prettifyKey(f), field: f, value: text,
                      hidden: hiddenKey, multiline: !hiddenKey && text.length > 48 })
        }
      }
    }

    var extras = Array.isArray(content.extra_fields) ? content.extra_fields : []
    for (var e = 0; e < extras.length; e++) {
      var extra = extras[e] || {}
      var label = String(extra.label || extra.name || "Champ")
      var value = ""
      if (extra.content !== undefined && extra.content !== null) value = String(extra.content)
      else if (extra.value !== undefined && extra.value !== null) value = String(extra.value)
      if (value === "") continue
      var hiddenField = String(extra.type || "").toLowerCase() === "hidden"
      rows.push({ label: label, field: label, value: value,
                  hidden: hiddenField, multiline: !hiddenField && value.length > 48 })
    }

    root.detailFields = rows
  }

  // ---------------------------------------------------- buffered copying

  // Values already decrypted in the panel go to a tmpfs buffer file instead
  // of process arguments, then copy-value puts them on the clipboard and
  // removes the file.
  readonly property string bufferPath: (Quickshell.env("XDG_RUNTIME_DIR") || home + "/.cache")
                                       + "/ziouf.proton-pass.copy-buffer"

  FileView {
    id: bufferFile
    path: root.bufferPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
  }

  Process {
    id: bufferCopyProcess
    running: false
  }

  function copyValue(label, value, hidden, timeoutSec) {
    if (!Quickshell.env("XDG_RUNTIME_DIR")) return
    bufferFile.setText(String(value))
    Qt.callLater(function() {
      bufferCopyProcess.command = [scriptDir + "/copy-value", bufferPath,
                                   label, hidden ? "secret" : "valeur",
                                   String(timeoutSec)]
      bufferCopyProcess.running = true
    })
  }

  // -------------------------------------------------------------- actions

  property string actionProcessLabel: ""

  Process {
    id: actionProcess
    running: false

    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim() !== "") console.warn("ziouf.proton-pass/action", text.trim())
    }

    onExited: function(exitCode) {
      var label = root.actionProcessLabel
      root.actionProcessLabel = ""
      if (exitCode !== 0) {
        root.notify("Échec", label + " a échoué (code " + exitCode + ")", "critical")
      }
      root.probeSession()
    }
  }

  function runAction(command, label) {
    if (actionProcess.running) return
    root.actionProcessLabel = label
    actionProcess.command = command
    actionProcess.running = true
  }

  function lockSession() {
    runAction(["pass-cli", "session", "lock"], "Verrouillage")
  }

  function copyField(item, field) {
    // Prefer ids; fall back to titles when an entry lacks them. The URI form
    // pass://<vault>/<item>/<field> accepts both ids and titles.
    var vault = String(item.shareId || item.vault || "")
    var ref = String(item.itemId || item.title || "")
    runAction([root.scriptDir + "/copy-secret", vault, ref, field,
               String(Math.max(0, root.clipboardTimeoutSec))],
              "Copie de " + field)
  }

  // Terminal flows (login, unlock) need interactive prompts, so they open in
  // their own floating terminal instead of a background process.
  function launchTerminal(command) {
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", command])
  }

  function login() { launchTerminal("pass-cli login") }

  function unlock() { launchTerminal("pass-cli session unlock") }

  function notify(summary, body, urgency) {
    Quickshell.execDetached(["notify-send", "-a", "Proton Pass", "-t", "4000",
                             "-u", urgency || "normal", summary, body || ""])
  }

  Component.onCompleted: probeSession()
}
