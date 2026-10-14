# Repository guidance

## Live configuration

- This checkout is the active `~/.config`; starting, reloading, or restarting Niri, QuickShell, Waybar, or user services changes the running desktop. Do so only when explicitly requested.
- Preserve unrelated local state and untracked files. In particular, do not overwrite `opencode/cli.json`.
- Treat `environment.d/30-secrets.conf` and `opencode/service.json` as credentials: never quote their values in output or copy them into other files.
- Some tracked paths are live symlinks, including `systemd/user/default.target.wants/*` and `zathura/colors-zathura`. Do not edit external or generated targets through them; Pywal output under `~/.cache/wal` is generated.
- There is no repository-wide build, test suite, CI workflow, or root package manifest. Verify only the area changed.

## Entrypoints and boundaries

- `niri/config.kdl` is the Niri entrypoint and composes the sibling KDL fragments; keep domain-specific settings in those fragments. `niri/startup.kdl` starts QuickShell with `qs --no-detailed-logs`.
- `quickshell/shell.qml` owns application-wide services and creates one `Bar` per screen. Shared state belongs in `quickshell/services/`, reusable UI in `quickshell/components/`, and feature code/helpers beside the feature in `quickshell/modules/`.
- Keep QuickShell feature logic out of `bar/Bar.qml` and global policy in `Config.qml`. Prefer direct QML object calls internally; reserve `IpcHandler` for external control and keep target names unique.
- Do not introduce dynamic QuickShell module/config loading unless requested. Preserve keyboard and mouse behavior when changing menus or popups.
- `nvim/init.lua` bootstraps Lazy.nvim, then loads `options`, `mappings`, and `plugins`; opening Neovim may install plugins or tools.

## Focused verification

- Niri: `niri validate -c niri/config.kdl`
- Shell syntax: `bash -n niri/scripts/*.sh waybar/scripts/*.sh`
- Neovim Lua formatting: `~/.local/share/nvim/mason/bin/stylua --check nvim`
- Lua syntax: `luac -p <changed-lua-files>`
- Python syntax without creating `__pycache__`: `python -c 'import ast, pathlib; p=pathlib.Path("FILE"); ast.parse(p.read_text(), filename=str(p))'`
- Do not use repository-wide Ruff, ShellCheck, shfmt, or `qmllint` as clean gates: the current tree has known pre-existing findings, and `qmllint` does not resolve the QuickShell imports reliably. A QuickShell runtime smoke test launches the live shell, so run one only when requested.

## Keep readmes clean

- README doesn't have to be an encyclopedia. Just list the basic features and structure without unnecessary technical jargon
