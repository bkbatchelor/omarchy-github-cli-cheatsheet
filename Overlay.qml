import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "GhCommandSearch.js" as GhCommandSearch

Item {
  id: root

  property string moduleName: "io.github.bkbatchelor.omarchy-github-cli-cheatsheet"
  property string pluginDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/" + moduleName
  property var shell: null
  property var manifest: null

  property bool opened: false
  property bool loading: false
  property string errorText: ""
  property string filterText: ""
  property int selectedIndex: 0
  property bool cursorActive: false
  property var commands: []

  // Shares the [menu] surface tokens so themes that style the Omarchy menu
  // style this picker too.
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int contentSpacing: Style.spacing.md
  property int cardWidth: Math.min(Style.space(900), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Math.round(panel.height * 0.6), panel.height - Style.gapsOut * 2)
  property int rowHeight: Math.max(Style.space(30), Style.font.body + Style.spacing.controlPaddingY * 2)
  property int sectionHeight: Math.max(Style.space(30), Style.font.caption + Style.spacing.lg * 2)
  property int commandColumnWidth: Math.round((cardWidth - contentMargin * 2) * 0.4)

  function open(payloadJson) {
    root.opened = true
    root.filterText = ""
    root.selectedIndex = 0
    root.cursorActive = true
    root.rebuildDisplay()
    root.loadIndex()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || root.moduleName)
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function loadIndex() {
    if (indexProc.running) return
    root.loading = root.commands.length === 0
    indexProc.running = true
  }

  function applyIndex(raw) {
    var parsed = GhCommandSearch.parseIndex(raw)
    root.loading = false
    root.errorText = parsed.error
    root.commands = parsed.items
    root.rebuildDisplay()
  }

  function rebuildDisplay() {
    var out = GhCommandSearch.filterCommands(root.commands, root.filterText)

    displayModel.clear()
    for (var i = 0; i < out.length; i++) {
      displayModel.append({
        category: String(out[i].category || ""),
        command: String(out[i].command || ""),
        description: String(out[i].description || "")
      })
    }

    if (displayModel.count === 0) selectedIndex = 0
    else if (selectedIndex >= displayModel.count) selectedIndex = displayModel.count - 1
    else if (selectedIndex < 0) selectedIndex = 0
    cursorActive = displayModel.count > 0

    pointerGate.reset()
    Qt.callLater(function() { root.revealSelected() })
  }

  function revealSelected() {
    if (displayModel.count === 0) return
    // Show the category header when the first row of a section is selected.
    if (selectedIndex === 0) resultList.positionViewAtBeginning()
    else resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  // Hover only moves the selection after a real pointer move, so rows
  // scrolling under a stationary pointer don't steal keyboard selection.
  function selectFromPointer(index, item, mouse) {
    if (!pointerGate.moved(item, mouse)) return
    root.cursorActive = true
    root.selectedIndex = index
  }

  function moveTo(index) {
    if (displayModel.count === 0) return
    pointerGate.reset()
    cursorActive = true
    selectedIndex = Math.max(0, Math.min(displayModel.count - 1, index))
    revealSelected()
  }

  function select(delta) {
    if (displayModel.count === 0) return
    if (!cursorActive) moveTo(delta < 0 ? displayModel.count - 1 : 0)
    else moveTo((selectedIndex + delta + displayModel.count) % displayModel.count)
  }

  function selectPage(delta) {
    var visibleRows = Math.max(1, Math.floor(resultList.height / rowHeight) - 1)
    moveTo(selectedIndex + delta * visibleRows)
  }

  // Jump to the first command of the next or previous category.
  function selectCategory(delta) {
    if (displayModel.count === 0) return
    var current = displayModel.get(selectedIndex).category
    var i = selectedIndex

    if (delta > 0) {
      while (i < displayModel.count && displayModel.get(i).category === current) i++
      moveTo(i < displayModel.count ? i : 0)
    } else {
      while (i > 0 && displayModel.get(i - 1).category === current) i--
      if (i === 0) i = displayModel.count
      var previous = displayModel.get(i - 1).category
      while (i > 0 && displayModel.get(i - 1).category === previous) i--
      moveTo(i)
    }
  }

  function setFilter(nextFilter) {
    root.filterText = nextFilter
    root.selectedIndex = 0
    root.cursorActive = true
    root.rebuildDisplay()
  }

  function activateIndex(index) {
    if (index < 0 || index >= displayModel.count) return
    root.applySelected(displayModel.get(index).command)
  }

  // Types the command followed by a space, without pressing Enter, so
  // arguments can be added before running it.
  function applySelected(command) {
    if (!command) return
    root.dismiss()
    Quickshell.execDetached([root.pluginDir + "/bin/gh-cheatsheet-insert", command + " "])
  }

  ListModel { id: displayModel }

  PointerMoveGate {
    id: pointerGate
    referenceItem: card
  }

  Process {
    id: indexProc
    command: [root.pluginDir + "/bin/gh-cheatsheet-index"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyIndex(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && root.commands.length === 0) {
        root.loading = false
        root.errorText = "Could not build the gh command index"
      }
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-github-cli-cheatsheet"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (root.filterText) root.setFilter("")
            else root.dismiss()
            event.accepted = true
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            root.select(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            root.select(1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageUp) {
            root.selectPage(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageDown) {
            root.selectPage(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Backtab) {
            root.selectCategory(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Tab) {
            root.selectCategory((event.modifiers & Qt.ShiftModifier) ? -1 : 1)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.cursorActive) root.activateIndex(root.selectedIndex)
            else if (displayModel.count > 0) root.cursorActive = true
            event.accepted = true
          } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
            root.setFilter(root.filterText + event.text)
            event.accepted = true
          }
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        Item {
          width: parent.width
          height: root.headerHeight

          Text {
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.right: countLabel.left
            anchors.rightMargin: root.contentSpacing
            anchors.verticalCenter: parent.verticalCenter
            text: root.filterText || "Search GitHub CLI commands…"
            color: root.foreground
            opacity: root.filterText ? 1 : 0.58
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            elide: Text.ElideRight
          }

          Text {
            id: countLabel
            textFormat: Text.PlainText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.commands.length > 0 ? displayModel.count + " / " + root.commands.length : ""
            color: root.foreground
            opacity: 0.5
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        Item {
          width: parent.width
          height: parent.height - root.headerHeight - root.contentSpacing

          ListView {
            id: resultList
            anchors.fill: parent
            model: displayModel
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            section.property: "category"
            section.criteria: ViewSection.FullString
            section.delegate: Item {
              required property string section

              width: ListView.view.width
              height: root.sectionHeight

              Text {
                textFormat: Text.PlainText
                anchors.left: parent.left
                anchors.leftMargin: Style.spacing.rowPaddingX
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Style.spacing.sm
                text: parent.section
                color: root.selectedText
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: root.foreground
                opacity: 0.3
              }
            }

            delegate: Rectangle {
              required property int index
              required property string command
              required property string description

              readonly property bool hasCursor: root.cursorActive && index === root.selectedIndex

              width: ListView.view.width
              height: root.rowHeight
              radius: root.cornerRadius
              color: hasCursor ? root.selectedBackground : "transparent"

              Text {
                id: commandText
                textFormat: Text.PlainText
                anchors.left: parent.left
                anchors.leftMargin: Style.spacing.rowPaddingX
                anchors.verticalCenter: parent.verticalCenter
                width: root.commandColumnWidth
                text: parent.command
                color: parent.hasCursor ? root.selectedText : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
              }

              Text {
                textFormat: Text.PlainText
                anchors.left: commandText.right
                anchors.leftMargin: Style.spacing.controlGap
                anchors.right: parent.right
                anchors.rightMargin: Style.spacing.rowPaddingX
                anchors.verticalCenter: parent.verticalCenter
                text: parent.description
                color: root.foreground
                opacity: parent.hasCursor ? 0.85 : 0.6
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: function(mouse) { root.selectFromPointer(parent.index, this, mouse) }
                onClicked: root.activateIndex(parent.index)
              }
            }
          }

          Column {
            anchors.centerIn: parent
            spacing: Style.space(8)
            visible: displayModel.count === 0

            Text {
              text: root.loading ? "󰔟" : (root.errorText ? "󰅚" : "󰈉")
              color: root.selectedText
              opacity: 0.8
              font.family: root.fontFamily
              font.pixelSize: Style.font.displayLarge
              horizontalAlignment: Text.AlignHCenter
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: root.loading ? "Loading gh commands…"
                : root.errorText ? root.errorText
                : "No matches for “" + root.filterText + "”"
              color: root.foreground
              opacity: 0.7
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              horizontalAlignment: Text.AlignHCenter
              width: parent.width
            }
          }
        }
      }
    }
  }
}
