<p align="center">
  <img src="assets/slimshell.svg" alt="Slimshell: a slim rat walking along a thin bar" width="100%">
</p>

<p align="center">
  A compact, keyboard-first desktop shell for <a href="https://github.com/YaLTeR/niri">Niri</a>, built with <a href="https://quickshell.org/">Quickshell</a>.
</p>

<p align="center">
  <a href="#features">Features</a> · <a href="#launcher">Launcher</a> · <a href="#dmenu-mode">Dmenu mode</a> · <a href="#getting-started">Getting started</a>
</p>

## Small shell, personal choices

Slimshell brings my bar, notifications, and everyday menus together—replacing a collection of separate tools and increasingly complicated Bash scripts.

It is built for my own desktop: compact, opinionated, and comfortable to use from the keyboard. It isn't a desktop environment with endless customization or every bell and whistle. Borrow what you like, and adapt the rest.

## Features

|                     | What's included                                                                                              |
| ------------------- | ------------------------------------------------------------------------------------------------------------ |
| **Desktop**         | Per-screen bar, workspaces, window title, clock, weather, battery, and system tray                           |
| **Controls**        | Keyboard-driven Wi-Fi, Bluetooth, and audio popups; output, input, playback, and card profile tabs           |
| **Launch & pick**   | Application launcher, file search, calculator, binary runner, emoji, timers, and a stdin-driven dmenu picker |
| **Stay informed**   | Notifications, history, do-not-disturb, and Bluetooth connection and low-battery alerts                      |
| **Everyday tools**  | Clipboard history, DeepL translation, and fullscreen or region recording                                     |
| **Session & style** | Lock screen, power menu, idle timeouts, wallpaper picker, and Pywal themes                                   |

Menus support keyboard shortcuts and external control through IPC. For example:

```bash
qs ipc call network toggle
qs ipc call bluetooth toggle
```

## Launcher

One launcher, four modes. Switch directly with the shortcuts below, or cycle with **Ctrl+← / Ctrl+→**.

| Mode  | Shortcut | What it does                                             |
| ----- | -------- | -------------------------------------------------------- |
| Apps  | `Ctrl+A` | Search and launch desktop applications                   |
| Run   | `Ctrl+B` | Run binaries, with recently used commands first          |
| Emoji | `Ctrl+E` | Search by name and copy the selected emoji               |
| Timer | `Ctrl+T` | Start timers such as `25m Focus`, `45s`, `1:30`, or `2h` |

In Apps mode, `/needle` searches files and `=expression` calculates with `qalc`. Plain math works too.

**Enter** activates the selected result; **Esc** closes the launcher. Selecting a running timer cancels it.

## Dmenu mode

Give your existing menu scripts the same look as the launcher. Pipe in newline-separated choices; the selected line comes back on stdout.

```bash
printf '%s\n' Search 'New Note' TODO Delete |
  ./launcher/dmenu-runner -p "Notes" -l 4 --minimal-lines
```

- **Enter** returns the selected line; **Shift+Enter** returns your typed text.
- **Esc** cancels with exit status `1`.
- `--index` returns the selected entry's original zero-based input index instead of its text, even after filtering or sorting. Custom typed text returns `-1`.
- `-l N` / `--lines N` sets the row count (default **7**).
- `--minimal-lines` shrinks the menu to the number of input choices. Filtering doesn't resize it.
- `-l 0` shows the prompt and mode footer only; **Enter** returns typed text.

Oversized menus are limited to the screen height. Slimshell must already be running. The runner supports these options, not every dmenu or rofi flag.

## Getting started

The shell is designed for **Niri + Wayland**, with **Quickshell**, **PipeWire**, **NetworkManager**, **BlueZ**, and **UPower**. Icons use **Symbols Nerd Font Mono**.

Feature helpers use Python, `wl-clipboard`, `cliphist`, `gpu-screen-recorder`, ImageMagick, `awww`, and Pywal. The calculator uses `qalc`; audio card profiles need `pactl` and PipeWire's PulseAudio compatibility service. DeepL translation needs `DEEPL_API` in the shell's environment—keep credentials out of the repository.

Review the configuration before using it: menus include personal commands and paths. To launch this checkout from its root directory:

```bash
qs -p .
```

`Config.qml` holds settings such as font scale, bar geometry, popup spacing, and idle defaults. This is a personal configuration rather than a drop-in setup for every machine.

## Structure

```text
shell.qml       Shell entrypoint and service wiring
Config.qml      Shared appearance and behavior settings
bar/            Bar and its modules
components/     Reusable UI and popup components
services/       Shared desktop state and integrations
launcher/       Launcher, dmenu runner, and search helpers
menus/          System, theme, and wallpaper menus
notifications/  Notification popups and history
clipboard/      Clipboard picker and previews
lock/           Lock screen components and PAM setup
recorder/       Screen recording and region selection
translator/     DeepL translator
wallpaper/      Wallpaper helpers
weather/        Weather popup and helper
osd/            Volume overlay
```

Tests live beside the features they cover.

## Transparency

This shell was developed with LLM assistance under my supervision. I direct the design, review the changes, and test them on my own desktop. These are personal dotfiles, so review and adapt them before using them on yours.

## On the list

- [ ] A dedicated clock popup for barless mode, instead of opening notifications.
- [ ] A visual refresh for the weather widget.
- [ ] A subtle “Zen Mode is enabled” watermark in the bottom-right corner in barless mode.
