# Frontier Rift

Sprint 1 of a desktop and Android RTS on **Rift Engine**. The pinned toolchain is in [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

The match loop is offline. Windows and Android both start, save, and finish a match with no network. The only request is the optional **Test paketini indir** button in Settings, and it talks only to `raw.githubusercontent.com`. There is no telemetry and no startup online check.

## Play

Player steps are in [OYNA.md](OYNA.md). Download the installer or APK from the GitHub Actions artifacts on this branch. Do not look for a GitHub Release; this project does not publish tags or releases.

| Artifact | What it is |
| --- | --- |
| `FrontierRift-Windows-Setup` | Per-user NSIS installer. No admin. Opens the game window only. |
| `FrontierRift-Android-Debug` | arm64 debug APK. `INTERNET` is the only permission. |
| `FrontierRift-Linux` | Headless Linux export for smoke checks. |

## Offline smoke

- Windows: install, disconnect the network, start from the desktop shortcut, play level 1, save, quit, relaunch, and load. Settings → **Oyunu kaldır** is the only uninstall entry.
- Android: install the APK, turn networking off, play level 1, save and load. **Oyunu kaldır** opens Android’s own application-details screen for this package. Android’s dialog decides whether to delete the app.

## Security locks

- Game code may call `OS.create_process` in exactly one file, `scripts/platform/windows/uninstall_launch.gd`, and only for `unins000.exe` with no arguments after the installer-recorded SHA-256 matches. `OS.execute`, `OS.shell_open`, and `OS.execute_with_pipe` are banned. `tools/security_grep.sh` enforces this.
- The Android export excludes `scripts/platform/windows`. CI scans APK assets and fails if that Windows path is present.
- Android uninstall is a no-argument plugin method. The package name is read from the app context. The intent is `ACTION_APPLICATION_DETAILS_SETTINGS` for that package, so the manifest does not request `REQUEST_DELETE_PACKAGES`.
- APK permissions are `android.permission.INTERNET` only. `tools/check_android_preset.py` checks the preset; `tools/check_apk.sh` checks the built manifest.
- Android backup is off: `android:allowBackup="false"`, and full-backup plus data-extraction rules exclude every domain. CI fails if `allowBackup` is missing or true. Saves stay in app storage.
- Saves and downloaded packs stay in `user://`.
- Packs need an Ed25519 signature plus a SHA-256 match. A pack may contain only `.ctex`, `.png`, `.webp`, `.oggvorbisstr`, `.ogg`, `.import`, `.json`, and the signed manifest. Verification runs on device and does not need the network once the file is local.
- No keystore is committed. CI generates a debug keystore. The pinned toolchain is in [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

## Pack signing

The embedded key id is `TEST`. The private key is not in this repository.

To rotate it, generate an Ed25519 key locally, store the raw 32-byte hex or a PEM as the Actions secret `RIFT_PACK_SIGNING_KEY`, put the matching public hex in `scripts/security/pack_config.gd`, and run `tools/sign_pack.py`. If the secret’s public key does not match the embedded key, the script exits. CI without the secret only checks that `packs/smoke_test.manifest.json` still matches `packs/smoke_test.pck`.

## CI

GitHub Actions runs the security grep, headless tests, a Windows export plus per-user installer, a Linux export, then an Android debug APK. The Windows job finishes before the APK job starts.

## Licenses

Engine and third-party notices are in [THIRD_PARTY_LICENSES.txt](THIRD_PARTY_LICENSES.txt). In the game they are under Ayarlar → Lisanslar.
