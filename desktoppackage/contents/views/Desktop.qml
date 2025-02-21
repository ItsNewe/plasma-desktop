/*
    SPDX-FileCopyrightText: 2012 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2014 David Edmundson <davidedmundson@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15

import org.kde.plasma.core as PlasmaCore
import org.kde.kwindowsystem 1.0
import org.kde.plasma.activityswitcher as ActivitySwitcher
import "../activitymanager"
import "../explorer"
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: root

    property Item containment

    property QtObject widgetExplorer

    Connections {
        target: ActivitySwitcher.Backend
        function onShouldShowSwitcherChanged() {
            if (ActivitySwitcher.Backend.shouldShowSwitcher) {
                if (sidePanelStack.state != "activityManager") {
                    root.toggleActivityManager();
                }

            } else {
                if (sidePanelStack.state == "activityManager") {
                    root.toggleActivityManager();
                }

            }
        }
    }

    function toggleWidgetExplorer(containment) {

        if (sidePanelStack.state == "widgetExplorer") {
            sidePanelStack.state = "closed";
        } else {
            sidePanelStack.state = "widgetExplorer";
            sidePanelStack.setSource(Qt.resolvedUrl("../explorer/WidgetExplorer.qml"), {"containment": containment, "sidePanel": sidePanel});
        }
    }

    function toggleActivityManager() {
        if (sidePanelStack.state == "activityManager") {
            sidePanelStack.state = "closed";
        } else {
            sidePanelStack.state = "activityManager";
            sidePanelStack.setSource(Qt.resolvedUrl("../activitymanager/ActivityManager.qml"));
        }
    }

    Loader {
        id: wallpaperColors

        active: root.containment && root.containment.wallpaper && desktop.usedInAccentColor
        asynchronous: true

        sourceComponent: Kirigami.ImageColors {
            id: imageColors
            source: root.containment.wallpaper

            readonly property color backgroundColor: Kirigami.Theme.backgroundColor
            readonly property color textColor: Kirigami.Theme.textColor

            // Ignore the initial dominant color
            onPaletteChanged: {
                if (!Qt.colorEqual(root.containment.wallpaper.accentColor, "transparent")) {
                    desktop.accentColor = root.containment.wallpaper.accentColor;
                }
                if (this.palette.length === 0) {
                    desktop.accentColor = "transparent";
                } else {
                    desktop.accentColor = this.dominant;
                }
            }

            Kirigami.Theme.inherit: false
            Kirigami.Theme.backgroundColor: backgroundColor
            Kirigami.Theme.textColor: textColor

            onBackgroundColorChanged: Qt.callLater(update)
            onTextColorChanged: Qt.callLater(update)

            property Connections repaintConnection: Connections {
                target: root.containment.wallpaper
                function onAccentColorChanged() {
                    if (Qt.colorEqual(root.containment.wallpaper.accentColor, "transparent")) {
                        imageColors.update();
                    } else {
                        imageColors.paletteChanged();
                    }
                }
            }
        }
    }

    Timer {
        id: pendingUninstallTimer
        // keeps track of the applets the user wants to uninstall
        property var applets: []
        function uninstall() {
            for (var i = 0, length = applets.length; i < length; ++i) {
                widgetExplorer.uninstall(applets[i])
            }
            applets = []

            if (sidePanelStack.state !== "widgetExplorer" && widgetExplorer) {
                widgetExplorer.destroy()
                widgetExplorer = null
            }
        }

        interval: 60000 // one minute
        onTriggered: uninstall()
    }

    PlasmaCore.Dialog {
        id: sidePanel
        location: Qt.application.layoutDirection === Qt.RightToLeft ? PlasmaCore.Types.RightEdge : PlasmaCore.Types.LeftEdge
        type: PlasmaCore.Dialog.Dock
        flags: Qt.WindowStaysOnTopHint

        hideOnWindowDeactivate: true

        x: {
            var result = desktop.x;
            if (!containment) {
                return result;
            }

            var rect = containment.plasmoid.availableScreenRect;
            result += rect.x;

            if (Qt.application.layoutDirection === Qt.RightToLeft) {
                result += rect.width - sidePanel.width;
            }

            return result;
        }
        y: desktop.y + (containment ? containment.plasmoid.availableScreenRect.y : 0)

        onVisibleChanged: {
            if (!visible) {
                sidePanelStack.state = "closed";
                ActivitySwitcher.Backend.shouldShowSwitcher = false;
            }
        }

        mainItem: Loader {
            id: sidePanelStack
            asynchronous: true
            width: item ? item.width: 0
            height: containment ? containment.plasmoid.availableScreenRect.height - sidePanel.margins.top - sidePanel.margins.bottom : 1000
            state: "closed"

            LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
            LayoutMirroring.childrenInherit: true

            onLoaded: {
                if (sidePanelStack.item) {
                    item.closed.connect(function(){sidePanelStack.state = "closed";});

                    if (sidePanelStack.state == "activityManager") {
                        sidePanelStack.item.showSwitcherOnly =
                            ActivitySwitcher.Backend.shouldShowSwitcher
                        sidePanel.hideOnWindowDeactivate = Qt.binding(function() {
                            return !ActivitySwitcher.Backend.shouldShowSwitcher
                                && !sidePanelStack.item.showingDialog;
                        })
                        sidePanelStack.item.forceActiveFocus();
                    } else if (sidePanelStack.state == "widgetExplorer"){
                        sidePanel.hideOnWindowDeactivate = Qt.binding(function() { return sidePanelStack.item && !sidePanelStack.item.preventWindowHide; })
                        sidePanel.opacity = Qt.binding(function() { return sidePanelStack.item ? sidePanelStack.item.opacity : 1 })
                        sidePanel.outputOnly = Qt.binding(function() { return sidePanelStack.item && sidePanelStack.item.outputOnly })
                    } else {
                        sidePanel.hideOnWindowDeactivate = true;
                    }
                }
                sidePanel.visible = true;
                if (KWindowSystem.isPlatformX11) {
                    KX11Extras.forceActiveWindow(sidePanel);
                }
            }
            onStateChanged: {
                if (sidePanelStack.state == "closed") {
                    sidePanel.visible = false;
                    sidePanelStack.source = ""; //unload all elements
                }
            }
        }
    }

    Connections {
        target: containment?.plasmoid ?? null
        function onAvailableScreenRectChanged() {
            if (sidePanel.visible) {
                sidePanel.requestActivate();
            }
        }
    }

    onContainmentChanged: {
        if (containment == null) {
            return;
        }

        if (switchAnim.running) {
            //If the animation was still running, stop it and reset
            //everything so that a consistent state can be kept
            switchAnim.running = false;
            internal.newContainment.visible = false;
            internal.oldContainment.visible = false;
            internal.oldContainment = null;
        }

        internal.newContainment = containment;
        containment.visible = true;

        if (internal.oldContainment != null && internal.oldContainment != containment) {
            switchAnim.running = true;
        } else {
            containment.anchors.left = root.left;
            containment.anchors.top = root.top;
            containment.anchors.right = root.right;
            containment.anchors.bottom = root.bottom;
            if (internal.oldContainment) {
                internal.oldContainment.visible = false;
            }
            internal.oldContainment = containment;
        }
    }

    //some properties that shouldn't be accessible from elsewhere
    QtObject {
        id: internal;

        property Item oldContainment: null;
        property Item newContainment: null;
    }

    SequentialAnimation {
        id: switchAnim
        ScriptAction {
            script: {
                if (containment) {
                    containment.anchors.left = undefined;
                    containment.anchors.top = undefined;
                    containment.anchors.right = undefined;
                    containment.anchors.bottom = undefined;
                    containment.z = 1;
                    containment.x = root.width;
                }
                if (internal.oldContainment) {
                    internal.oldContainment.anchors.left = undefined;
                    internal.oldContainment.anchors.top = undefined;
                    internal.oldContainment.anchors.right = undefined;
                    internal.oldContainment.anchors.bottom = undefined;
                    internal.oldContainment.z = 0;
                    internal.oldContainment.x = 0;
                }
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: internal.oldContainment
                properties: "x"
                to: internal.newContainment != null ? -root.width : 0
                duration: Kirigami.Units.veryLongDuration
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: internal.newContainment
                properties: "x"
                to: 0
                duration: Kirigami.Units.longDuration
                easing.type: Easing.InOutQuad
            }
        }
        ScriptAction {
            script: {
                if (internal.oldContainment) {
                    internal.oldContainment.visible = false;
                }
                if (containment) {
                    containment.anchors.left = root.left;
                    containment.anchors.top = root.top;
                    containment.anchors.right = root.right;
                    containment.anchors.bottom = root.bottom;
                    internal.oldContainment = containment;
                }
            }
        }
    }

    Loader {
        id: previewBannerLoader
        readonly property point pos: root.containment?.plasmoid.availableScreenRegion,
            active ? root.containment.adjustToAvailableScreenRegion(
                root.containment.width + root.containment.x - item.width - Kirigami.Units.largeSpacing,
                root.containment.height + root.containment.y - item.height - Kirigami.Units.largeSpacing,
                item.width + Kirigami.Units.largeSpacing,
                item.height + Kirigami.Units.largeSpacing)
            : Qt.point(0, 0)
        x: pos.x
        y: pos.y
        z: Number(root.containment?.z) + 1
        active: root.containment && Boolean(desktop.showPreviewBanner)
        visible: active
        source: "PreviewBanner.qml"
    }
}
