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

  // Create-secret popup state.
  property bool createOpen: false
  property string createVaultValue: ""

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

  // Match scoring for the filter: word-start beats prefix beats plain
  // substring beats vault/type-only match. Same-score ties keep model order.
  function matchScore(text, q) {
    var s = String(text || "").toLowerCase()
    if (q === "" || s === "") return 0
    var i = s.indexOf(q)
    if (i < 0) return 0
    if (i === 0) return 3
    if (" -_.@:/+-".indexOf(s.charAt(i - 1)) >= 0) return 2
    return 1
  }

  function filteredItems() {
    var q = query.trim().toLowerCase()
    var out = []
    for (var i = 0; i < pass.items.length; i++) {
      var item = pass.items[i]
      if (currentVault !== "" && item.vault !== currentVault) continue
      var score = 0
      if (q !== "") {
        score = matchScore(item.title, q)
        if (score === 0) score = Math.max(matchScore(item.vault, q),
                                          matchScore(typeLabel(item.itemType), q))
        if (score === 0) continue
      }
      out.push({ item: item, score: score })
    }
    if (q !== "")
      out.sort(function(a, b) { return b.score - a.score })
    return out.map(function(r) { return r.item })
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
  // Typing a filter arms the cursor on the top match: the launcher reflex,
  // type then Enter, without touching the arrows first.
  onQueryChanged: {
    selectedIndex = 0
    cursorActive = query.trim() !== ""
  }

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
    console.log("ziouf.proton-pass/openDetail view=detail item=" +
                JSON.stringify(item ? item.title : ""))
  }

  property string pendingOpenItemId: ""

  // Deep-link entry (pass-pick "detail" action, IPC): open the panel straight
  // onto an item's detail view. When the id is not in the loaded data yet
  // (fresh shell, walk in flight, session just restored), the navigation is
  // retried once the item list lands instead of leaving the panel on vaults.
  function openItemById(id) {
    var wanted = String(id || "")
    console.log("ziouf.proton-pass/openItem id.len=" + wanted.length +
                " items=" + pass.items.length + " opened=" + opened)
    root.open()
    if (wanted === "") return
    for (var i = 0; i < pass.items.length; i++) {
      if (pass.items[i].itemId === wanted) {
        console.log("ziouf.proton-pass/openItem found → detail")
        currentVault = ""
        openDetail(pass.items[i])
        pendingOpenItemId = ""
        return
      }
    }
    console.log("ziouf.proton-pass/openItem NOT found yet → refresh + retry")
    pendingOpenItemId = wanted
    refreshNow()
  }

  function goBack() {
    if (view === "detail") { view = "items"; pass.clearDetail() }
    else if (view === "items") { view = "vaults"; currentVault = ""; query = "" }
    else close()
  }

  function heroTitle() {
    if (view === "vaults") return tr("nav.brand")
    if (view === "items") return currentVault === "" ? tr("vault.all") : currentVault
    return currentItem ? currentItem.title : ""
  }

  // Meta line under the hero: the account at the root, the containing vault
  // on a detail view.
  function heroMeta() {
    if (view === "vaults") return pass.account !== "" ? pass.account : root.statusLabel()
    if (view === "detail") return currentVault === "" ? tr("vault.all") : currentVault
    return ""
  }

  function copyFor(item, field) {
    pass.copyField(item, field)
  }

  // Shift+Enter on the highlighted row: copy its password without entering
  // the detail view (item view only; logins only).
  function quickCopyPassword() {
    if (view !== "items") return
    clampIndex()
    if (selectedIndex < 0) return
    var item = visibleItems[selectedIndex]
    if (item && item.itemType === "login") copyFor(item, "password")
  }

  function refreshNow(force) {
    pass.probeSession()
    if (pass.status === "unlocked") pass.refreshItems(force === true)
  }

  function openCreatePopup() {
    root.createVaultValue = root.currentVault !== ""
                           ? root.currentVault
                           : (pass.vaults.length > 0 ? String(pass.vaults[0]) : "")
    createTitleField.text = ""
    createUsernameField.text = ""
    createPasswordField.text = ""
    root.createOpen = true
    Qt.callLater(function() { createTitleField.forceActiveFocus() })
  }

  function closeCreatePopup() {
    root.createOpen = false
    Qt.callLater(function() { searchField.forceActiveFocus() })
  }

  function submitCreateForm() {
    var vault = root.createVaultValue
    var title = createTitleField.text.trim()
    if (vault === "" || title === "") return
    // Password travels in the tmpfs template buffer, never in argv.
    var template = {
      title: title,
      username: createUsernameField.text.trim() || null,
      email: null,
      password: createPasswordField.text || null,
      totp_uri: null,
      urls: []
    }
    pass.submitCreate(vault, JSON.stringify(template), createPasswordField.text === "")
  }

  function statusIcon() {
    // Key glyph (FA key); locked sessions show a padlock; dimming is
    // reserved for logged-out (handled by the icon's dimmed binding).
    if (pass.status === "locked") return "\uF023"
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

  // Opening from the keyboard should mean typing right away.
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
    function onCreateDoneChanged() {
      if (pass.createDone) root.closeCreatePopup()
    }
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
    // While the create popup is open the panel grows to fit the card, so a
    // short list view never clips the form.
    contentHeight: panel.fittedContentHeight(
      root.createOpen ? Math.max(column.implicitHeight, createCard.height + Style.space(16))
                      : column.implicitHeight,
      Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onCloseRequested: root.close()
      onActivateRequested: root.refreshNow()
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.moveCursor(dy > 0 ? 1 : -1)
      }
      Keys.onReturnPressed: if (event.modifiers & Qt.ShiftModifier) root.quickCopyPassword(); else root.activateRow(-1)
      Keys.onEnterPressed: if (event.modifiers & Qt.ShiftModifier) root.quickCopyPassword(); else root.activateRow(-1)
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
              text: "\uF104"
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.body
              onClicked: root.goBack()
            }

            // Scope bridge: inside PanelHero's iconComponent, `root` resolves
            // to PanelHero itself (not this Panel) — expose what the hero
            // slot needs via `hero`, like first-party panels.
            Item {
              id: hero
              visible: false
              readonly property bool isVaults: root.view === "vaults"
              readonly property bool isItems: root.view === "items"
              readonly property var currentItem: root.currentItem
              readonly property color foreground: root.foreground
              readonly property color dim: root.dim
              readonly property string fontFamily: root.fontFamily
              readonly property string heroTitleText: root.heroTitle()
              readonly property string heroMetaText: root.heroMeta()
              function typeIcon(t) { return root.typeIcon(t) }
            }

            PanelHero {
              width: Math.max(0, parent.width - (backButton.visible ? backButton.width + parent.spacing : 0))
              iconComponent: Component {
                Text {
                  textFormat: Text.PlainText
                  text: hero.isVaults ? "\uF084"
                      : hero.isItems ? "\uF114"
                      : hero.typeIcon(hero.currentItem ? hero.currentItem.itemType : "")
                  color: hero.dim
                  font.family: hero.fontFamily
                  font.pixelSize: Style.font.display
                }
              }
              title: hero.heroTitleText
              meta: hero.heroMetaText
              foreground: hero.foreground
              fontFamily: hero.fontFamily
            }
          }

          // --------------------------------------------- search toolbar
          // Actions live next to the filter, not in PanelHero.trailingControl:
          // the hero centers its trailing slot on title+meta, which left the
          // icons floating on the interline. Against this single-line row the
          // 22px buttons center exactly.
          Item {
            width: parent.width
            implicitHeight: Math.max(searchField.visible ? searchField.implicitHeight : 0,
                                     actionButtons.height)

            TextField {
              id: searchField
              visible: root.view !== "detail"
              anchors.left: parent.left
              anchors.right: actionButtons.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
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
              Keys.onReturnPressed: if (event.modifiers & Qt.ShiftModifier) root.quickCopyPassword(); else root.activateRow(-1)
              Keys.onEnterPressed: if (event.modifiers & Qt.ShiftModifier) root.quickCopyPassword(); else root.activateRow(-1)
              Keys.onEscapePressed: root.close()
              // Backspace on an empty filter walks back up one level.
              Keys.onBackPressed: if (text === "") root.goBack()
            }

            Row {
              id: actionButtons
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(8)

              PanelActionButton {
                iconText: "\uF067"                   // plus = new secret
                visible: pass.status !== "logged-out"
                foreground: root.dim
                hoverColor: root.foreground
                tooltipText: root.tr("header.newSecret")
                onClicked: root.openCreatePopup()
              }

              PanelActionButton {
                iconText: "\uF021"                   // refresh
                visible: pass.status !== "logged-out"
                enabled: !pass.itemsLoading
                foreground: root.dim
                hoverColor: root.foreground
                tooltipText: root.tr("action.refresh")
                onClicked: root.refreshNow(true)
              }

              PanelActionButton {
                iconText: "\uF09C"                   // unlock
                visible: pass.status === "locked"
                foreground: root.dim
                hoverColor: root.foreground
                tooltipText: root.tr("action.unlock")
                onClicked: pass.unlock()
              }

              PanelActionButton {
                iconText: "\uF023"                   // login
                visible: pass.status === "logged-out"
                foreground: root.dim
                hoverColor: root.foreground
                tooltipText: root.tr("action.login")
                onClicked: pass.login()
              }
            }
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
            text: trFmt("items.hiddenCount", root.visibleItems.length,
                        root.filteredAll.length)
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

          // Keyboard hints, launcher style, on the search level.
          Text {
            textFormat: Text.PlainText
            visible: root.view === "items"
            width: parent.width
            topPadding: Style.space(6)
            text: root.tr("hints.itemsLine")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }

      // ---------------------------------------------------- create popup
      // Modal card over the panel content. No dim overlay: a translucent
      // fill on the keyboard-panel layer breaks text rendering shell-wide
      // (every Text on the layer stops painting while it is visible).
      Rectangle {
        id: createOverlay
        visible: root.createOpen
        anchors.fill: parent
        z: 50
        color: "transparent"

        // Click outside the card cancels.
        MouseArea {
          anchors.fill: parent
          onClicked: root.closeCreatePopup()
        }

        BorderSurface {
          id: createCard
          anchors.centerIn: parent
          width: Math.min(parent.width - Style.space(24), Style.space(320))
          // The Column inside uses anchors.fill, so it cannot drive the
          // card's size: the height must come from the content instead.
          height: cardColumn.implicitHeight + Style.space(32)
          radius: Style.cornerRadius
          color: Color.popups.background
          borderSpec: Border.localOrSurfaceSpec("popups", "border",
                                                Color.popups.border,
                                                Color.popups.border, 1)

          Column {
            id: cardColumn
            anchors.fill: parent
            anchors.margins: Style.space(16)
            spacing: Style.space(10)

            Text {
              text: root.tr("create.title")
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Dropdown {

              width: parent.width
              label: root.tr("create.vault")
              options: pass.vaults
              value: root.createVaultValue
              foreground: root.foreground
              fontFamily: root.fontFamily
              onChanged: function(v) { root.createVaultValue = v }
            }

            TextField {
              id: createTitleField
              width: parent.width
              placeholderText: root.tr("create.titleField")
              foreground: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              activeFocusOnTab: true
              Keys.onReturnPressed: root.submitCreateForm()
              Keys.onEnterPressed: root.submitCreateForm()
              Keys.onEscapePressed: root.closeCreatePopup()
            }

            TextField {
              id: createUsernameField
              width: parent.width
              placeholderText: root.tr("create.username")
              foreground: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              activeFocusOnTab: true
              Keys.onReturnPressed: root.submitCreateForm()
              Keys.onEnterPressed: root.submitCreateForm()
              Keys.onEscapePressed: root.closeCreatePopup()
            }

            TextField {
              id: createPasswordField
              width: parent.width
              placeholderText: root.tr("create.password")
              foreground: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              password: true
              activeFocusOnTab: true
              Keys.onReturnPressed: root.submitCreateForm()
              Keys.onEnterPressed: root.submitCreateForm()
              Keys.onEscapePressed: root.closeCreatePopup()
            }

            Text {
              visible: pass.createError !== ""
              width: parent.width
              text: pass.createError
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Row {
              width: parent.width
              layoutDirection: Qt.RightToLeft
              spacing: Style.space(8)

              Button {
                text: pass.createRunning ? root.tr("create.creating") : root.tr("create.confirm")
                enabled: !pass.createRunning
                         && root.createVaultValue !== ""
                         && createTitleField.text.trim() !== ""
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                bordered: true
                onClicked: root.submitCreateForm()
              }

              Button {
                text: root.tr("create.cancel")
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                bordered: true
                onClicked: root.closeCreatePopup()
              }
            }
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
    // Optimistic copy feedback: the check shows on click; failures already
    // raise a critical notification through the action pipeline.
    property bool justCopied: false

    signal opened()
    signal copiedField(string field)

    Timer {
      id: copyFlash
      interval: 1500
      onTriggered: row.justCopied = false
    }

    function flashCopied() { justCopied = true; copyFlash.restart() }

    implicitHeight: typeCol.implicitHeight + Style.space(10)
    radius: Style.cornerRadius
    color: row.selected ? Style.selectedFillFor(root.foreground, Color.accent)
                        : (rowHover.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent)
                                                  : "transparent")

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      onClicked: function(mouse) {
        // Quick-copy shortcuts on login rows, like the desktop app.
        if (row.item && row.item.itemType === "login"
            && (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton)) {
          row.flashCopied()
          row.copiedField(mouse.button === Qt.MiddleButton ? "password" : "username")
          return
        }
        row.opened()
      }
    }

    Text {

        textFormat: Text.PlainText
      id: typeIconText
      text: row.justCopied ? "\uF00C" : root.typeIcon(row.item ? row.item.itemType : "")
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
        onClicked: { row.flashCopied(); row.copiedField("username") }
      }

      PanelActionButton {
        iconText: "\uF023"                       // lock = password
        foreground: root.dim
        hoverColor: root.foreground
        tooltipText: root.tr("copy.password")
        visible: !!row.item && row.item.itemType === "login"
        onClicked: { row.flashCopied(); row.copiedField("password") }
      }

      PanelActionButton {
        iconText: "\uF021"                       // refresh = TOTP
        foreground: root.dim
        hoverColor: root.foreground
        tooltipText: root.tr("copy.totp")
        // Hidden once pass-cli confirmed the item carries no TOTP.
        visible: !!row.item && row.item.itemType === "login"
                 && pass.showTotp && row.item.hasTotp !== false
        onClicked: { row.flashCopied(); row.copiedField("totp") }
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
    property bool justCopied: false
    signal copied()

    Timer {
      id: fcopyFlash
      interval: 1500
      onTriggered: frow.justCopied = false
    }

    function flashCopied() { justCopied = true; fcopyFlash.restart() }

    implicitHeight: fieldCol.implicitHeight + Style.space(12)
    radius: Style.cornerRadius
    color: fhover.hovered ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: { frow.flashCopied(); frow.copied() }
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
      iconText: frow.justCopied ? "\uF00C" : "\uF0C5"   // check / copy
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
