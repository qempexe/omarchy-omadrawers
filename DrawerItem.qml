pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property var entry: ({})
    property var service: null
    property var bar: null
    property var hostApi: null

    readonly property string widgetId: root.entry && root.entry.id ? String(root.entry.id) : ""
    readonly property var component: root.service ? root.service.componentFor(root.widgetId) : null
    readonly property var widgetSettings: {
        var out = ({})
        var src = root.entry ? root.entry : ({})
        for (var key in src) if (key !== "id") out[key] = src[key]
        return out
    }
    readonly property var widgetItem: loader.item
    readonly property real itemW: root.widgetItem ? Number(root.widgetItem.implicitWidth) : 0
    readonly property real itemH: root.widgetItem ? Number(root.widgetItem.implicitHeight) : 0

    // A widget that renders nothing takes no space.
    visible: root.itemW > 0 && root.itemH > 0
    implicitWidth: root.itemW
    implicitHeight: root.itemH
    width: implicitWidth
    height: implicitHeight

    function ensureHostApi() {
        if (root.hostApi !== null || root.bar === null || root.service === null) return
        root.hostApi = hostApiComponent.createObject(root, {
            pluginId: root.service.pluginId,
            moduleName: root.widgetId,
            source: root.bar,
            shell: root.service.hostShell
        })
    }

    function inject() {
        var item = root.widgetItem
        if (!item) return
        if ("bar" in item && root.hostApi) item.bar = root.hostApi
        if ("moduleName" in item) item.moduleName = root.widgetId
        if ("settings" in item) item.settings = root.widgetSettings
    }

    onBarChanged: root.ensureHostApi()
    onServiceChanged: root.ensureHostApi()
    onHostApiChanged: Qt.callLater(root.inject)
    onWidgetSettingsChanged: Qt.callLater(root.inject)
    Component.onCompleted: root.ensureHostApi()

    Component.onDestruction: {
        var item = root.widgetItem
        if (item) {
            try { if ("bar" in item) item.bar = null } catch (e) { }
        }
        if (root.hostApi) root.hostApi.destroy(1000)
    }

    Loader {
        id: loader
        anchors.centerIn: parent
        active: root.component !== null && root.hostApi !== null
        sourceComponent: root.component
        onLoaded: {
            root.inject()
            Qt.callLater(root.inject)
        }
    }

    Component {
        id: hostApiComponent
        HostBarApi { }
    }
}
