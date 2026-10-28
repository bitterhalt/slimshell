# Install Slimshell

Slimshell runs inside an existing Niri session. It does not install or replace
your compositor configuration.

## 1. Install dependencies

Install these using your distribution's package manager:

- Niri and a current Qt 6 build of [Quickshell](https://quickshell.org/docs/guide/install-setup/),
  including its Wayland, PipeWire, Networking, Bluetooth, UPower, Polkit and PAM modules.
- PipeWire, NetworkManager, BlueZ, UPower and polkit, with the relevant services running.
- Symbols Nerd Font Mono for icons, plus your preferred text font.
- Git to clone the repository.

Additional tools are needed only for the features you use:

| Feature                    | Dependencies                                                              |
| -------------------------- | ------------------------------------------------------------------------- |
| Clipboard history          | `cliphist`, `wl-clipboard`                                                |
| File search and Run mode   | `fd`; file opening also uses `file`, `xdg-open`, a terminal and an editor |
| Administrator file editing | `sudo` with permission to use `sudoedit`                                  |
| Calculator                 | `qalc`, `wl-copy`                                                         |
| Emoji                      | An emoji list, described below; `wl-copy` to copy selections              |
| Timers                     | systemd user services and `notify-send`                                   |
| Audio card profiles        | `pactl` and PipeWire's PulseAudio compatibility service                   |
| Screen recording           | `gpu-screen-recorder`, `notify-send`                                      |
| Wallpaper picker           | Python 3, ImageMagick (`magick`), `awww`; Hellwal for generated colors    |
| Translation                | Python 3, `wl-copy`, and a DeepL API key                                  |
| Locking and suspension     | Linux-PAM, Bash and systemd/logind; see the lock-screen check below       |

`notify-send` is usually supplied by a package named `libnotify`. Some distributions
install `fd` under a different command name; Slimshell expects `fd` on `PATH`.
The default terminal/editor are `foot` and `nvim`; set `TERMINAL` and `EDITOR` before
starting the shell to use other executables.

## 2. Install the configuration

Back up any existing `~/.config/quickshell` first. Then clone into that exact path:

```sh
mkdir -p ~/.config
git clone https://github.com/bitterhalt/slimshell.git ~/.config/quickshell
```

Several helpers currently expect `~/.config/quickshell`, so do not install into a
named subconfiguration or another directory unless you also adjust those paths.

Review `Config.qml` for appearance and defaults. Optional commands in
`menus/MainMenu.qml` still include local tools such as `sup`, `vopen` and
`tmux-sysmon.sh`; replace or remove entries you do not use. Your own dmenu scripts
are independent of these built-in menus.

## 3. Try it in your Niri session

Stop any other notification daemon, such as Mako or Dunst, and avoid running a
second polkit authentication agent. Disable the old bar's autostart if replacing it.

```sh
qs -p "$HOME/.config/quickshell" --no-detailed-logs
```

Keep the terminal open to see errors. Press Ctrl+C to stop this foreground instance
before starting it another way.

### Check the lock screen

From another terminal, while Slimshell is running:

```sh
qs ipc call lock lock
```

Test that you can unlock before relying on automatic locking or suspension. The
bundled `lock/pam/quickshell-lock` policy uses `pam_unix` and `pam_faillock`; it may
need adapting to your distribution's authentication policy. Keep another way to
access your session while testing.

Idle defaults include automatic locking, monitor power-off and suspension. If you
want these disabled initially, set the three `idle*Timeout` defaults in `Config.qml`
to `0` before first launch. Existing saved settings take precedence over defaults.

## 4. Add Niri startup and keybindings

Add the following to your Niri configuration, merging the bindings into your
existing `binds` block:

```kdl
spawn-sh-at-startup "qs -n --no-detailed-logs"

binds {
    Mod+Space { spawn-sh "qs ipc call launcher toggle"; }
    Mod+V { spawn-sh "qs ipc call clipboard toggle"; }
    Mod+N { spawn-sh "qs ipc call notificationCenter toggle"; }
    Mod+Shift+L { spawn-sh "qs ipc call lock lock"; }
    XF86AudioRaiseVolume { spawn-sh "qs ipc call volume up"; }
    XF86AudioLowerVolume { spawn-sh "qs ipc call volume down"; }
    XF86AudioMute { spawn-sh "qs ipc call volume mute"; }
}
```

The startup command takes effect next session. Do not start a second copy if one
is already running. More IPC calls are listed in the [README](../README.md#features).

## 5. Set up optional features

### Clipboard history

Slimshell displays history but does not collect it. Add these Niri startup entries
if you do not already run clipboard watchers:

```kdl
spawn-at-startup "wl-paste" "--type" "text" "--watch" "cliphist" "store"
spawn-at-startup "wl-paste" "--type" "image" "--watch" "cliphist" "store"
```

### Wallpaper and colors

Put images in `~/Pictures/wallpaper`. The current wallpaper helper updates both
the desktop and an `overview` wallpaper, so it expects two `awww` instances:

```kdl
spawn-at-startup "awww-daemon"
spawn-sh-startup "awww-daemon --namespace overview"

layer-rule {
    match namespace="overview"
    place-within-backdrop true
}
```

Open the picker with `qs ipc call wallpaper open`. Generated wallpaper/lock-screen
images go into `~/.local/share/wall`. The shell uses its fallback palette until
Hellwal supplies `~/.cache/hellwal/colors.css`.

### Emoji

Place a UTF-8 list at `~/.local/share/emoji/emoji.txt`, with an emoji followed by
its search description on each line:

```text
🐀 rat
😀 grinning face
```

### Translation

Set `DEEPL_API` in the environment inherited by Slimshell before launching it.
Do not put the key in this repository or commit it to your configuration.

### Your own menus

Scripts can call `~/.config/quickshell/launcher/dmenu-runner` while Slimshell is
running. See the [dmenu examples](../README.md#dmenu-mode).

## Updating and troubleshooting

Update with `git -C ~/.config/quickshell pull --ff-only`. Preserve or commit your
local changes first; Git will refuse updates that would overwrite conflicting work.

If startup fails, run the foreground command from step 3 after stopping the existing
instance. Missing QML modules usually mean the installed Quickshell build is too old
or lacks a required integration. Missing icons usually mean the Nerd Font is absent.

Offline tests are available with `python -B tests/run.py` from the checkout.
They require Qt 6's `qmltestrunner` and do not start or reload the live shell.
