# SwiftFever Agent & Contributor Guide

## 1. Repository & Branching
- `origin`: `https://github.com/Dan1el-19/SwiftFever` (default branch: `private-fast`).
- `upstream`: `https://github.com/dkdknight/MPFever` (`main` mirrors upstream cleanly for rebases).
- Do all fork work on `private-fast`; never push directly to `main` unless syncing upstream.
- Always pass `-R Dan1el-19/SwiftFever` to `gh` CLI commands (local `gh` default may resolve to `upstream`).

## 2. Rebase Hygiene & Protected Upstream Files
Keep SwiftFever customizations isolated so upstream rebases stay clean:
- **Launcher branding & Bento theme tokens:** `launcher/ForkBrand.cs` (plus minimal hooks in `launcher/Ui.cs` and `launcher/MainForm.cs`).
- **In-game Midnight Cobalt overlay & toast-free chat:** `mod/mpfever_1/content/mpfever_swiftfever.lua` (plus minimal hooks in `mod/mpfever_1/content/mpfever_ui.script.lua`).
- **Do NOT edit** `launcher/lang.json`, `native/mpfever_native.cpp`, or `.github/workflows/release.yml` (upstream tests assert against them).
- Never commit untracked local scratch or configuration files. Keep GPL-3.0-or-later attribution (`by Dan1el-19 based on dkdknight`).

## 3. Test & Compatibility Invariants
- **Single version across 4 files** (`tests/check_repo.py`): `build.bat` (`VERSION`), `launcher/MainForm.cs` (`MainForm.Version`), `mod/mpfever_1/content/mpfever_common.lua` (`C.MODVERSION`), and the top entry of `docs/CHANGELOG.txt` must always match. Never introduce unrelated `X.Y.Z` versions in `mod/mpfever_1/_metadata/modinfo.json`.
- **Localization (`tests/test_lang.py`):** Every `T(...)` / `Tf(...)` call is checked against `launcher/lang.json`. In `mpfever_swiftfever.lua`, wrap fork-only strings in `sfT` / `sfTf` instead of bare `T` / `Tf`.
- **Lua 5.2 rules:** Transport Fever 3 and CI `lupa.lua52` run Lua 5.2. Keep zero backslashes (`\`) in mod `.lua` files (`string.char(92)` if needed), register every `content/` file in `mod/mpfever_1/_content.json`, and avoid adding top-level `local` variables in `mpfever_ui.script.lua` (`tests/test_locals.py`).
- **Signing policy check (`tests/test_signpolicy092.py`):** Preserve `"SignPath Foundation accepted MPFever"` in `README.md`.
- **Verification:** Run lightweight Python tests locally; Windows C#/C++ compilation and full `lupa` tests run in GitHub Actions CI.

## 4. Automated Releases & Launcher Auto-Update
- `launcher/Updater.cs` checks published (non-draft, non-prerelease) GitHub Releases on `Dan1el-19/SwiftFever`, comparing numeric versions (`0.9.7.2 > 0.9.7.1`) and matching `MPFever-<version>.zip` / `MPFever-<version>-server.zip` (never name relay archives `MPFever*.zip`).
- **1-command local release:**
  - `python3 tools/swiftfever_release.py` — auto-bumps the 4th version segment (`0.9.7.1` -> `0.9.7.2`), prepends a `docs/CHANGELOG.txt` entry from commits since the last `v*` tag, updates all 4 version files, commits, creates annotated tag `v<version>`, and pushes branch + tag (triggering `.github/workflows/swiftfever-release.yml`).
  - Options: explicit version (`python3 tools/swiftfever_release.py 0.9.8.1`), `-m "summary"`, `--dry-run`, `--no-push`, `--files-only`.
- **1-click GitHub UI release:** **Actions → SwiftFever Release → Run workflow** (`bump: auto` bumps, commits, tags, builds, tests, and publishes automatically; `bump: none` builds & publishes the current version).
