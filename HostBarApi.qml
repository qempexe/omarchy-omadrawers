pragma ComponentBehavior: Bound

import QtQuick
import qs.Ui

PluginBarApi {
    id: root

    property var source: null

    foreground: source ? source.foreground : "transparent"
    barForeground: source ? source.barForeground : "transparent"
    background: source ? source.background : "transparent"
    urgent: source ? source.urgent : "transparent"
    fontFamily: source ? String(source.fontFamily || "") : ""
    position: source ? String(source.position || "top") : "top"
    vertical: source ? source.vertical === true : false
    barSize: source ? Number(source.barSize || 0) : 0
    transparent: source ? source.transparent === true : false
    foregroundAnimationEnabled: source ? source.foregroundAnimationEnabled !== false : true
    centerSectionRevealHeld: source ? source.centerSectionRevealHeld === true : false
    activePopout: source ? source.activePopout : null
    clickTargets: source && source.clickTargets ? source.clickTargets : []
    layoutConfig: source && source.layoutConfig ? source.layoutConfig : ({})

    _showTooltip: function(target, text) {
        if (source && typeof source.showTooltip === "function") source.showTooltip(target, text)
    }
    _hideTooltip: function(target) {
        if (source && typeof source.hideTooltip === "function") source.hideTooltip(target)
    }
    _registerClickTarget: function(target) {
        if (source && typeof source.registerClickTarget === "function") source.registerClickTarget(target)
    }
    _unregisterClickTarget: function(target) {
        if (source && typeof source.unregisterClickTarget === "function") source.unregisterClickTarget(target)
    }
    _requestPopout: function(owner) {
        if (source && typeof source.requestPopout === "function") source.requestPopout(owner)
    }
    _releasePopout: function(owner) {
        if (source && typeof source.releasePopout === "function") source.releasePopout(owner)
    }
    _switchPanelFrom: function(owner, direction) {
        return source && typeof source.switchPanelFrom === "function"
            ? source.switchPanelFrom(owner, direction) : false
    }
    _targetBelongsToWindow: function(target, window) {
        return source && typeof source.targetBelongsToWindow === "function"
            ? source.targetBelongsToWindow(target, window) : false
    }
    _moduleWidgets: function(id) {
        return source && typeof source.moduleWidgets === "function" ? source.moduleWidgets(id) : []
    }
    _run: function(command) {
        if (source && typeof source.run === "function") source.run(command)
    }
    _setCenterHoverRevealSuppressed: function(value) {
        if (source && typeof source.setCenterHoverRevealSuppressed === "function")
            source.setCenterHoverRevealSuppressed(value)
    }
}
