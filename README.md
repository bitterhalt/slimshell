<p align="center">
  <img src="assets/slimshell.svg" alt="Slimshell: a slim rat walking along a thin bar" width="100%">
</p>

### What Slim is and what it isn’t

- It **is** a personalised Quickshell environment for **NIRI**
- Why slim? I needed a lightweight desktop environment with compact design
- What Slim **isn’t**: A highly customizable environment featuring all the bells and whistles

> This is mainly designed for my own use to replace bar, notifications and some complicated bash scripts

## Features

- Per-screen bar with workspaces, window title, clock, weather, battery, and system tray
- Keyboard-driven Network and Bluetooth popups, plus PipeWire audio controls
- Keyboard-driven audio tabs: Outputs, Inputs, Playback, and card profiles
- Notifications, history, and do-not-disturb mode
- Bluetooth connection and low-battery alerts
- Application launcher with Apps, Run, Emoji, and Timer modes (`Ctrl+A` / `Ctrl+B` / `Ctrl+E` / `Ctrl+T`, or cycle with `Ctrl+←` / `Ctrl+→`)
- Clipboard history
- Lock screen and power menu
- Idle monitoring with editable timeouts
- Fullscreen and region recording
- Wallpaper picker and Pywal themes
- DeepL translator
- Process killer
- Keyboard shortcuts and IPC controls

Network and Bluetooth popups can also be opened with `qs ipc call network toggle` and `qs ipc call bluetooth toggle`.

In the launcher, `/needle` searches files and `=expression` calculates with `qalc` (plain math works too). The modes are Apps (desktop entries), Run (binaries, recently used first), Emoji (search by name; Enter copies it), and Timer (`25m Focus`, `45s`, `1:30`, `2h`; selecting a running timer cancels it). Enter activates the selected row and Esc closes.

For a stdin-driven picker (Dmenu Mode), use `printf '%s\n' one two three | ./launcher/dmenu-runner -p "Pick"`. Enter prints the selected line, Shift+Enter prints the typed text, and Esc cancels with exit status 1. This requires quickshell to be running.

Use `-l N` / `--lines N` to set the visible rows (default 7). Add `--minimal-lines` to shrink to the number of input choices; filtering keeps that height. Oversized menus fit the screen, and `-l 0` shows only the prompt and mode footer, with Enter returning typed text.

## Structure

```text
quickshell/
├── shell.qml
├── Config.qml
├── bar/
│   ├── Bar.qml
│   └── modules/
│       ├── audio/
│       │   ├── Audio.qml
│       │   ├── AudioPopup.qml
│       │   ├── AudioPopupState.qml
│       │   ├── AudioProfiles.qml
│       │   ├── AudioVolumeRow.qml
│       │   ├── Model.js
│       │   ├── Profiles.js
│       │   └── tests/
│       │       ├── AudioFixture.qml
│       │       ├── ProfileFixture.qml
│       │       └── tst_audio.qml
│       ├── battery/
│       │   └── Battery.qml
│       ├── bluetooth/
│       │   ├── Bluetooth.qml
│       │   ├── BluetoothNotifier.qml
│       │   ├── Model.js
│       │   └── tests/
│       │       └── tst_model.qml
│       ├── clock/
│       │   └── Clock.qml
│       ├── idle/
│       │   ├── Idle.qml
│       │   └── IdleNotifier.qml
│       ├── network/
│       │   ├── Model.js
│       │   ├── Network.qml
│       │   ├── NetworkPopup.qml
│       │   ├── NetworkRow.qml
│       │   └── tests/
│       │       └── tst_model.qml
│       ├── tray/
│       │   ├── Power.qml
│       │   ├── Tray.qml
│       │   └── TrayMenu.qml
│       ├── window/
│       │   └── WindowTitle.qml
│       └── workspaces/
│           └── Workspaces.qml
├── clipboard/
│   └── Clipboard.qml
├── components/
│   ├── PanelSeparator.qml
│   ├── PopoutPanel.qml
│   ├── PopupCatcher.qml
│   ├── PopupManager.qml
│   ├── SectionHeader.qml
│   ├── ToggleSwitch.qml
│   └── tests/
│       └── tst_popoutpanel.qml
├── launcher/
│   ├── Dmenu.js
│   ├── Emoji.js
│   ├── Launcher.qml
│   ├── Scorer.js
│   ├── dmenu-runner
│   └── tests/
│       ├── test_dmenu_runner.py
│       ├── tst_dmenu.qml
│       └── tst_emoji.qml
├── lock/
│   ├── LockContext.qml
│   ├── LockSurface.qml
│   ├── lock.sh
│   └── pam/
│       └── quickshell-lock
├── lock.qml
├── lock-test.qml
├── menus/
│   ├── IdleSettings.qml
│   ├── MainMenu.qml
│   ├── ProcessMenu.qml
│   ├── processes.py
│   ├── ThemeMenu.qml
│   └── WallpaperMenu.qml
├── notifications/
│   ├── NotificationCard.qml
│   ├── NotificationCenter.qml
│   ├── NotificationIndicator.qml
│   └── NotificationPopup.qml
├── osd/
│   └── VolumeOsd.qml
├── recorder/
│   ├── Recorder.qml
│   └── RegionSelector.qml
├── services/
│   ├── BatteryService.qml
│   ├── BluetoothService.qml
│   ├── IdleService.qml
│   ├── LockService.qml
│   ├── NiriService.qml
│   ├── NotificationService.qml
│   ├── RecorderService.qml
│   ├── ShellUiService.qml
│   ├── ThemeService.qml
│   ├── TimerService.qml
│   ├── WeatherService.qml
│   ├── bluetooth/
│   │   ├── BatteryWarning.js
│   │   └── tests/
│   │       └── tst_batterywarning.qml
│   └── idle/
│       ├── Duration.js
│       ├── suspend.sh
│       └── tests/
│           └── tst_duration.qml
├── translator/
│   ├── Languages.js
│   ├── Translator.qml
│   ├── TranslatorButton.qml
│   ├── TranslatorWindow.qml
│   ├── deepl.py
│   ├── test_deepl.py
│   └── tests/
│       └── tst_languages.qml
├── wallpaper/
│   ├── Wallpaper.qml
│   ├── setbg.py
│   └── test_setbg.py
└── weather/
    ├── WeatherPopup.qml
    └── weather.py
```

## Requirements

QuickShell, Niri, PipeWire, NetworkManager, BlueZ, and UPower.

Feature helpers use Python, `wl-clipboard`, `cliphist`, `gpu-screen-recorder`, ImageMagick, `awww`, and Pywal. Audio card profiles require `pactl` and PipeWire's PulseAudio compatibility service. The translator requires `DEEPL_API` in the shell's environment.

## Transparency

This shell was developed with LLM assistance under my supervision. I direct the design, review the changes, and test them on my own desktop. These are personal dotfiles, so review and adapt them before using them on yours.

## TODO

- [ ] 1. Some sort of clock popup to replace notications when checking clock in barless mode
- [ ] 2. Weather widget looks overhaul = At the moment it's just copy of Waybar tooltip so it need some makeup
- [ ] 3. Barless mode: Draw a watermark-like text in bottom righ with text "Zen Mode is enabled"
