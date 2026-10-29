pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// Draft preferences: only Save writes them; Escape/Cancel leaves them unchanged.
FocusScope {
    id: root

    required property var config
    required property var settingsService
    required property bool busy
    property string errorText: ""
    signal saved()
    signal cancelled()

    function begin(): void {
        errorText = ""
        modeInput.currentIndex = settingsService.hellwalMode === "light" ? 1 : 0
        backgroundModeInput.currentIndex = settingsService.hellwalBackgroundMode === "fixed" ? 1 : 0
        darkOffsetInput.text = String(settingsService.hellwalDarkOffset)
        brightOffsetInput.text = String(settingsService.hellwalBrightOffset)
        grayScaleInput.text = String(settingsService.hellwalGrayScale)
        backgroundInput.text = settingsService.hellwalBackgroundColor
        Qt.callLater(() => modeInput.forceActiveFocus())
    }

    function save(): void {
        if (busy)
            return
        const dark = darkOffsetInput.text.trim()
        const bright = brightOffsetInput.text.trim()
        const grayScale = grayScaleInput.text.trim()
        if (dark === "" || bright === "" || grayScale === "") {
            errorText = "Offsets must be between 0 and 1"
            return
        }
        errorText = settingsService.saveHellwalSettings(
            modeInput.currentIndex === 1 ? "light" : "dark", Number(dark), Number(bright),
            backgroundModeInput.currentIndex === 1 ? "fixed" : "dynamic", backgroundInput.text,
            Number(grayScale))
        if (errorText === "")
            saved()
    }

    Shortcut {
        sequence: "Ctrl+Return"
        enabled: root.visible && root.enabled && !root.busy
        onActivated: root.save()
    }
    Shortcut {
        sequence: "Ctrl+Enter"
        enabled: root.visible && root.enabled && !root.busy
        onActivated: root.save()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Text {
                renderType: Text.NativeRendering
                Layout.fillWidth: true
                text: "Wallpaper settings"
                color: root.config.fg
                font.pointSize: root.config.fontSize(1)
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
        }

        ScrollView {
            id: settingsScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            GridLayout {
                width: settingsScroll.availableWidth
                columns: width < 400 ? 1 : 2
                columnSpacing: 20
                rowSpacing: 16
                enabled: !root.busy

                ColumnLayout {
                    Layout.fillWidth: true
                    SettingLabel { text: "Mode" }
                    SettingCombo {
                        id: modeInput
                        objectName: "wallpaperColorMode"
                        model: ["Dark", "Light"]
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    SettingLabel { text: "Background" }
                    SettingCombo {
                        id: backgroundModeInput
                        objectName: "wallpaperBackgroundMode"
                        model: ["Dynamic", "Fixed"]
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    SettingLabel { text: "Dark offset (0–1)" }
                    SettingField {
                        id: darkOffsetInput
                        objectName: "wallpaperDarkOffset"
                        placeholderText: "0"
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    SettingLabel { text: "Bright offset (0–1)" }
                    SettingField {
                        id: brightOffsetInput
                        objectName: "wallpaperBrightOffset"
                        placeholderText: "0"
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    SettingLabel { text: "Grayscale (0–1, 0 = off)" }
                    SettingField {
                        id: grayScaleInput
                        objectName: "wallpaperGrayScale"
                        placeholderText: "0"
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.columnSpan: parent.columns
                    SettingLabel { text: "Fixed background color" }
                    RowLayout {
                        Layout.fillWidth: true
                        enabled: backgroundModeInput.currentIndex === 1
                        opacity: enabled ? 1 : 0.5
                        SettingField {
                            id: backgroundInput
                            objectName: "wallpaperBackgroundColor"
                            placeholderText: "#111111"
                            onAccepted: root.save()
                        }
                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 4
                            color: /^#[0-9a-fA-F]{6}$/.test(backgroundInput.text.trim())
                                ? backgroundInput.text.trim() : root.config.bg
                            border.color: root.config.border
                        }
                    }
                    Text {
                        renderType: Text.NativeRendering
                        Layout.fillWidth: true
                        text: "Used by Hellwal. Dynamic derives the background from the wallpaper."
                        color: root.config.muted
                        font.pointSize: root.config.fontSize(0.8)
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        Text {
            renderType: Text.NativeRendering
            Layout.fillWidth: true
            visible: root.errorText !== ""
            text: root.errorText
            color: root.config.urgent
            font.pointSize: root.config.fontSize(0.85)
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Item { Layout.fillWidth: true }
            ActionButton { text: "Cancel"; onClicked: root.cancelled() }
            ActionButton { text: "Save"; enabled: !root.busy; onClicked: root.save() }
        }
    }

    component SettingLabel: Text {
        renderType: Text.NativeRendering
        Layout.fillWidth: true
        color: root.config.muted
        font.pointSize: root.config.fontSize(0.85)
        wrapMode: Text.WordWrap
    }

    component SettingField: TextField {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredHeight: 32
        color: root.config.fg
        placeholderTextColor: root.config.muted
        selectionColor: root.config.selectionBackground
        selectedTextColor: root.config.selectionForeground
        font.pointSize: root.config.fontSize(0.9)
        selectByMouse: true
        onTextChanged: root.errorText = ""
        background: Rectangle {
            color: "transparent"
            radius: 4
            border.color: parent.activeFocus ? root.config.selectionBackground : root.config.border
        }
    }

    component SettingCombo: ComboBox {
        id: combo
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredHeight: 32
        font.pointSize: root.config.fontSize(0.9)
        onActivated: root.errorText = ""
        contentItem: Text {
            renderType: Text.NativeRendering
            leftPadding: 8
            rightPadding: combo.indicator ? combo.indicator.width + 8 : 8
            text: combo.currentText
            color: root.config.fg
            font: combo.font
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            color: "transparent"
            radius: 4
            border.color: combo.activeFocus ? root.config.selectionBackground : root.config.border
        }
    }

    component ActionButton: Button {
        id: button
        font.pointSize: root.config.fontSize(0.85)
        opacity: enabled ? 1 : 0.5
        contentItem: Text {
            renderType: Text.NativeRendering
            text: button.text
            font: button.font
            color: button.hovered || button.activeFocus
                ? root.config.selectionForeground : root.config.fg
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 4
            color: button.hovered || button.activeFocus ? root.config.selectionBackground : "transparent"
            border.color: button.activeFocus ? root.config.selectionBackground : root.config.border
        }
    }
}
