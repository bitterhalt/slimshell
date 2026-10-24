pragma ComponentBehavior: Bound

import QtQuick
import "../../../components"

Item {
    id: root

    required property var config
    required property var barWindow
    required property var niri

    readonly property bool minimalLayout: config.workspaceLayout === "minimal"
    readonly property var outputWorkspaces: niri.workspaces
        .filter(workspace => workspace.output === barWindow.screen.name)
        .sort((a, b) => a.idx - b.idx)
    readonly property var activeWorkspace:
        outputWorkspaces.find(workspace => workspace.is_active) ?? null
    readonly property var otherWorkspaces:
        outputWorkspaces.filter(workspace => !workspace.is_active)

    implicitWidth: minimalLayout ? workspaceRevealer.implicitWidth : dotsRow.implicitWidth
    height: barWindow.height

    function focusWorkspace(workspace): void {
        if (workspace)
            config.run(`niri msg action focus-workspace ${workspace.idx}`)
    }

    Row {
        id: dotsRow

        anchors.centerIn: parent
        spacing: root.config.barModuleSpacing
        visible: !root.minimalLayout

        Repeater {
            model: root.outputWorkspaces

            delegate: Rectangle {
                id: workspaceDot
                objectName: "workspace-dot-" + modelData.idx
                required property var modelData

                width: modelData.is_active ? 24 : 8
                height: 8
                radius: 4
                color: workspaceDot.modelData.is_urgent ? root.config.urgent
                    : workspaceDot.modelData.is_active
                        ? root.config.selectionBackground : root.config.fg
                opacity: workspaceDot.modelData.is_active ? 1 : 0.7

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.focusWorkspace(workspaceDot.modelData)
                }
            }
        }
    }

    ItemRevealer {
        id: workspaceRevealer
        objectName: "workspaceRevealer"

        config: root.config
        barWindow: root.barWindow
        hoverRevealDelay: 100
        visible: root.minimalLayout

        Rectangle {
            objectName: "activeWorkspaceChip"
            width: activeName.implicitWidth + 16
            height: 26
            radius: 4
            color: root.config.selectionBackground

            Text {
                id: activeName
                objectName: "activeWorkspaceName"
                renderType: Text.NativeRendering

                anchors.centerIn: parent
                color: root.config.selectionForeground
                font.pointSize: root.config.fontSize(1)
                font.weight: Font.DemiBold
                text: root.activeWorkspace
                    ? (root.activeWorkspace.name || String(root.activeWorkspace.idx))
                    : "—"
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.activeWorkspace !== null
                cursorShape: Qt.PointingHandCursor
                onClicked: root.focusWorkspace(root.activeWorkspace)
            }
        }

        revealData: [
            Repeater {
                model: root.otherWorkspaces

                delegate: Rectangle {
                    id: workspaceItem
                    required property var modelData

                    width: workspaceName.implicitWidth + 16
                    height: 26
                    radius: 4
                    color: workspaceItem.modelData.is_urgent
                        ? root.config.urgent : root.config.selectionBackground
                    opacity: 0.8

                    Text {
                        id: workspaceName
                        objectName: "workspace-name-" + workspaceItem.modelData.idx
                        renderType: Text.NativeRendering

                        anchors.centerIn: parent
                        color: workspaceItem.modelData.is_urgent
                            ? root.config.fg : root.config.selectionForeground
                        font.pointSize: root.config.fontSize(1)
                        font.weight: Font.DemiBold
                        text: workspaceItem.modelData.name
                            || String(workspaceItem.modelData.idx)
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.focusWorkspace(workspaceItem.modelData)
                    }
                }
            }
        ]
    }
}
