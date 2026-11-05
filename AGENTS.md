# Slimshell repository guidance

## Live-desktop safety

- `~/.config/quickshell` symlinks to this checkout. Starting/reloading `qs`, calling its IPC, or restarting desktop services affects the running session; do so only when explicitly requested. `settings.json` and `menus.json` are watched live, so edits can take effect without a restart.
- `lock.qml` acquires a real Wayland session lock. Despite its name, `lock-test.qml` launches UI with the real `LockContext`/PAM, not an offline test. Use `tests/lock/` for safe verification.
- Runtime helpers assume installation at `~/.config/quickshell`; running wallpaper, clipboard, translation, or weather helpers directly can change desktop state, access personal data, or make network requests. Prefer mocked offline tests. Never print or commit `DEEPL_API`.

## Wiring and ownership

- `shell.qml` owns shared services and creates a `Bar` per screen. Keep feature logic out of `bar/Bar.qml`; bar modules are adapters to their popup/service, not owners of duplicate per-screen backend services.
- `components/PopupManager.qml` owns bar popup windows and their motion. `PopupMotion.qml` also serves standalone popups; keep surfaces mapped until close animations finish and preserve reopen-during-close behavior.
- Popups may be destroyed on close. Keep persistent selections/preferences in their controller/service, reset transient help/confirmation state, and release discovery/process resources on destruction. Preserve both keyboard and mouse controls.
- Use direct object calls internally; IPC is the external control boundary, with unique target names. Do not add dynamic QML module loading unless requested.

## Background work

- Long-running code (the shell, daemons, watchers) reacts to events instead of polling with a timer. Polling is the absolutely last resort

## Configuration boundaries

- `services/config/Schema.js` is the source of truth for `settings.json`, exposed by `services/Config.qml`. Some README settings prose is stale: animations currently expose only `enabled`; style/duration belong in each QML animation owner.
- Personal menu commands belong in root `menus.json`, validated by `menus/MenuSchema.js` and loaded by `MenuConfig.qml`. Lists are `user-menu1`–`user-menu4`; Power and built-in action handlers stay in `MainMenu.qml`. Preserve last-valid reload behavior and cancel stale selection/confirmation when lists change.
- UI preferences are separate from tracked defaults: `SettingsService.qml` writes `$XDG_DATA_HOME/quickshell-settings.json`, and Translator writes `quickshell-translator.json` (fallback directory `~/.local/share`). Do not overwrite these files while testing.
- Theme colors come from `ThemeService.qml`; Hellwal output in `~/.cache/hellwal/colors.css` is generated. Lock-screen weather only reads the weather cache; keep missing/invalid cache data harmless and avoid adding network requests to the locker.

## Verification

- No root build manifest or CI pipeline. From the repo root: `python -B tests/run.py` runs all offline suites; `python -B tests/run.py launcher menus` selects features; `python -B tests/run.py --list` lists them. The runner uses offscreen Qt, disables bytecode, and never starts/reloads the desktop shell.
- All tests and test-only fixtures belong in `tests/<feature>/`, not runtime folders. Register suites in `tests/run.py`. Python tests often copy real QML into temporary directories and replace integrations with doubles; moving runtime files/imports may require updating these extraction paths too.
- Single Python file: `python -B -m unittest discover -s tests/lock -p test_surface.py`. Single QML file: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/components/tst_PopupMotion.qml -o -,txt`.
- Use Qt 6 explicitly: `/usr/lib/qt6/bin/qmlformat -i FILE.qml`. The generic `qmlformat` on PATH can be an older parser that rejects valid functions/QML. `qmllint` does not reliably resolve Quickshell imports here; do not treat unresolved-import warnings as a clean gate.
- Before verification, format every QML file you changed (including test fixtures) with `/usr/lib/qt6/bin/qmlformat -i FILE.qml`. Keep routine formatting scoped to changed files; do not use `--sort-imports`, since import order can affect type resolution. Run the relevant offline tests after formatting.
- Python syntax without bytecode: `python -c 'import ast, pathlib; p=pathlib.Path("FILE"); ast.parse(p.read_text(), filename=str(p))'`. Finish edits with `git diff --check`.

## Documentation

- Keep README to basic features, usage, and structure; put setup details/examples in `assets/INSTALL.md`, not lengthy implementation explanations in README.
