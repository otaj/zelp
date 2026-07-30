# Zelp (Flutter)

Android app for Amazfit/Zepp accounts: Bluetooth pairing keys for
[Gadgetbridge](https://gadgetbridge.org/basics/pairing/huami-xiaomi-server/),
GPS assistance downloads, optional `gps_uihh.bin` build, firmware checks and
downloads, and Apps / Watchfaces browsing.

Based on [huami-token](https://codeberg.org/argrento/huami-token/). Firmware
and market flows follow the same Amazfit paths as
[Zepp Explorer](../explorer), with devices from
[ZeppOS-DevicesList](https://github.com/melianmiko/ZeppOS-DevicesList).

Xiaomi Mi Fitness login is not included.

## Why “Zelp”?

**Zelp** is a portmanteau of **Zepp** + **help**.

## Tabs

1. **Credentials** — sign in (unlocks GPS / store tabs), pairing keys, download folder
2. **GPS** — GPS packs and optional `gps_uihh.bin` (sign-in required)
3. **Watchfaces** — watchface list for a watch model (sign-in required)
4. **Apps** — apps list for a watch model (sign-in required)
5. **Firmware** — firmware history and downloads (no sign-in)

GPS, Watchfaces, and Apps show a small lock mark and stay closed until you
sign in with **Remember credentials** on. Firmware is open without an account.

## Credentials

- Sign in with Amazfit email + password (real login). Pairing-key fetch is
  optional — keys are shown in the UI to copy or share, not saved as a file.
  You can sign in without fetching keys to unlock other tabs.
- Turn on **Remember credentials** so GPS / Watchfaces / Apps stay available.
- Choose where downloads are saved; clear folder with a confirmation that shows
  the file count.

## GPS

Pick the GPS pack types you want. Building `gps_uihh.bin` uses temporary packs
in memory and only saves that file unless you also check those pack types.

## Firmware

Pick a watch (compact chooser). If a model has more than one hardware variant,
pick which one to check. Release notes appear when available. Downloads go to
your folder after confirmation; already-downloaded files are called out clearly.

## Apps & Watchfaces

- Choose a **watch model** (not a raw hardware channel). Lists are saved on
  this device and only update when you tap **Update list**.
- Filter and sort (category, author, price, starred, last updated, size, name).
- Tap an item for **About** / **What’s new**, download, star, and copy link.
- Downloading stars the item by default; starred updates appear at the top
  after a list refresh.
- Update list is incremental: it re-reads the market list, but skips re-fetching
  details for unchanged free items that already have download info and About text.

## App icon

Custom Android launcher icon under `assets/icon/`.

## Requirements

- [FVM](https://fvm.app/) with Flutter `stable` (see `.fvmrc`)
- Android SDK (for device / APK builds)
- [pre-commit](https://pre-commit.com/) (for local lint, outdated-deps check, and Conventional Commits hooks)

## Setup

```bash
fvm use
fvm flutter pub get
```

## Run

```bash
fvm flutter run
```

## Analyze / format

```bash
fvm dart format .
fvm flutter analyze
./scripts/analyze_kotlin.sh   # detekt (same rules as `cd android && ./gradlew :app:analyze`)
```

## Test

```bash
fvm flutter test
```

Tests are unit-only (no real network). HTTP and file I/O are mocked or use
in-memory fixtures.

## Pre-commit hooks

Install hooks once after clone (formats/analyzes on commit; checks for outdated
direct/dev pub dependencies; Conventional Commits on `commit-msg`):

```bash
pre-commit install --hook-type pre-commit --hook-type commit-msg
```

There is no official [pre-commit](https://pre-commit.com/) framework hook for
`flutter pub outdated` (Flutter/Dart do not ship one either). The community
[`dart_pre_commit`](https://pub.dev/packages/dart_pre_commit) package has an
`outdated` task, but it is a Dart CLI wired through custom git scripts—not a
drop-in pre-commit repo—and would overlap this project's FVM format/analyze
hooks. Zelp uses a small local hook instead:

`scripts/check_pub_outdated.py` runs `fvm flutter pub outdated --json` and
**fails** when a direct or dev dependency:

- is discontinued, retracted, or affected by a security advisory, or
- has an **upgradable** version within current pubspec constraints
  (`current` ≠ `upgradable` — usually fixed by `fvm flutter pub upgrade`).

Transitive-only gaps and constraint-blocked majors (newer `resolvable`/`latest`
but not upgradable without editing constraints, and sometimes only via
prereleases) do not fail the hook.

Run against all files without committing:

```bash
pre-commit run --all-files
```

## Release build

```bash
fvm flutter build apk --release --split-per-abi
```

Publishing a GitHub Release runs `.github/workflows/release.yml`, which builds
per-ABI APKs and uploads them as `{app}-{version}-{abi}.apk` (for example
`zelp-1.0.0-arm64-v8a.apk`). CI and release workflows read the Flutter version
from `.fvmrc`.

## License

Zelp is free software: you can redistribute it and/or modify it under the terms
of the [GNU General Public License](LICENSE) as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.
