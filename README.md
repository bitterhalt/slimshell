<p align="center">
  <img src="assets/slimshell.svg" alt="Slimshell: a slim rat walking along a thin bar" width="100%">
</p>

<p align="center">
  A compact, keyboard-first desktop shell for <a href="https://github.com/YaLTeR/niri">Niri</a>, built with <a href="https://quickshell.org/">Quickshell</a>.
</p>

<p align="center">
  <a href="#features">Features</a> · <a href="#launcher">Launcher</a> · <a href="#dmenu-mode">Dmenu mode</a> · <a href="#getting-started">Getting started</a>
</p>

## Slimshell

Slimshell brings my bar, notifications, and some useful menus together—replacing a collection of separate tools and increasingly complicated Bash scripts.

It is built for my own desktop: compact, opinionated, and comfortable to use from the keyboard. It isn't a desktop environment with endless customization or every bell and whistle. Borrow what you like, and adapt the rest.

## Why?

Why does this exist? Because all the well-known Quickshell setups focus too much on large Material Design Menus and features that, at the end of the day, no productive user actually needs. If a widget has functions, it must also work 100% with the keyboard. Bluetooth or the Wi-Fi menus do not need to take half of your 1440p screen space. So the goal was simple = Make the most of the best features of the Quickshell in terms of usability and lightness.

## Features

|              | What's included                                                                                 |
| ------------ | ----------------------------------------------------------------------------------------------- |
| **Bar**      | Workspaces, Window title, Clock, Battery, Connections, Tray etc.                                |
| **Menus**    | Keyboard-driven menus for Bluetooth, Wi-Fi, Audio, Power, and Notifications                     |
| **launcher** | Application launcher with: File Search, Calculator, Binary Runner, Emoji, Timers and Dmenu-mode |
| **Tools**    | Clipboard, DeepL translation, and Screen recording                                              |
| **Session**  | Lock Screen, Wallpaper Picker, and Dynamic theming with [Hellwal](https://hellwal.danihek.xyz/) |

<details>
<summary>IPC reference</summary>

| Target               | Calls                                                                  | Effect                                                   |
| -------------------- | ---------------------------------------------------------------------- | -------------------------------------------------------- |
| `Audio`              | `toggle`, `open`, `close`                                              | Show or hide the audio popup                             |
| `Bar`                | `toggle`, `hide`, `show`, `isVisible`                                  | Control or query bar visibility                          |
| `Bluetooth`          | `toggle`, `open`, `close`                                              | Show or hide the Bluetooth popup                         |
| `Clipboard`          | `toggle`, `open`, `close`, `refresh`, `copySelected`, `deleteSelected` | Control the clipboard picker                             |
| `Idle`               | `toggle`, `isDisabled`, `settings`                                     | Control idle handling or open its settings               |
| `Launcher`           | `toggle`, `open`, `close`                                              | Control the application launcher                         |
| `Lock`               | `lock`                                                                 | Lock the session                                         |
| `Locker`             | `isSecure`                                                             | Query whether the separate lock-screen process is secure |
| `Menu`               | `packages`, `settings`, `system`, `close`                              | Open a main-menu page or close it                        |
| `Network`            | `toggle`, `open`, `close`                                              | Show or hide the network popup                           |
| `NotificationCenter` | `toggle`, `open`, `close`                                              | Show or hide notification history                        |
| `Notifications`      | `toggleDnd`, `enableDnd`, `disableDnd`, `isDnd`, `clear`, `count`      | Control DND or notification history                      |
| `Power`              | `toggle`, `open`, `close`                                              | Control the power menu                                   |
| `Recorder`           | `toggle`, `open`, `close`, `fullscreen`, `region`, `stop`              | Control screen recording                                 |
| `Theme`              | `refresh`, `usingHellwal`                                              | Reload or query the active theme                         |
| `Translator`         | `toggle`, `open`, `close`                                              | Control the translator                                   |
| `Volume`             | `up`, `down`, `mute`                                                   | Adjust or mute the default audio output; shows the OSD   |
| `Wallpaper`          | `toggle`, `open`, `close`, `refresh`                                   | Control the wallpaper picker or refresh wallpapers       |

For example, `qs ipc call volume up` raises the volume by one step. `launcher/dmenu-runner` uses the launcher's IPC internally; call the script to open a picker.

</details>

## Launcher

Launcher modes. Switch directly with the shortcuts below, or cycle with **Ctrl+← / Ctrl+→**.

| Mode  | Shortcut | What it does                                             |
| ----- | -------- | -------------------------------------------------------- |
| Apps  | `Ctrl+A` | Search and launch desktop applications                   |
| Run   | `Ctrl+B` | Run binaries, with recently used commands first          |
| Emoji | `Ctrl+E` | Search by name and copy the selected emoji               |
| Timer | `Ctrl+T` | Start timers such as `25m Focus`, `45s`, `1:30`, or `2h` |

In Apps mode, `/<word>` searches files and `=expression` calculates with `qalc`. Plain math works too.

## Dmenu mode

For scripts that use dmenu-style pickers:

```bash
printf '%s\n' Search 'New Note' TODO Delete | ./launcher/dmenu-runner -p "Notes" -l 4 --minimal-lines
```

- Supported options: `-p` / `--prompt`, `-l N` / `--lines N` (default 7), `--minimal-lines`, and `--index` (return the original zero-based input index; typed text returns `-1`).
- Enter selects, Shift+Enter returns typed text, and Esc cancels with status 1. `-l 0` opens an input-only picker.

Slimshell must be running. This is a small dmenu-compatible runner, not a full dmenu/rofi replacement.

## Getting started

### Required

- 🧠 with some common sense
- [Niri](https://github.com/YaLTeR/niri)
- [Quickshell](https://quickshell.org/)
- PipeWire
- NetworkManager
- BlueZ
- UPower
- Symbols Nerd Font Mono (icons)

### Optional features

- Python, `wl-clipboard`, and `cliphist` for helper scripts and clipboard history
- `gpu-screen-recorder` for screen recording
- ImageMagick, `awww`, and Hellwal for wallpaper colors
- `qalc` for launcher calculations
- `pactl` and PipeWire's PulseAudio compatibility service for audio card profiles
- `DEEPL_API` in your environment for DeepL translation

Review the configuration before using it: menus include personal commands and paths. To launch this checkout from its root directory:

```bash
qs -p .
```

## Settings

Lives inside `Config.qml` holds settings such as font scale, bar geometry, popup spacing, and idle defaults.

## Structure

```text
shell.qml       Shell entrypoint and service wiring
Config.qml      Shared appearance and behavior settings
bar/            Bar and its modules
components/     Reusable UI and popup components
services/       Shared desktop state and integrations
launcher/       Launcher, dmenu runner, and search helpers
menus/          System and wallpaper menus
notifications/  Notification popups and history
clipboard/      Clipboard picker and previews
lock/           Lock screen components and PAM setup
recorder/       Screen recording and region selection
translator/     DeepL translator
wallpaper/      Wallpaper helpers
osd/            Volume overlay
```

## Transparency

This shell was developed with LLM assistance under my supervision. I direct the design, review the changes, and test them on my own desktop. These are personal dotfiles, so review and adapt them before using them on yours.

This repository is mainly for hobby and learning, so don't expect everything to work out of the box.

## Screenshots and more

Check out [my config](https://github.com/bitterhalt/dotfiles).

## ISSUES 🔨

- dmenu-runner can't display special symbols (Nerd fonts etc.)
- File structure is messy and files needs to be commented better
- There are probably plenty of other things as well. Maybe yoy can show me how to fix them or do better :)

## TODO

- [ ] Put there something
