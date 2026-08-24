import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons

import qs.Ui
import "I18n.js" as I18n

// Proton Pass bar widget: one icon, three-level panel. Vaults → typed items
// → field detail, each level reachable with a click and undone with the back
// button. The bar icon is a key whose dim state mirrors logged-out; right
// click locks the session immediately.

Panel {
  id: root
  moduleName: "ziouf.proton-pass"
  ipcTarget: "ziouf.proton-pass"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // The bar collapses any slot whose item reports no size, so the icon
  // button drives the root's geometry.
  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // ----------------------------------------------------------- navigation
  property string view: "vaults"          // vaults | items | detail
  property string currentVault: ""        // "" = all vaults
  property var currentItem: null
  property bool cursorActive: false
  property string query: ""
  property int selectedIndex: -1

  // System locale selects the UI language (LC_ALL > LC_MESSAGES > LANG >
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

  Main {
    id: pass
    settings: root.settings
  }

  // -------------------------------------------------------------- helpers

  readonly property var vaultRows: {
    var rows = [{ name: "", label: tr("vault.all"), count: pass.items.length }]
    for (var i = 0; i < pass.vaults.length; i++) {
      var name = String(pass.vaults[i])
      rows.push({ name: name, label: name, count: countForVault(name) })
    }
    return rows
  }

  function countForVault(name) {
    var n = 0
    for (var i = 0; i < pass.items.length; i++)
      if (pass.items[i].vault === name) n++
    return n
  }

  function filteredItems() {
    var q = query.trim().toLowerCase()
    var out = []
    for (var i = 0; i < pass.items.length; i++) {
      var item = pass.items[i]
      if (currentVault !== "" && item.vault !== currentVault) continue
      if (q !== "" && item.title.toLowerCase().indexOf(q) < 0) continue
      out.push(item)
    }
    return out
  }

  readonly property int maxRenderedItems: 120
  readonly property var filteredAll: filteredItems()
  // Rendering cap: the Repeater instantiates every delegate eagerly, so a
  // 365-item vault would build ~8 000 objects per view entry. Show the first
  // N sorted matches and tell the user to narrow the search beyond that.
  readonly property var visibleItems: filteredAll.length > maxRenderedItems
                                      ? filteredAll.slice(0, maxRenderedItems)
                                      : filteredAll
  readonly property int hiddenItemCount: filteredAll.length - visibleItems.length

  function clampIndex() {
    var model = view === "vaults" ? vaultRows : visibleItems
    var n = model.length
    if (n === 0) { selectedIndex = -1; return }
    if (selectedIndex < 0) selectedIndex = 0
    if (selectedIndex >= n) selectedIndex = n - 1
  }
  onVisibleItemsChanged: clampIndex()
  onVaultRowsChanged: clampIndex()
  onViewChanged: selectedIndex = 0
  onQueryChanged: selectedIndex = 0

  function moveCursor(delta) {
    cursorActive = true
    clampIndex()
    var model = view === "vaults" ? vaultRows : visibleItems
    var n = model.length
    if (n === 0) return
    var next = selectedIndex + delta
    selectedIndex = ((next % n) + n) % n
  }

  function activateRow(index) {
    clampIndex()
    var i = index >= 0 ? index : selectedIndex
    if (i < 0) return
    if (view === "vaults") {
      openVault(vaultRows[i].name)
    } else if (view === "items") {
      openDetail(visibleItems[i])
    }
  }

  function openVault(name) {
    currentVault = name
    query = ""
    cursorActive = false
    view = "items"
  }

  function openDetail(item) {
    cursorActive = false
    root.currentItem = item
    pass.loadDetail(item)
    view = "detail"
  }

  property string pendingOpenItemId: ""

  // Deep-link entry (pass-pick "detail" action, IPC): open the panel straight
  // onto an item's detail view. When the id is not in the loaded data yet
  // (fresh shell, walk in flight, session just restored), the navigation is
  // retried once the item list lands instead of leaving the panel on vaults.
  function openItemById(id) {
    var wanted = String(id || "")
    root.open()
    if (wanted === "") return
    for (var i = 0; i < pass.items.length; i++) {
      if (pass.items[i].itemId === wanted) {
        currentVault = ""
        openDetail(pass.items[i])
        pendingOpenItemId = ""
        return
      }
    }
    pendingOpenItemId = wanted
    refreshNow()
  }

  function goBack() {
    if (view === "detail") { view = "items"; pass.clearDetail() }
    else if (view === "items") { view = "vaults"; currentVault = ""; query = "" }
    else close()
  }

  function breadcrumb() {
    if (view === "vaults") return tr("nav.vaults")
    if (view === "items") return (currentVault === "" ? tr("vault.all") : currentVault)
    var title = currentItem ? currentItem.title : ""
    return (currentVault === "" ? tr("vault.allShort") : currentVault) + " › " + title
  }

  function copyFor(item, field) {
    pass.copyField(item, field)
  }

  function refreshNow(force) {
    pass.probeSession()
    if (pass.status === "unlocked") pass.refreshItems(force === true)
  }

  function statusIcon() {
    // Key glyph (FA key); dimmed when logged out.
    return "\uF084"
  }

  function statusLabel() {
    if (pass.status === "unlocked") return tr("status.unlocked")
    if (pass.status === "locked") return tr("status.locked")
    if (pass.status === "checking") return tr("status.checking")
    return tr("status.loggedOut")
  }

  function typeIcon(itemType) {
    var t = String(itemType || "").toLowerCase()
    if (t === "login") return "\uF090"           // sign-in
    if (t === "alias") return "\uF0E0"           // envelope
    if (t === "note") return "\uF15C"            // file-alt
    if (t === "credit_card" || t === "creditcard") return "\uF09D"  // credit card
    if (t === "identity") return "\uF2BD"        // user-circle
    if (t === "ssh_key" || t === "sshkey") return "\uF084"          // key
    if (t === "wifi") return "\uF1EB"            // wifi
    return "\uF29C"                              // question-circle
  }

  function typeLabel(itemType) {
    var t = String(itemType || "").toLowerCase()
    var key = { login: "login", alias: "alias", note: "note",
                credit_card: "credit_card", creditcard: "credit_card",
                identity: "identity", ssh_key: "ssh_key", sshkey: "ssh_key",
                wifi: "wifi" }[t]
    return key !== undefined ? tr("type." + key) : String(itemType || tr("type.other"))
  }

  onOpenedChanged: if (opened) {
    view = "vaults"
    currentVault = ""
    query = ""
    selectedIndex = 0
    cursorActive = false
    refreshNow(false)
    // Typing goes straight to the filter; the key catcher stays as a
    // fallback for when focus moves elsewhere.
    Qt.callLater(function() { searchField.forceActiveFocus() })
  } else {
    // Panel closed: drop decrypted detail material from memory and any
    // deferred deep-link navigation.
    pass.clearDetail()
    pendingOpenItemId = ""
  }

  Connections {
    target: pass
    function onDataRevisionChanged() {
      root.clampIndex()
      // Deferred deep-link: navigate as soon as the wanted item shows up.
      if (root.pendingOpenItemId !== "") {
        for (var i = 0; i < pass.items.length; i++) {
          if (pass.items[i].itemId === root.pendingOpenItemId) {
            var wanted = root.pendingOpenItemId
            root.pendingOpenItemId = ""
            currentVault = ""
            openDetail(pass.items[i])
            return
          }
        }
        // Walk finished without it (deleted, or no session): stop retrying.
        if (!pass.itemsLoading && pass.items.length > 0)
          root.pendingOpenItemId = ""
      }
    }
  }

  // ------------------------------------------------------------------ IPC

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function refresh(): string { root.refreshNow(true); return "ok" }
    function lock(): string { pass.lockSession(); return "ok" }
    function login(): string { pass.login(); return "ok" }
    function unlock(): string { pass.unlock(); return "ok" }
    function openItem(id: string): string { root.openItemById(id); return "ok" }
  }

  // ----------------------------------------------------------------- icon

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.statusIcon()
    dimmed: pass.status === "logged-out"
    tooltipText: "Proton Pass · " + root.statusLabel()
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) pass.lockSession()
      else if (buttonCode === Qt.MiddleButton) root.refreshNow()
      else root.toggle()
    }
  }

  // ---------------------------------------------------------------- panel

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onCloseRequested: root.close()
      onActivateRequested: root.refreshNow()
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.moveCursor(dy > 0 ? 1 : -1)
      }
      Keys.onReturnPressed: root.activateRow(-1)
      Keys.onEnterPressed: root.activateRow(-1)
      Keys.onBackPressed: root.goBack()

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          // ------------------------------------------------------- hero
          Row {
            width: parent.width
            spacing: Style.space(8)

            Button {
              id: backButton
              visible: root.view !== "vaults"
              text: "\uF104"                     // angle-left
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.body
              onClicked: root.goBack()
            }

            Column {
              width: parent.width - backButton.width - (root.view !== "vaults" ? parent.spacing : 0)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {

                  textFormat: Text.PlainText
                width: parent.width
                text: root.breadcrumb()
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                elide: Text.ElideMiddle
              }

              Text {

                  textFormat: Text.PlainText
                visible: root.view === "vaults"
                width: parent.width
                text: pass.account !== "" ? pass.account : root.statusLabel()
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }
          }

          // -------------------------------------------- status / actions
          Row {
            visible: root.view === "vaults"
            width: parent.width
            spacing: Style.space(8)

            Text {

                textFormat: Text.PlainText
              text: root.statusLabel()
              color: pass.status === "unlocked" ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              anchors.verticalCenter: parent.verticalCenter
              elide: Text.ElideRight
              width: parent.width - actionsRow.width - parent.spacing
            }

            Row {
              id: actionsRow
              spacing: Style.space(6)

              Button {
                // Without a session there is nothing to unlock — the Sign in
                // button next to it owns that state.
                visible: pass.status !== "logged-out"
                text: pass.status === "unlocked"
                      ? (pass.hasLockCode ? tr("action.lock") : tr("action.createLockCode"))
                      : tr("action.unlock")
                enabled: pass.status !== "checking" && pass.status !== "locked"
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                bordered: true
                onClicked: {
                  if (pass.status === "unlocked") {
                    if (pass.hasLockCode) pass.lockSession()
                    else pass.launchTerminal("pass-cli session create-lock --idle-timeout 900")
                  } else {
                    pass.unlock()
                  }
                }
              }

              Button {
                text: pass.status === "logged-out" ? tr("action.login") : tr("action.refresh")
                enabled: !pass.itemsLoading
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                onClicked: {
                  if (pass.status === "logged-out") pass.login()
                  else root.refreshNow(true)
                }
              }
            }
          }

          // ------------------------------------------------------ search
          TextField {
            id: searchField
            visible: root.view !== "detail"
            width: parent.width
            placeholderText: root.view === "items"
                             ? trFmt("search.filterIn", currentVault === "" ? tr("vault.all") : currentVault)
                             : tr("search.vaults")
            foreground: root.foreground
            // Reserve room for the reset button so long queries stay readable.
            rightPadding: horizontalPadding + Style.space(2)
                          + (resetButton.visible ? resetButton.width + Style.space(4) : 0)
            onTextChanged: root.query = text

            PanelActionButton {
              id: resetButton
              anchors.right: parent.right
              anchors.rightMargin: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter
              iconText: "\uF00D"                   // times
              foreground: root.dim
              hoverColor: root.foreground
              tooltipText: root.tr("search.reset")
              visible: searchField.text !== ""
              onClicked: {
                searchField.text = ""
                root.query = ""
                root.selectedIndex = 0
                searchField.forceActiveFocus()
              }
            }
            Keys.onDownPressed: root.moveCursor(1)
            Keys.onUpPressed: root.moveCursor(-1)
            Keys.onReturnPressed: root.activateRow(-1)
            Keys.onEnterPressed: root.activateRow(-1)
            Keys.onEscapePressed: root.close()
            // Backspace on an empty filter walks back up one level.
            Keys.onBackPressed: if (text === "") root.goBack()
          }

          // -------------------------------------------------- vault list
          Repeater {
            visible: root.view === "vaults"
            model: root.view === "vaults" ? root.vaultRows : []

            delegate: VaultRow {
              required property var modelData
              required property int index
              width: column.width
              row: modelData
              selected: root.cursorActive && index === root.selectedIndex
              onClicked: root.openVault(modelData.name)
            }
          }

          Text {

              textFormat: Text.PlainText
            visible: root.view === "vaults" && pass.vaults.length === 0 && !pass.itemsLoading
            width: parent.width
            text: pass.status === "unlocked"
                  ? tr("vault.noneAccessible")
                  : root.statusLabel() + " — " + tr("vault.hintLockedOrOut")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }

          Text {

              textFormat: Text.PlainText
            visible: root.view === "vaults" && pass.itemsLoading
            width: parent.width
            text: tr("vault.loading")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }

          // --------------------------------------------------- item list
          Repeater {
            visible: root.view === "items"
            model: root.view === "items" ? root.visibleItems : []

            delegate: ItemRow {
              required property var modelData
              required property int index
              width: column.width
              item: modelData
              showVault: root.currentVault === ""
              selected: root.cursorActive && index === root.selectedIndex
              onOpened: root.openDetail(modelData)
              onCopiedField: function(field) { root.copyFor(modelData, field) }
            }
          }

          Text {

              textFormat: Text.PlainText
            visible: root.view === "items" && root.visibleItems.length === 0 && !pass.itemsLoading
            width: parent.width
            topPadding: Style.space(8)
            text: pass.items.length === 0
                  ? tr("items.noneAtAll")
                  : tr("items.noneHere")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }

          Text {
            visible: root.view === "items" && root.hiddenItemCount > 0
            width: parent.width
            topPadding: Style.space(4)
            text: trFmt("items.hiddenCount", pass.items.length - root.visibleItems.length,
                        pass.items.length)
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }

          // ------------------------------------------------ detail view
          DetailView {
            visible: root.view === "detail"
            width: column.width
          }
        }
      }
    }
  }

  // ------------------------------------------------------------ components

  component VaultRow: Rectangle {
    id: vrow
    property var row: null
    property bool selected: false
    signal clicked()

    implicitHeight: Math.max(vname.implicitHeight, vcount.implicitHeight) + Style.space(14)
    radius: Style.cornerRadius
    color: vrow.selected || vhover.hovered ? Style.hoverFillFor(root.foreground, Color.accent)
                                           : "transparent"

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: vrow.clicked()
    }

    Text {

        textFormat: Text.PlainText
      id: vicon
      text: vrow.row && vrow.row.name === "" ? "\uF0C9" : "\uF114"   // list / folder
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      anchors.left: parent.left
      anchors.leftMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {

        textFormat: Text.PlainText
      id: vname
      text: vrow.row ? vrow.row.label : ""
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      anchors.left: vicon.right
      anchors.right: vcount.left
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      elide: Text.ElideRight
    }

    Text {

        textFormat: Text.PlainText
      id: vcount
      text: vrow.row ? String(vrow.row.count) : ""
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      anchors.right: parent.right
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
    }

    HoverHandler { id: vhover }
  }

  component ItemRow: Rectangle {
    id: row
    property var item: null
    property bool selected: false
    property bool showVault: false

    signal opened()
    signal copiedField(string field)

    implicitHeight: typeCol.implicitHeight + Style.space(10)
    radius: Style.cornerRadius
    color: row.selected ? Style.selectedFillFor(root.foreground, Color.accent)
                        : (rowHover.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent)
                                                  : "transparent")

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: row.opened()
    }

    Text {

        textFormat: Text.PlainText
      id: typeIconText
      text: root.typeIcon(row.item ? row.item.itemType : "")
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      anchors.left: parent.left
      anchors.leftMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
    }

    Column {
      id: typeCol
      anchors.left: typeIconText.right
      anchors.right: actionsCol.left
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(2)

      Text {

          textFormat: Text.PlainText
        id: titleText
        width: parent.width
        text: row.item ? row.item.title : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
      }

      Text {

          textFormat: Text.PlainText
        id: userText
        visible: text !== ""
        width: parent.width
        text: {
          if (!row.item) return ""
          var bits = [root.typeLabel(row.item.itemType)]
          if (showVault && row.item.vault !== "") bits.push(row.item.vault)
          return bits.join(" · ")
        }
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    Row {
      id: actionsCol
      anchors.right: parent.right
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(4)

      PanelActionButton {
        iconText: "\uE7FD"                       // person = username
        foreground: root.dim
        hoverColor: root.foreground
        tooltipText: root.tr("copy.username")
        visible: !!row.item && row.item.itemType === "login"
        onClicked: row.copiedField("username")
      }

      PanelActionButton {
        iconText: "\uF023"                       // lock = password
        foreground: root.dim
        hoverColor: root.foreground
        tooltipText: root.tr("copy.password")
        visible: !!row.item && row.item.itemType === "login"
        onClicked: row.copiedField("password")
      }

      PanelActionButton {
        iconText: "\uF021"                       // refresh = TOTP
        foreground: root.dim
        hoverColor: root.foreground
        tooltipText: root.tr("copy.totp")
        // Hidden once pass-cli confirmed the item carries no TOTP.
        visible: !!row.item && row.item.itemType === "login"
                 && pass.showTotp && row.item.hasTotp !== false
        onClicked: row.copiedField("totp")
      }
    }

    PanelToolTip {
      visible: rowHover.containsMouse && !!row.item && !actionsHoverHover()
      text: root.typeLabel(row.item ? row.item.itemType : "")
      fontFamily: root.fontFamily
    }

    function actionsHoverHover() { return false }

    MouseArea {
      id: rowHover
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
    }
  }

  component DetailView: Column {
    id: detail
    spacing: Style.space(6)

    Text {

        textFormat: Text.PlainText
      visible: pass.detailError !== ""
      width: parent.width
      text: pass.detailError
      color: root.urgent
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Text {

        textFormat: Text.PlainText
      visible: pass.detailLoading
      width: parent.width
      text: tr("detail.decrypting")
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Text {

        textFormat: Text.PlainText
      visible: !!root.currentItem && root.currentItem.itemType !== ""
      width: parent.width
      text: !!root.currentItem ? root.typeLabel(root.currentItem.itemType) : ""
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    Repeater {
      model: pass.detailFields

      delegate: FieldRow {
        required property var modelData
        width: detail.width
        field: modelData
        onCopied: root.copyFieldValue(modelData)
      }
    }

    Text {

        textFormat: Text.PlainText
      visible: !pass.detailLoading && pass.detailFields.length === 0 && pass.detailError === ""
      width: parent.width
      text: tr("detail.noFields")
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignHCenter
    }
  }

  component FieldRow: Rectangle {
    id: frow
    property var field: null
    signal copied()

    implicitHeight: fieldCol.implicitHeight + Style.space(12)
    radius: Style.cornerRadius
    color: fhover.hovered ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: frow.copied()
    }

    Column {
      id: fieldCol
      anchors.left: parent.left
      anchors.right: copyBtn.left
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(12)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(2)

      Text {

          textFormat: Text.PlainText
        width: parent.width
        text: frow.field ? frow.field.label : ""
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        elide: Text.ElideRight
      }

      Text {

          textFormat: Text.PlainText
        width: parent.width
        text: {
          if (!frow.field) return ""
          if (frow.field.hidden) return "••••••••"
          var v = String(frow.field.value || "")
          return v === "" ? tr("field.empty") : (v.length > 64 ? v.substring(0, 61) + "…" : v)
        }
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        visible: !(frow.field && frow.field.multiline && !frow.field.hidden)
      }

      Text {

          textFormat: Text.PlainText
        visible: !!frow.field && frow.field.multiline && !frow.field.hidden
        width: parent.width
        text: frow.field ? String(frow.field.value || "") : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WrapAnywhere
        maximumLineCount: 6
        elide: Text.ElideRight
      }
    }

    PanelActionButton {
      id: copyBtn
      iconText: "\uF0C5"                         // copy
      anchors.right: parent.right
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      foreground: root.dim
      hoverColor: root.foreground
      tooltipText: root.tr("field.copyValue")
      onClicked: frow.copied()
    }

    HoverHandler { id: fhover }
  }

  function copyFieldValue(field) {
    if (!field) return
    if (field.field === "totp" && currentItem) {
      copyFor(currentItem, "totp")
      return
    }
    // Oversized values are truncated in the model (resource caps): re-fetch
    // the field fresh so the clipboard copy stays complete. Extra fields
    // resolve by label in the pass:// URI.
    if (field.truncated === true && currentItem) {
      copyFor(currentItem, String(field.field || field.label || ""))
      return
    }
    pass.copyValue(String(field.label || field.field || "champ"),
                   String(field.value || ""),
                   field.hidden === true,
                   Number(Math.max(0, clipboardTimeout())))
  }

  function clipboardTimeout() {
    return pass.clipboardTimeoutSec
  }
}
