pragma Singleton
import QtQuick

// Shared handle to the plugin's live Service.qml instance.
//
// The replacement-bar facade gives a bar entry a service-less shell, so the
// widget cannot discover its own service through `bar.shell.serviceFor()`.
// Service.qml publishes itself here and BarWidget.qml reads it. The host
// creates at most one service per plugin id, so a single slot is enough.
QtObject {
    property var service: null
}
