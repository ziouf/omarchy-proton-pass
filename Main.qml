import QtQuick
import Quickshell
import Quickshell.Io
import "I18n.js" as I18n

// Data layer of the Proton Pass bar widget. Every pass-cli exchange lives
// here so the display side only reads plain properties:
//
//   status     "logged-out" | "locked" | "unlocked" | "checking"
//   account    signed-in email, when known
//   items      [{ itemId, shareId, vault, title, hasTotp }]
//
// Resource limits (marketplace security baseline): every pass-cli command
// runs under coreutils `timeout` (hard producer-side deadline — Quickshell
// Process exposes no kill), stream captures are capped, and the item/detail
// models are bounded so a hung or hostile CLI can neither stall the
// long-lived shell nor retain unbounded secret material.

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

  // ------------------------------------------------------- resource limits
  readonly property int maxCaptureChars: 2 * 1024 * 1024  // per stream, 2 MiB
  readonly property int maxErrCaptureChars: 16 * 1024     // per stderr stream
  readonly property int maxItems: 2000
  readonly property int maxVaults: 64
  readonly property int maxDetailFields: 64
  readonly property int maxValueChars: 65536
  readonly property int probeDeadlineSec: 15
  readonly property int walkLegDeadlineSec: 45
  readonly property int detailDeadlineSec: 25
  readonly property int actionDeadlineSec: 60

  // Hard producer-side deadline: coreutils timeout TERMinates the command
  // (KILL 5 s later); onExited then sees exit code 124.
  function timed(sec, cmd) {
    return ["timeout", "--signal=TERM", "--kill-after=5", String(sec)].concat(cmd)
  }

  function truncate(value, maxChars) {
    var s = String(value === undefined || value === null ? "" : value)
    return s.length > maxChars ? s.substring(0, maxChars) : s
  }

  // Never journal account identifiers: probe output carries the account
  // email and the session id.
  function redact(text) {
    var s = String(text === undefined || text === null ? "" : text)
    s = s.replace(/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g, "[email]")
    s = s.replace(/(ID\s*:)\s*\S+/, "$1 [redacted]")
    s = s.replace(/(Username\s*:)\s*\S+/, "$1 [redacted]")
    return s
  }

  // ------------------------------------------------------------- settings

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  readonly property int refreshIntervalSec: Math.max(15, Number(setting("refreshIntervalSec", 60)))
  readonly property int clipboardTimeoutSec: Number(setting("clipboardTimeoutSec", 30))
  readonly property bool showTotp: setting("showTotp", true) !== false
  readonly property bool genericNotifications: setting("genericNotifications", false) === true

  // System locale drives the UI language (LC_ALL > LC_MESSAGES > LANG >
  // Qt locale); English doubles as the fallback catalog.
  readonly property string lang: I18n.normalize(
    Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES")
    || Quickshell.env("LANG") || Qt.locale().name)

  function tr(key) { return I18n.tr(lang, key) }

  function trFmt(key) {
    var out = tr(key)
    for (var i = 1; i < arguments.length; i++)
      out = out.split("%" + i).join(String(arguments[i]))
    return out
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.probeSession()
  }

  // -------------------------------------------------------- session probe

  property string probeCapture: ""
  property string probeErrCapture: ""

  Process {
    id: probeProcess
    running: false

    stdout: SplitParser {
      onRead: function(data) {
        if (root.probeCapture.length < root.maxCaptureChars)
          root.probeCapture += data + "\n"
      }
    }
    stderr: SplitParser {
      onRead: function(data) {
        if (root.probeErrCapture.length < root.maxErrCaptureChars)
          root.probeErrCapture += data + "\n"
      }
    }

    onExited: function(exitCode) {
      root.applyProbe(exitCode)
    }
  }

  function probeSession() {
    if (probeProcess.running) return
    probeCapture = ""
    probeErrCapture = ""
    probeProcess.command = root.timed(root.probeDeadlineSec, ["pass-cli", "info"])
    probeProcess.running = true
  }

  function applyProbe(exitCode) {
    var out = String(root.probeCapture || "")
    var err = String(root.probeErrCapture || "")
    var combined = (out + "\n" + err).toLowerCase()
    root.probeCapture = ""
    root.probeErrCapture = ""

    // pass-cli info exits 0 even when it fails ("Command is not logout there
    // is no session"), so the text decides first — most importantly after a
    // long suspend, where the server-side lock expiry destroys the session
    // and unlock can never succeed: only a fresh login can.
    var noSession = combined.indexOf("no session") >= 0
        || combined.indexOf("authenticated client") >= 0
        || combined.indexOf("not logged") >= 0
        || combined.indexOf("session expired") >= 0
        || combined.indexOf("login required") >= 0

    if (noSession) {
      root.status = "logged-out"
      root.account = ""
      root.hasLockCode = false
      if (root.items.length > 0 || root.vaults.length > 0) {
        root.items = []
        root.vaults = []
        root.dataRevision++
      }
      return
    }

    if (exitCode !== 0) {
      console.log("ziouf.proton-pass/probe exit=" + exitCode +
                  " out=" + JSON.stringify(redact(out).slice(0, 120)) +
                  " err=" + JSON.stringify(redact(err).slice(0, 120)))
      if (combined.indexOf("lock") >= 0 && combined.indexOf("unlock") < 0) {
        root.status = "locked"
      } else if (combined.indexOf("log in") >= 0) {
        root.status = "logged-out"
        root.account = ""
      } else {
        // An unknown failure (offline, deadline, update pending…) keeps the
        // last known state rather than flapping the bar icon.
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
  property string walkKind: ""          // "vaults" | "items"
  property string currentWalkVault: ""

  property string processCapture: ""
  property string processErrCapture: ""

  Process {
    id: walkProcess
    running: false

    stdout: SplitParser {
      onRead: function(data) {
        if (root.processCapture.length < root.maxCaptureChars)
          root.processCapture += data + "\n"
      }
    }
    stderr: SplitParser {
      onRead: function(data) {
        if (root.processErrCapture.length < root.maxErrCaptureChars)
          root.processErrCapture += data + "\n"
      }
    }

    onExited: function(exitCode) { root.walkExited(exitCode) }
  }

  function refreshItems() {
    if (walkProcess.running) return
    root.itemsLoading = true
    root.itemAccumulator = []
    root.processCapture = ""
    root.processErrCapture = ""
    root.walkKind = "vaults"
    walkProcess.command = root.timed(root.walkLegDeadlineSec,
                                     ["pass-cli", "vault", "list", "--output", "json"])
    walkProcess.running = true
  }

  function walkExited(exitCode) {
    var output = String(root.processCapture)
    root.processCapture = ""
    var errText = String(root.processErrCapture)
    root.processErrCapture = ""

    console.log("ziouf.proton-pass/walk exit=" + exitCode +
                " itemRun=" + isItemListRun() +
                " pending=" + root.pendingVaults.length +
                " acc=" + root.itemAccumulator.length +
                " vaults=" + root.vaults.length)

    if (exitCode !== 0) {
      root.itemsLoading = false
      root.pendingVaults = []
      if (exitCode === 124 || errText.toLowerCase().indexOf("timed out") >= 0)
        console.warn("ziouf.proton-pass", "walk leg exceeded its deadline")
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

  // The walk reuses one Process for both command kinds; the timed() wrapper
  // shifts argv, so the kind is tracked explicitly instead of read back.
  function isItemListRun() {
    return root.walkKind === "items"
  }

  function runNextVault() {
    if (root.pendingVaults.length === 0) {
      root.publishItems()
      return
    }
    var vaultName = root.pendingVaults.shift()
    root.processCapture = ""
    root.processErrCapture = ""
    root.walkKind = "items"
    root.currentWalkVault = vaultName
    walkProcess.command = root.timed(root.walkLegDeadlineSec,
                                     ["pass-cli", "item", "list", vaultName, "--output", "json"])
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
    for (var i = 0; i < arr.length && names.length < root.maxVaults; i++) {
      var name = truncate(arr[i] && arr[i].name ? arr[i].name : "", 128).trim()
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
    var currentVault = String(root.currentWalkVault || "")
    for (var i = 0; i < arr.length; i++) {
      if (root.itemAccumulator.length >= root.maxItems) {
        console.warn("ziouf.proton-pass", "item cap reached, ignoring the rest")
        return
      }
      var raw = arr[i] || {}
      if (String(raw.state || "Active").toLowerCase() === "trashed") continue
      var title = truncate(raw.title, 256).trim()
      if (title === "") continue
      root.itemAccumulator.push({
        itemId: truncate(raw.id, 256),
        shareId: truncate(raw.share_id || raw.shareId, 256),
        vault: truncate(currentVault, 128),
        title: title,
        itemType: truncate(raw.item_type || raw.type, 32),
        hasTotp: undefined
      })
    }
  }

  function publishItems() {
    // Learned TOTP presence survives walks: match previous entries by id.
    var learned = {}
    for (var p = 0; p < root.items.length; p++) {
      var prev = root.items[p]
      if (prev.hasTotp !== undefined) learned[prev.itemId] = prev.hasTotp
    }
    var result = root.itemAccumulator.slice()
    for (var i = 0; i < result.length; i++) {
      if (learned[result[i].itemId] !== undefined)
        result[i].hasTotp = learned[result[i].itemId]
    }
    result.sort(function(a, b) { return a.title.localeCompare(b.title) })
    root.items = result
    root.dataRevision++
    root.itemsLoading = false
    writeCache()
  }

  // --------------------------------------------------------- item detail

  property string detailCapture: ""
  property string detailErrCapture: ""

  Process {
    id: detailProcess
    running: false

    stdout: SplitParser {
      onRead: function(data) {
        if (root.detailCapture.length < root.maxCaptureChars)
          root.detailCapture += data + "\n"
      }
    }
    stderr: SplitParser {
      onRead: function(data) {
        if (root.detailErrCapture.length < root.maxErrCaptureChars)
          root.detailErrCapture += data + "\n"
      }
    }

    onExited: function(exitCode) {
      root.detailLoading = false
      var capture = String(root.detailCapture)
      root.detailCapture = ""
      root.detailErrCapture = ""

      if (exitCode === 124) {
        root.detailError = root.tr("error.detailTimeout")
        return
      }
      if (exitCode !== 0) {
        root.detailError = root.tr("error.detailRead")
        return
      }
      root.parseDetail(capture)
    }
  }

  function loadDetail(item) {
    if (detailProcess.running) return
    root.currentItem = item
    root.detailFields = []
    root.detailError = ""
    root.detailLoading = true
    root.detailCapture = ""
    root.detailErrCapture = ""
    var vault = String(item.shareId || item.vault || "")
    var ref = String(item.itemId || item.title || "")
    detailProcess.command = root.timed(root.detailDeadlineSec,
                                       ["pass-cli", "item", "view", "--output", "json",
                                        "pass://" + vault + "/" + ref])
    detailProcess.running = true
  }

  // Drop decrypted material from memory (panel close, navigation away).
  function clearDetail() {
    detailProcess.command = []
    root.currentItem = null
    root.detailFields = []
    root.detailError = ""
    root.detailLoading = false
    root.detailCapture = ""
    root.detailErrCapture = ""
  }

  function prettifyKey(key) {
    // Known keys translate through the catalog; unknown ones fall back to a
    // capitalized raw name.
    var k = String(key || "").toLowerCase()
    if (k === "expirationdate") k = "expiration"
    if (k === "totp_uri") k = "totp"
    var translated = tr("field." + k)
    if (translated !== ("field." + k)) return translated
    return String(key || "").replace(/_/g, " ").replace(/^./, function(c) { return c.toUpperCase() })
  }

  function parseDetail(output) {
    var parsed = null
    try {
      parsed = JSON.parse(String(output || ""))
    } catch (e) {
      root.detailError = root.tr("error.detailParse")
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
      rows.push({ label: tr("field.note"), field: "", value: truncate(content.note, maxValueChars), hidden: false, multiline: true })
    }

    if (typeObj) {
      for (var f in typeObj) {
        if (rows.length >= root.maxDetailFields) {
          console.warn("ziouf.proton-pass", "detail field cap reached")
          break
        }
        var v = typeObj[f]
        if (v === null || v === undefined || v === "") continue
        if (Array.isArray(v)) {
          var strs = []
          for (var i = 0; i < v.length && strs.length < 8; i++)
            if (typeof v[i] === "string" && v[i] !== "") strs.push(truncate(v[i], 512))
          if (strs.length > 0)
            rows.push({ label: prettifyKey(f), field: truncate(f, 128), value: strs.join("\n"),
                        hidden: false, multiline: strs.join("\n").length > 48 })
        } else if (typeof v === "object") {
          continue
        } else if (f === "totp_uri") {
          rows.push({ label: tr("field.totp"), field: "totp", value: tr("totp.currentHint"),
                      hidden: false, multiline: false })
        } else {
          var rawText = String(v)
          var text = truncate(rawText, maxValueChars)
          var hiddenKey = /password|secret|cvv|private|pin/i.test(f)
          rows.push({ label: prettifyKey(f), field: truncate(f, 128), value: text,
                      hidden: hiddenKey, multiline: !hiddenKey && text.length > 48,
                      truncated: rawText.length > maxValueChars })
        }
      }
    }

    var extras = Array.isArray(content.extra_fields) ? content.extra_fields : []
    for (var e = 0; e < extras.length && rows.length < root.maxDetailFields; e++) {
      var extra = extras[e] || {}
      var label = truncate(extra.label || extra.name || tr("field.extraFallback"), 128)
      var value = ""
      if (extra.content !== undefined && extra.content !== null) value = String(extra.content)
      else if (extra.value !== undefined && extra.value !== null) value = String(extra.value)
      if (value === "") continue
      value = truncate(value, maxValueChars)
      var hiddenField = String(extra.type || "").toLowerCase() === "hidden"
      rows.push({ label: label, field: label, value: value,
                  hidden: hiddenField, multiline: !hiddenField && value.length > 48,
                  truncated: value.length >= maxValueChars })
    }

    root.detailFields = rows

    // Remember whether this item really carries a TOTP so list rows can stop
    // offering the action when it does not.
    var hasTotp = !!(typeObj && typeof typeObj.totp_uri === "string" && typeObj.totp_uri !== "")
    if (root.currentItem)
      setItemHasTotp(String(root.currentItem.itemId || root.currentItem.title || ""), hasTotp)
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
    // Single-slot runner: a request arriving while a copy is in flight is
    // queued and replayed on exit instead of being silently dropped.
    onExited: {
      if (root.pendingBufferCopy) {
        var queued = root.pendingBufferCopy
        root.pendingBufferCopy = null
        root.startBufferCopy(queued)
      }
    }
  }

  property var pendingBufferCopy: null

  function copyValue(label, value, hidden, timeoutSec) {
    if (!Quickshell.env("XDG_RUNTIME_DIR")) return
    var request = {
      label: truncate(label, 128),
      value: String(value === undefined || value === null ? "" : value),
      hidden: hidden === true,
      timeout: Math.max(0, Number(timeoutSec) || 0)
    }
    if (bufferCopyProcess.running) {
      pendingBufferCopy = request
      return
    }
    startBufferCopy(request)
  }

  function startBufferCopy(request) {
    bufferFile.setText(request.value)
    Qt.callLater(function() {
      var cmd = [scriptDir + "/copy-value", bufferPath,
                 request.label, request.hidden ? "secret" : "value",
                 String(request.timeout)]
      if (root.genericNotifications) cmd = ["env", "PASS_GENERIC_NOTIFY=1"].concat(cmd)
      bufferCopyProcess.command = root.timed(root.actionDeadlineSec, cmd)
      bufferCopyProcess.running = true
    })
  }

  // -------------------------------------------------------------- actions

  property string actionProcessLabel: ""
  property string actionField: ""
  property string actionItemId: ""

  Process {
    id: actionProcess
    running: false

    stderr: SplitParser {
      onRead: function(data) {
        if (data.length <= 4096) console.warn("ziouf.proton-pass/action", truncate(data, 512).trim())
      }
    }

    onExited: function(exitCode) {
      var label = root.actionProcessLabel
      var field = root.actionField
      var itemId = root.actionItemId
      root.actionProcessLabel = ""
      root.actionField = ""
      root.actionItemId = ""

      if (exitCode === 3 && field === "totp") {
        // pass-cli confirmed the item carries no TOTP: remember it so the
        // row stops offering the action.
        setItemHasTotp(itemId, false)
      } else if (exitCode === 0 && field === "totp") {
        setItemHasTotp(itemId, true)
      } else if (exitCode !== 0) {
        root.notify(tr("error.actionFailed"),
                    trFmt("notify.actionFailed", label, exitCode), "critical")
      }
      root.probeSession()
    }
  }

  function setItemHasTotp(itemId, value) {
    if (itemId === "") return
    var changed = false
    var next = []
    for (var i = 0; i < root.items.length; i++) {
      var entry = root.items[i]
      if (entry.itemId === itemId || (entry.itemId === "" && entry.title === itemId)) {
        var copy = Object.assign({}, entry, { hasTotp: value })
        next.push(copy)
        changed = true
      } else {
        next.push(entry)
      }
    }
    if (!changed) return
    root.items = next
    root.dataRevision++
  }

  function runAction(command, label) {
    if (actionProcess.running) return
    root.actionProcessLabel = label
    var cmd = root.timed(root.actionDeadlineSec, command)
    if (root.genericNotifications) cmd = ["env", "PASS_GENERIC_NOTIFY=1"].concat(cmd)
    actionProcess.command = cmd
    actionProcess.running = true
  }

  function lockSession() {
    runAction(["pass-cli", "session", "lock"], tr("notify.locking"))
  }

  function copyField(item, field) {
    // Prefer ids; fall back to titles when an entry lacks them. The URI form
    // pass://<vault>/<item>/<field> accepts both ids and titles.
    var vault = String(item.shareId || item.vault || "")
    var ref = String(item.itemId || item.title || "")
    root.actionField = field
    root.actionItemId = ref
    runAction([root.scriptDir + "/copy-secret", vault, ref, field,
               String(Math.max(0, root.clipboardTimeoutSec))],
              trFmt("notify.copyOf", field))
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

  // ------------------------------------------------------- metadata cache
  //
  // The picker and the panel both want items without waiting for a full
  // vault walk. pass-cache-update (systemd timer) and publishItems() keep
  // this file current; at startup we hydrate from it instantly, then the
  // regular walk replaces the data with live values.
  readonly property string cachePath: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache")
                                      + "/ziouf.proton-pass/items.json"

  FileView {
    id: cacheFile
    path: root.cachePath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.parseCache(text())
  }

  function parseCache(output) {
    var parsed = null
    try {
      parsed = JSON.parse(String(output || ""))
    } catch (e) {
      return
    }
    if (!parsed || !Array.isArray(parsed.items)) return

    var result = []
    for (var i = 0; i < parsed.items.length && result.length < root.maxItems; i++) {
      var raw = parsed.items[i] || {}
      var title = truncate(raw.title, 256).trim()
      if (title === "") continue
      result.push({
        itemId: truncate(raw.itemId, 256),
        shareId: truncate(raw.shareId, 256),
        vault: truncate(raw.vault, 128),
        title: title,
        itemType: truncate(raw.itemType, 32),
        hasTotp: undefined
      })
    }
    root.vaults = Array.isArray(parsed.vaults) ? parsed.vaults.slice(0, root.maxVaults) : []
    root.items = result
    root.dataRevision++
  }

  function writeCache() {
    var payload = {
      schemaVersion: 1,
      updatedAt: new Date().toISOString(),
      vaults: root.vaults,
      items: root.items
    }
    cacheFile.setText(JSON.stringify(payload))
  }

  Component.onCompleted: probeSession()
}
