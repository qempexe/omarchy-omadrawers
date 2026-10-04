pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    // Injected by the bar
    property var bar: null
    property string moduleName: ""
    property var settings: ({})

    readonly property string pluginId: "io.github.qempexe.omadrawers"
    readonly property bool vertical: bar ? bar.vertical === true : false
    readonly property real barSize: bar && bar.barSize ? Number(bar.barSize) : (vertical ? 28 : 26)
    readonly property color fg: bar && bar.foreground ? bar.foreground : "white"
    readonly property string fontFamily: bar && bar.fontFamily ? String(bar.fontFamily) : "monospace"

    readonly property color drawerBackground: {
        if (bar && bar.background !== undefined && bar.background !== null
            && String(bar.background) !== "transparent")
            return bar.background
        return "#1a1a1a"
    }

    readonly property string drawerKey: settings && settings.key ? String(settings.key) : ""

    property var liveOverride: null
    readonly property var effectiveSettings:
        root.liveOverride !== null ? root.liveOverride : root.settings

    readonly property string label: {
        var s = root.effectiveSettings || ({})
        return s.name ? String(s.name) : "Drawer"
    }
    readonly property string glyph: {
        var s = root.effectiveSettings || ({})
        return s.glyph ? String(s.glyph) : "\uf141"
    }
    readonly property bool before: {
        var s = root.effectiveSettings || ({})
        return s.reveal === "before"
    }
    readonly property var items: {
        var s = root.effectiveSettings || ({})
        return s.items && s.items.length !== undefined ? s.items : []
    }

    readonly property real pad: 8
    readonly property real gap: 4
    readonly property real drawerPad: 4

    property bool pinned: false
    property bool shown: false
    // Suppress hover-open while any drawer is being dragged so its overlay
    // can't interfere with the shell's drag hit-test.
    property bool dragging: false
    readonly property bool popoutBusy: bar !== null && bar.activePopout !== undefined && bar.activePopout !== null

    property int serviceAttempt: 0
    readonly property var service: {
        var attempt = root.serviceAttempt
        return root.bar && root.bar.shell ? root.bar.shell.serviceFor(root.pluginId) : null
    }

    readonly property string tooltipText: root.items.length === 0
        ? root.label + "\nEmpty. Right-click to set it up"
        : root.label + " (" + root.items.length + ")\nHover to open, click to pin, right-click to edit"

    function tip(show) {
        if (!root.bar) return
        if (show && typeof root.bar.showTooltip === "function") root.bar.showTooltip(handle, root.tooltipText)
        else if (!show && typeof root.bar.hideTooltip === "function") root.bar.hideTooltip(handle)
    }

    readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
    readonly property bool popoutSwitchClosing: panelLoader.item
        ? panelLoader.item.popoutSwitchClosing === true : false

    function open() { if (panelLoader.item) panelLoader.item.open() }
    function close() { if (panelLoader.item) panelLoader.item.close() }
    function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
    function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

    function injectPanel() {
        if (!panelLoader.item) return
        panelLoader.item.bar = root.bar
        panelLoader.item.anchorItem = handle
        panelLoader.item.hostWidget = root
        panelLoader.item.drawerKey = root.drawerKey
    }

    onBarChanged: root.injectPanel()
    onDrawerKeyChanged: root.injectPanel()
    onSettingsChanged: root.liveOverride = null

    Connections {
        target: root.service
        enabled: root.service !== null
        function onDrawerSettingsChanged(key, values) {
            if (String(key) !== root.drawerKey) return
            root.liveOverride = values
        }
    }

    Connections {
        target: root.service
        enabled: root.service !== null
        function onDrawerDragStarted() {
            root.pinned = false
            root.shown = false
            root.dragging = true
            dragReleaseTimer.restart()
        }
        function onDrawerDragEnded() {
            root.dragging = false
            dragReleaseTimer.stop()
        }
    }

    Timer {
        id: dragReleaseTimer
        interval: 1500
        onTriggered: root.dragging = false
    }

    Loader {
        id: panelLoader
        active: true
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: {
            root.injectPanel()
            Qt.callLater(root.injectPanel)
        }
    }

    onPinnedChanged: {
        if (root.pinned) root.shown = true
        else if (!hover.hovered) collapseTimer.restart()
    }
    Component.onDestruction: root.tip(false)

    Timer {
        interval: 400
        repeat: true
        running: root.service === null && root.serviceAttempt < 40 && root.items.length > 0
        onTriggered: root.serviceAttempt = root.serviceAttempt + 1
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered && !root.dragging) {
                collapseTimer.stop()
                root.shown = true
            } else {
                collapseTimer.restart()
            }
        }
    }

    Timer {
        id: collapseTimer
        interval: 450
        onTriggered: {
            if (root.pinned || hover.hovered) return
            if (root.popoutBusy) { collapseTimer.restart(); return }
            root.shown = false
        }
    }

    implicitWidth: root.vertical ? root.barSize : handle.width
    implicitHeight: root.vertical ? handle.height : root.barSize

    z: (root.shown || root.pinned) ? 100 : 0

    Item {
        id: handle
        x: 0
        y: 0
        width: root.vertical ? root.barSize : glyphText.implicitWidth + root.pad * 2
        height: root.vertical ? glyphText.implicitHeight + root.pad * 2 : root.barSize

        Text {
            id: glyphText
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: root.glyph
            color: (root.shown || root.pinned) ? root.fg : Qt.alpha(root.fg, 0.75)
            font.family: root.fontFamily
            font.pixelSize: 14
            renderType: Text.NativeRendering
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: root.tip(containsMouse)

            onPressed: function(mouse) {
                if (mouse.button !== Qt.LeftButton) return
                root.pinned = false
                root.shown = false
                root.dragging = true
                dragReleaseTimer.restart()
                if (root.service && typeof root.service.notifyDrawerDragStart === "function")
                    root.service.notifyDrawerDragStart()
            }

            onReleased: function(mouse) {
                if (mouse.button !== Qt.LeftButton) return
                root.dragging = false
                dragReleaseTimer.stop()
                if (root.service && typeof root.service.notifyDrawerDragEnd === "function")
                    root.service.notifyDrawerDragEnd()
            }

            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    root.tip(false)
                    root.toggle()
                } else {
                    root.pinned = !root.pinned
                }
            }
        }
    }

    Item {
        id: clipBox
        // Instantly hidden during a drag — no animation, no leftover overlay
        // for the shell's drag hit-test to trip over.
        visible: !root.dragging
        clip: true
        opacity: root.shown ? 1 : 0
        width: root.vertical ? root.barSize : (root.shown ? content.width + drawerPad * 2 : 0)
        height: root.vertical ? (root.shown ? content.height + drawerPad * 2 : 0) : root.barSize
        x: root.vertical
            ? 0
            : (root.before ? -(content.width + drawerPad * 2) : handle.width)
        y: root.vertical
            ? (root.before ? -(content.height + drawerPad * 2) : handle.height)
            : 0

        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 140 } }

        Rectangle {
            anchors.fill: parent
            color: root.drawerBackground
            radius: Style && Style.radius ? Style.radius : 4
        }

        Grid {
            id: content
            columns: root.vertical ? 1 : Math.max(1, root.items.length)
            spacing: root.gap
            verticalItemAlignment: Grid.AlignVCenter
            horizontalItemAlignment: Grid.AlignHCenter
            x: root.drawerPad
            y: root.drawerPad

            Repeater {
                model: root.items
                DrawerItem {
                    required property var modelData
                    entry: modelData
                    service: root.service
                    bar: root.bar
                }
            }
        }
    }
}
