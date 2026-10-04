import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
    id: root
    moduleName: "io.github.qempexe.omadrawers"
    manageIpc: false

    // Injected by BarWidget.qml
    property var anchorItem: null
    property var hostWidget: null
    property string drawerKey: ""

    // Editor state (d* = drawer editor)
    property string dGlyph: ""
    property var dChoices: []
    property var dSelected: []
    property bool dFound: false
    property bool dBusy: false
    property bool dConfirm: false
    property int dOrigCount: 0
    property int dDrawerCount: 1
    readonly property bool dCanRemove: root.dOrigCount > 0 || root.dDrawerCount > 1
    property string dError: ""

    readonly property color fg: root.barForeground
    readonly property string fontFamily: root.bar && root.bar.fontFamily
        ? String(root.bar.fontFamily) : Style.font.family

    readonly property string dHelper: {
        var url = Qt.resolvedUrl("bin/omarchy-drawers").toString()
        if (url.indexOf("file://") === 0) return decodeURIComponent(url.slice(7))
        return decodeURIComponent(url)
    }

    readonly property var dIcons: [
        "\uf141", "\uf142", "\uf0c9", "\uf00a", "\uf013", "\uf0ad", "\uf025", "\uf001",
        "\uf1eb", "\uf294", "\uf108", "\uf120", "\uf121", "\uf004", "\uf005", "\uf0e7",
        "\uf132", "\uf06e", "\uf07b", "\uf11b", "\uf2db", "\uf1e6", "\uf1c0", "\uf0c2",
        "\uf053", "\uf104", "\uf100", "\uf0e0", "\uf075", "\uf0f3"
    ]

    function open() {
        root.controller.show()
    }

    function close() {
        root.controller.hide()
    }

    function switchPanel(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
            return root.bar.switchPanelFrom(root.hostWidget || root, direction)
        return false
    }

    onOpenedChanged: {
        if (root.opened) root.dReload()
    }

    function labelFor(id) {
        var s = String(id || "")
        var parts = s.split(".")
        var last = parts[parts.length - 1] || s
        last = last.replace(/[-_]/g, " ")
        return last.charAt(0).toUpperCase() + last.slice(1)
    }

    function isSelected(id) {
        return root.dSelected.indexOf(id) >= 0
    }

    function dToggle(id) {
        var next = root.dSelected.slice()
        var i = next.indexOf(id)
        if (i >= 0) next.splice(i, 1)
        else next.push(id)
        root.dSelected = next
    }

    function dMove(from, to) {
        var n = root.dSelected.length
        if (from < 0 || from >= n) return
        to = Math.max(0, Math.min(n - 1, to))
        if (to === from) return
        var next = root.dSelected.slice()
        var moved = next.splice(from, 1)[0]
        next.splice(to, 0, moved)
        root.dSelected = next
    }

    function dReload() {
        root.dError = ""
        root.dConfirm = false
        confirmTimer.stop()
        root.dBusy = false
        describeProc.command = ["bash", root.dHelper, "describe", "--key", root.drawerKey]
        describeProc.running = true
    }

    function dParse(text) {
        var raw = String(text || "").trim()
        var data = null
        try { data = JSON.parse(raw) } catch (e) { data = null }
        if (!data) {
            root.dFound = false
            root.dError = raw === ""
                ? "The helper printed nothing."
                : "Could not parse helper output. Got: " + raw.substring(0, 300)
            return
        }
        root.dFound = true
        root.dGlyph = data.glyph || "\uf141"
        var items = data.items || []
        var avail = data.available || []
        var all = items.slice()
        for (var i = 0; i < avail.length; i++)
            if (all.indexOf(avail[i]) < 0) all.push(avail[i])
        root.dChoices = all
        root.dSelected = items.slice()
        root.dOrigCount = items.length
        root.dDrawerCount = data.drawers || 1
        nameInput.text = data.name || "Drawer"
        Qt.callLater(function() {
            nameInput.forceActiveFocus()
            nameInput.selectAll()
        })
    }

    function dRun(args) {
        root.dBusy = true
        root.dError = ""
        applyProc.command = ["bash", root.dHelper].concat(args)
        applyProc.running = true
    }

    function dSave() {
        if (root.dBusy || !root.dFound) return
        var name = String(nameInput.text || "").trim()
        if (name === "") name = "Drawer"
        root.dRun(["configure", "--key", root.drawerKey, "--name", name,
                   "--icon", root.dGlyph || "\uf141",
                   "--widgets", root.dSelected.join(",")])
    }

    function dAddBlank() {
        if (root.dBusy || !root.dFound) return
        root.dRun(["add-blank", "--after", root.drawerKey])
    }

    function dReset() {
        if (root.dBusy || !root.dFound) return
        root.dRun(["configure", "--key", root.drawerKey, "--name", "Drawer",
                   "--icon", "\uf141", "--widgets", ""])
    }

    function dDelete() {
        if (root.dBusy || !root.dFound) return
        root.dRun(["delete", "--key", root.drawerKey])
    }

    // Move this exact drawer one slot earlier / later in its bar section,
    // matched by key so the wrong drawer can never be moved.
    function dMoveEarlier() {
        if (root.dBusy || !root.dFound) return
        root.dRun(["reorder", "--key", root.drawerKey, "--before"])
    }

    function dMoveLater() {
        if (root.dBusy || !root.dFound) return
        root.dRun(["reorder", "--key", root.drawerKey, "--after"])
    }

    Process {
        id: describeProc
        stdout: StdioCollector { id: describeOut }
        stderr: StdioCollector { id: describeErr }
        onExited: function(exitCode) {
            var out = String(describeOut.text || "").trim()
            var err = String(describeErr.text || "").trim()
            if (exitCode === 0 && out !== "") {
                root.dParse(out)
            } else {
                root.dFound = false
                root.dError = "helper: " + root.dHelper
                    + "\nkey: " + root.drawerKey
                    + "\nexit: " + exitCode
                    + (err !== "" ? "\nstderr: " + err : "")
                    + (out !== "" ? "\nstdout: " + out.substring(0, 200) : "")
            }
        }
    }

    Process {
        id: applyProc
        stdout: StdioCollector { id: applyOut }
        stderr: StdioCollector { id: applyErr }
        onExited: function(exitCode, exitStatus) {
            Qt.callLater(function() {
                root.dBusy = false
                if (exitCode === 0) {
                    var svc = root.bar && root.bar.shell
                        ? root.bar.shell.serviceFor(root.moduleName) : null
                    if (svc && typeof svc.notifyDrawerSettings === "function") {
                        var base = root.hostWidget && root.hostWidget.settings
                            ? root.hostWidget.settings : ({})
                        var merged = ({})
                        for (var k in base) merged[k] = base[k]
                        merged.name = String(nameInput.text || "").trim() || "Drawer"
                        merged.glyph = root.dGlyph || "\uf141"
                        merged.items = root.dSelected.slice()
                        svc.notifyDrawerSettings(root.drawerKey, merged)
                    }
                    root.close()
                } else {
                    var out = String(applyOut.text || "").trim()
                    var err = String(applyErr.text || "").trim()
                    root.dError = "helper: " + root.dHelper
                        + "\nexit: " + exitCode
                        + (err !== "" ? "\nstderr: " + err : "")
                        + (out !== "" ? "\nstdout: " + out.substring(0, 200) : "")
                }
            })
        }
    }

    Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: root.dConfirm = false
    }

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(480))
        contentHeight: panel.fittedContentHeight(content.implicitHeight + Style.space(4))

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.close()
            onTabRequested: function(direction) { root.switchPanel(direction) }

            Column {
                id: content
                width: parent.width
                spacing: Style.space(10)

                Text {
                    width: parent.width
                    text: "Drawer"
                    color: root.fg
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                }

                Rectangle {
                    width: parent.width
                    height: Style.space(32)
                    radius: Style.space(6)
                    color: Qt.alpha(root.fg, 0.08)
                    border.width: nameInput.activeFocus ? 1 : 0
                    border.color: Qt.alpha(root.fg, 0.45)

                    TextInput {
                        id: nameInput
                        anchors.fill: parent
                        anchors.leftMargin: Style.space(10)
                        anchors.rightMargin: Style.space(10)
                        verticalAlignment: TextInput.AlignVCenter
                        color: root.fg
                        selectionColor: Qt.alpha(root.fg, 0.35)
                        selectedTextColor: root.fg
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(14)
                        maximumLength: 32
                        clip: true
                        selectByMouse: true
                        onAccepted: root.dSave()
                        Keys.onEscapePressed: root.close()

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: nameInput.text.length === 0
                            text: "Drawer name"
                            color: Qt.alpha(root.fg, 0.45)
                            font: nameInput.font
                        }
                    }
                }

                Text {
                    text: "Icon"
                    color: Qt.alpha(root.fg, 0.7)
                    font.family: root.fontFamily
                    font.pixelSize: Style.space(12)
                }

                Flow {
                    width: parent.width
                    spacing: Style.space(6)

                    Repeater {
                        model: root.dIcons

                        Rectangle {
                            width: Style.space(30)
                            height: Style.space(30)
                            radius: Style.space(6)
                            color: root.dGlyph === modelData ? Qt.alpha(root.fg, 0.32)
                                : (iconMouse.containsMouse ? Qt.alpha(root.fg, 0.16) : Qt.alpha(root.fg, 0.06))

                            Text {
                                anchors.centerIn: parent
                                textFormat: Text.PlainText
                                text: modelData
                                color: root.fg
                                font.family: root.fontFamily
                                font.pixelSize: Style.space(16)
                            }

                            MouseArea {
                                id: iconMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.dGlyph = modelData
                            }
                        }
                    }
                }

                Text {
                    text: "Hide these widgets inside the drawer"
                    color: Qt.alpha(root.fg, 0.7)
                    font.family: root.fontFamily
                    font.pixelSize: Style.space(12)
                }

                Flow {
                    width: parent.width
                    spacing: Style.space(6)

                    Repeater {
                        model: root.dChoices

                        Rectangle {
                            height: Style.space(28)
                            width: chipText.implicitWidth + Style.space(20)
                            radius: Style.space(6)
                            color: root.isSelected(modelData) ? Qt.alpha(root.fg, 0.32)
                                : (chipMouse.containsMouse ? Qt.alpha(root.fg, 0.16) : Qt.alpha(root.fg, 0.06))

                            Text {
                                id: chipText
                                anchors.centerIn: parent
                                textFormat: Text.PlainText
                                text: (root.isSelected(modelData) ? "\u2713 " : "") + root.labelFor(modelData)
                                color: root.fg
                                font.family: root.fontFamily
                                font.pixelSize: Style.space(13)
                            }

                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.dToggle(modelData)
                            }
                        }
                    }
                }

                Text {
                    visible: root.dSelected.length > 1
                    text: "Order inside the drawer (drag to reorder)"
                    color: Qt.alpha(root.fg, 0.7)
                    font.family: root.fontFamily
                    font.pixelSize: Style.space(12)
                }

                Item {
                    id: orderBox
                    width: parent.width
                    visible: root.dSelected.length > 1
                    readonly property real rowH: Style.space(30)
                    height: visible ? root.dSelected.length * rowH : 0
                    implicitHeight: height

                    Repeater {
                        model: root.dSelected.length

                        Item {
                            id: slot
                            width: orderBox.width
                            height: orderBox.rowH
                            y: index * orderBox.rowH
                            z: orderDrag.drag.active ? 10 : 0

                            Rectangle {
                                id: orderRow
                                width: parent.width
                                height: parent.height - Style.space(4)
                                radius: Style.space(6)
                                color: orderDrag.drag.active ? Qt.alpha(root.fg, 0.3) : Qt.alpha(root.fg, 0.08)

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Style.space(10)
                                    textFormat: Text.PlainText
                                    text: "\u2261   " + root.labelFor(root.dSelected[index])
                                    color: root.fg
                                    font.family: root.fontFamily
                                    font.pixelSize: Style.space(13)
                                }

                                MouseArea {
                                    id: orderDrag
                                    anchors.fill: parent
                                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                    drag.target: orderRow
                                    drag.axis: Drag.YAxis
                                    drag.minimumY: -slot.y
                                    drag.maximumY: orderBox.height - orderBox.rowH - slot.y
                                    onReleased: {
                                        var to = Math.round((slot.y + orderRow.y) / orderBox.rowH)
                                        root.dMove(index, to)
                                        orderRow.y = 0
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: root.dFound && root.dChoices.length === 0
                    text: "No other widgets in this part of the bar. Only widgets in the same section as the drawer can be hidden in it."
                    wrapMode: Text.WordWrap
                    color: Qt.alpha(root.fg, 0.6)
                    font.family: root.fontFamily
                    font.pixelSize: Style.space(12)
                }

                Text {
                    width: parent.width
                    visible: root.dFound && !root.dCanRemove
                    text: "This is your only drawer, so it stays. Use + New drawer to add more, then you can remove extras."
                    wrapMode: Text.WordWrap
                    color: Qt.alpha(root.fg, 0.6)
                    font.family: root.fontFamily
                    font.pixelSize: Style.space(12)
                }

                Text {
                    width: parent.width
                    visible: root.dError !== ""
                    text: root.dError
                    wrapMode: Text.WordWrap
                    color: "#ff6b6b"
                    font.family: root.fontFamily
                    font.pixelSize: Style.space(12)
                }

                // ---- Row 1: Save / + New drawer / Remove ----
                Row {
                    id: actionsRow
                    width: parent.width
                    height: Style.space(34)
                    spacing: Style.space(8)
                    readonly property real btnW: Math.floor((width - spacing * 2) / 3)

                    Rectangle {
                        width: actionsRow.btnW
                        height: actionsRow.height
                        radius: Style.space(6)
                        opacity: root.dFound && !root.dBusy ? 1 : 0.5
                        color: saveMouse.containsMouse ? Qt.alpha(root.fg, 0.38) : Qt.alpha(root.fg, 0.26)

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(4)
                            anchors.rightMargin: Style.space(4)
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            text: root.dBusy ? "Saving\u2026" : "Save"
                            color: root.fg
                            font.family: root.fontFamily
                            font.pixelSize: Style.space(13)
                            font.bold: true
                            renderType: Text.NativeRendering
                        }

                        MouseArea {
                            id: saveMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.dSave()
                        }
                    }

                    Rectangle {
                        width: actionsRow.btnW
                        height: actionsRow.height
                        radius: Style.space(6)
                        visible: root.dFound
                        opacity: root.dBusy ? 0.5 : 1
                        color: addMouse.containsMouse ? Qt.alpha(root.fg, 0.2) : Qt.alpha(root.fg, 0.08)

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(4)
                            anchors.rightMargin: Style.space(4)
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            text: "+ New drawer"
                            color: root.fg
                            font.family: root.fontFamily
                            font.pixelSize: Style.space(13)
                            renderType: Text.NativeRendering
                        }

                        MouseArea {
                            id: addMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.dAddBlank()
                        }
                    }

                    Rectangle {
                        id: delBtn
                        width: actionsRow.btnW
                        height: actionsRow.height
                        radius: Style.space(6)
                        visible: root.dFound && root.dCanRemove
                        opacity: root.dBusy ? 0.5 : 1

                        property bool emptying: root.dOrigCount > 0
                        property bool confirming: !root.dOrigCount && root.dConfirm

                        color: delBtn.confirming
                            ? (delMouse.containsMouse ? "#e05555" : "#c0392b")
                            : delBtn.emptying
                                ? (delMouse.containsMouse ? Qt.alpha("#ff6b6b", 0.32) : Qt.alpha("#ff6b6b", 0.16))
                                : (delMouse.containsMouse ? Qt.alpha(root.fg, 0.20) : Qt.alpha(root.fg, 0.10))

                        border.width: 1
                        border.color: delBtn.confirming
                            ? "#c0392b"
                            : delBtn.emptying
                                ? Qt.alpha("#ff6b6b", 0.55)
                                : Qt.alpha(root.fg, 0.22)

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(4)
                            anchors.rightMargin: Style.space(4)
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            text: delBtn.confirming
                                ? "Remove?"
                                : (delBtn.emptying ? "Empty" : "Remove")
                            color: delBtn.confirming
                                ? "#ffffff"
                                : (delBtn.emptying ? "#ffb3b3" : root.fg)
                            font.family: root.fontFamily
                            font.pixelSize: Style.space(13)
                            font.bold: delBtn.confirming
                            renderType: Text.NativeRendering
                        }

                        MouseArea {
                            id: delMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.dOrigCount > 0) {
                                    root.dReset()
                                } else if (root.dConfirm) {
                                    confirmTimer.stop()
                                    root.dDelete()
                                } else {
                                    root.dConfirm = true
                                    confirmTimer.restart()
                                }
                            }
                        }
                    }
                }

                // ---- Row 2: move this drawer earlier / later on the bar ----
                Row {
                    id: reorderRow
                    width: parent.width
                    height: Style.space(30)
                    spacing: Style.space(8)
                    visible: root.dFound
                    readonly property real btnW: Math.floor((width - spacing) / 2)

                    Rectangle {
                        width: reorderRow.btnW
                        height: reorderRow.height
                        radius: Style.space(6)
                        opacity: root.dBusy ? 0.5 : 1
                        color: moveEarlierMouse.containsMouse ? Qt.alpha(root.fg, 0.2) : Qt.alpha(root.fg, 0.08)

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            textFormat: Text.PlainText
                            text: "\u25c0  Move earlier"
                            color: root.fg
                            font.family: root.fontFamily
                            font.pixelSize: Style.space(13)
                            renderType: Text.NativeRendering
                        }

                        MouseArea {
                            id: moveEarlierMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.dMoveEarlier()
                        }
                    }

                    Rectangle {
                        width: reorderRow.btnW
                        height: reorderRow.height
                        radius: Style.space(6)
                        opacity: root.dBusy ? 0.5 : 1
                        color: moveLaterMouse.containsMouse ? Qt.alpha(root.fg, 0.2) : Qt.alpha(root.fg, 0.08)

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            textFormat: Text.PlainText
                            text: "Move later  \u25b6"
                            color: root.fg
                            font.family: root.fontFamily
                            font.pixelSize: Style.space(13)
                            renderType: Text.NativeRendering
                        }

                        MouseArea {
                            id: moveLaterMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.dMoveLater()
                        }
                    }
                }

                Item {
                    width: 1
                    height: Style.space(4)
                }
            }
        }
    }
}
