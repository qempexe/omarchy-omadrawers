pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

Item {
    id: root

    // Injected by the shell
    property var shell: null
    property var manifest: null
    property var barWidgetRegistry: null

    readonly property string pluginId: "io.github.qempexe.omadrawers"
    readonly property var widgetCatalog: root.barWidgetRegistry && root.barWidgetRegistry.widgets
        ? root.barWidgetRegistry.widgets : ({})

    signal drawerSettingsChanged(string key, var values)
    function notifyDrawerSettings(key, values) {
        drawerSettingsChanged(String(key || ""), values)
    }

    signal drawerDragStarted()
    signal drawerDragEnded()
    function notifyDrawerDragStart() { drawerDragStarted() }
    function notifyDrawerDragEnd() { drawerDragEnded() }

    function mutateShellConfig(mutator) {
        if (root.shell && typeof root.shell.mutateShellConfig === "function")
            return root.shell.mutateShellConfig(mutator)
        return false
    }

    readonly property var hostShell: QtObject {
        property string pluginId: root.pluginId
        function serviceFor(id) { return String(id || "") === root.pluginId ? root : null }
        function firstPartyServiceFor(id) { return null }
        function summon(id, payloadJson) { root.ipc("summon", id, payloadJson); return true }
        function hide(id) { root.ipc("hide", id, ""); return true }
        function toggle(id, payloadJson) { root.ipc("toggle", id, payloadJson); return true }
        function isPluginOpen(id) { return false }
        function updateEntryInline(id, settings) { return false }
        function mutateShellConfig(mutator) { return root.mutateShellConfig(mutator) }
    }

    function componentFor(id) {
        var entry = root.widgetCatalog[String(id || "")]
        return entry ? entry.component : null
    }

    function hasWidget(id) {
        return root.widgetCatalog[String(id || "")] !== undefined
    }

    function ipc(verb, id, payloadJson) {
        var target = String(id || "")
        if (target === "") return
        var args = ["omarchy-shell", "shell", String(verb || ""), target]
        var body = payloadJson === undefined || payloadJson === null ? "" : String(payloadJson)
        if (body !== "") args.push(body)
        ipcRunner.createObject(root, { command: args })
    }

    Component {
        id: ipcRunner
        Process {
            id: ipcProcess
            running: true
            stdout: StdioCollector { waitForEnd: true }
            stderr: StdioCollector { waitForEnd: true }
            onExited: Qt.callLater(function() { ipcProcess.destroy() })
        }
    }
}
