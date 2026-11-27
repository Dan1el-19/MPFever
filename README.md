# SwiftFever – Performance-Optimized Multiplayer for Transport Fever 3

**Play Transport Fever 3 together with lower sync overhead, a streamlined Midnight Cobalt launcher, and an ultra-compact in-game HUD — based on [MPFever](https://github.com/dkdknight/MPFever) by dkdknight.**

[![Latest release](https://img.shields.io/github/v/release/Dan1el-19/SwiftFever?label=download)](https://github.com/Dan1el-19/SwiftFever/releases/latest)
[![CI](https://github.com/Dan1el-19/SwiftFever/actions/workflows/ci.yml/badge.svg?branch=private-fast)](https://github.com/Dan1el-19/SwiftFever/actions/workflows/ci.yml)
[![Game Build](https://img.shields.io/badge/Transport%20Fever%203-build%2040444-3B82F6)](#before-you-start)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/license-GPL--3.0--or--later-green)](LICENSE)

Each player runs their own copy of Transport Fever 3. SwiftFever replays every player's actions across all connected games at the same game step, checks state hashes, and keeps companies, infrastructure, and simulation pace aligned.

> **Branch & development note:** Active SwiftFever work lives on **`private-fast`** (`main` mirrors upstream `dkdknight/MPFever` for clean rebases). Always back up your savegames before long sessions.

---

## Contents

- [What SwiftFever changes over MPFever](#what-swiftfever-changes-over-mpfever)
- [Before you start](#before-you-start)
- [Install and play](#install-and-play)
- [Multiplayer features](#multiplayer-features)
- [Relay & dedicated server](#relay--dedicated-server)
- [Troubleshooting & diagnostics](#troubleshooting--diagnostics)
- [Building & testing](#building--testing)
- [Privacy & upstream code signing note](#privacy--upstream-code-signing-note)
- [Credits and license](#credits-and-license)

---

## What SwiftFever changes over MPFever

1. **Private Fast performance tuning (`MPFEVER_PRIVATE_FAST`)**
   - Reduces checksum, diagnostic, and sync overhead for smoother private multiplayer sessions (9 structural audit groups rotated sequentially).
   - Smarter soft drift recovery (Option B resync decision) to avoid unnecessary full-world reloads during minor transient drift.
2. **Redesigned Midnight Cobalt Bento Launcher**
   - Unified header bar combining launch/session controls, speed selector, `⚙ Settings`, and language picker.
   - Asymmetric telemetry Bento grid (`Players`, `Speed`, `Actions relayed`, elevated `Sync`), sunken log console, and clean status footer (`by Dan1el-19 based on dkdknight`).
   - Preserves the legacy `--dev` / `--server` / `MPFEVER_CONNCARD=1` views for automated tests and dedicated server management.
3. **Ultra-Compact In-Game Overlay (`420px` HUD / `240px` Mini Card)**
   - Midnight Cobalt Neo-Minimalist palette applied consistently to the quick window, `The Hub`, pause menu cards, and bottom HUD bar pill (`SwiftFever`).
   - Combined `Sync` + `Speed` status header, compact `Players` card, and single-row action strip (`Resync` + map pings).
   - Floating top-left `ChatToast` popup is disabled by default so it stays out of the way (messages and system notices stay inside the `Chat` tab).
   - Opt-out flags via environment/settings: `MPFEVER_SWIFTUI=0` restores the stock MPFever overlay; `MPFEVER_CHATTOAST=1` re-enables the floating chat toast.

---

## Before you start

| Requirement | Why |
|---|---|
| **Transport Fever 3 on Windows (Steam, GOG, or Epic Games Store)** | Cross-store multiplayer works out of the box (join via IP/relay address on any store, or Steam invites on Steam). |
| **Game build 40444 (compatible)** | Works with **Transport Fever 3 build 40444** (current) as well as earlier builds **40425**, **40423**, and **40420**. Every player in a session must run the exact same game build. |
| **Same DLCs on every PC** | Deluxe / pre-order packs add entities only on PCs that own them, which causes drift unless switched off or matched across players. |
| **Same SwiftFever / mod versions** | All players need the same SwiftFever build and the same world/gameplay mods (`personal` UI-only mods can stay local). |

---

## Install and play

1. Download the latest archive from [Releases](https://github.com/Dan1el-19/SwiftFever/releases/latest) (or build from source with `build.bat`).
2. **Extract the entire folder** somewhere accessible and always run `MPFever.exe` from inside that folder (never move the `.exe` out alone).
3. Launch `MPFever.exe` — it detects `TransportFever3.exe`, installs the mod (`mod/mpfever_1`) and native proxy (`winhttp.dll`), and starts the game.
4. On the game's main menu, open **Multiplayer** to host a savegame (co-op or separate companies) or join a host/relay address.
5. In-game, click **`SwiftFever`** on the bottom HUD bar to toggle the `420px` overlay, shrink to the `240px` Mini card, or open **The Hub** for full company, rules, trade, and rankings pages.

**Ports:** By default TCP port `28090` is used (UPnP attempted automatically). If your ISP uses CGNAT, use IPv6, manual port forwarding, or the included `mpfever-relay` (see [docs/RELAY.md](docs/RELAY.md)).

---

## Multiplayer features

SwiftFever keeps all core MPFever gameplay systems intact:

- **Two modes:** Shared company (co-op) or One company per player (independent money, vehicles, lines, loans, track/station/depot sharing rules & tolls, auctions, mergers, and experimental AI competitors).
- **Full build & action replication:** Roads, tracks, trams, signals, stations, depots, terrain edits, trees, bulldozer, vehicle purchases, line assignments, speed & pause, plus build previews in player colours.
- **Self-healing sync:** Periodic state comparison and automatic money/desync recovery, plus manual **Resync** for the host.
- **Mod Hub & optional rules (`0.6`):** Auto-checks mods in the lobby, exposes optional gameplay modules (journals, rankings, market shares, territories, tenders, trade, stocks, permissions), and supports all 13 game languages.

---

## Relay & dedicated server

- **Dedicated server (`--server`):** Run a headless or windowed world host on a dedicated Windows machine via `MPFever-<version>-server.zip`. See [docs/SERVER.txt](docs/SERVER.txt).
- **Relay (`relay/`):** Lightweight `.NET 9` TCP relay (`mpfever-relay` for Linux/Windows/Docker) allowing hosts behind NAT/CGNAT to share a single stable relay endpoint without opening inbound router ports. See [docs/RELAY.md](docs/RELAY.md).

---

## Troubleshooting & diagnostics

| Symptom | Check |
|---|---|
| Repeated resyncs without building | Verify every player has the exact same game build (`40444`), identical DLCs, and matching non-personal mods. |
| `MPFever.exe is not in a version folder` / `winhttp.dll missing` | Extract the full release zip rather than running `MPFever.exe` standalone. |
| `nvngx` / native signatures mismatch after a game patch | Verify signatures against your `TransportFever3.exe` using `python tools\mksigs.py check "<path>\TransportFever3.exe"`. |

To gather logs after an issue, click **Report a problem** in the launcher or in the in-game `Settings` tab.

---

## Building & testing

Windows 10/11 with Visual Studio 2022+ (*Desktop development with C++* + *.NET Framework 4.8*), Python 3 with `lupa` (`pip install lupa`), and `.NET 9` SDK (for `relay/`):

```bat
build.bat
```

Automated checks (`python tests\run_all.py --exe launcher\bin\Release\MPFever.exe`):
- `tests\check_repo.py` — version alignment, `_content.json`, JSON/Python/Lua 5.2 validation, UTF-8 & conflict-marker checks.
- `tests\test_lockstep.py`, `tests\test_companies.py`, `tests\test_assets.py` — simulated lockstep, company economics, and asset sync.
- `tests\test_locals.py`, `tests\test_lang.py` — Lua 5.2 local variable limit & 11-language coverage.
- `MPFever.exe --selftest` — launcher self-tests (relay, client/server config, updates, UPnP, report redaction).

---

## Privacy & upstream code signing note

SwiftFever collects no analytics or accounts. Network connections are limited to explicit multiplayer sessions/relays, optional GitHub release update checks (`autoupdate=0` disables), `api.ipify.org`, UPnP, and optional public server list queries (see [docs/PRIVACY.txt](docs/PRIVACY.txt)).

*Upstream signing note:* SignPath Foundation accepted MPFever for upstream official releases built from `dkdknight/MPFever`. Fork builds on `Dan1el-19/SwiftFever` are unsigned unless signed locally or via your own CI pipeline.

---

## Credits and license

**SwiftFever** is maintained by **[Dan1el-19](https://github.com/Dan1el-19/SwiftFever)**, based on **[MPFever](https://github.com/dkdknight/MPFever)** by **[dkdknight](https://github.com/dkdknight)** and the upstream contributors:

- **[dkdknight](https://github.com/dkdknight)** — creator and maintainer of MPFever.
- **[SlikerDev](https://github.com/SlikerDev)** — dedicated server, auto-updates, IPv6, launcher foundation, 13-language translations, in-game window & chat.
- **[Steelworm](https://github.com/Steelworm)** — build timing fixes, builder lead, deep issue analyses.
- **[ampynjord](https://github.com/ampynjord)** — `mpfever-relay` and relay hosting support.
- **[Juliansgith](https://github.com/Juliansgith)** — TPF3-MP order fixes, smooth pacing, signatures, company rules, faster saves/connections (MIT).

Licensed under the **[GNU General Public License v3](LICENSE)** (`GPL-3.0-or-later`; versions up to `0.4.5` and TPF3-MP components remain under MIT — see [NOTICE.txt](NOTICE.txt)).

*SwiftFever and MPFever are not affiliated with Urban Games. Transport Fever 3 is a trademark of its owners.*
