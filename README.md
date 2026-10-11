# Dünya Radyo — World Radio Alarm

Android app (Flutter) to listen to radio stations from all over the world and
wake up to a station of your choice. The UI is in Turkish.

## Design

Minimal, brutalist, monochrome: pure black on white (light) or white on black (dark),
square corners, 2px borders, Space Grotesk titles and JetBrains Mono data text.
Theme follows the system or can be forced light/dark (the ◐ button).

## Features

- **World map home screen**: a line-only world map in the equal-area **Equal Earth**
  projection (no Mercator size distortion). The first view shows only land and sea;
  political borders fade in as you zoom. Pinch / +/- to zoom, drag to pan. Each square
  dot is a station; tap a dot to see the stations there, or tap a country to open all
  of its stations.

- **~50,000 stations** from the free [Radio Browser](https://www.radio-browser.info)
  directory: internet radios and the online streams of terrestrial (FM/AM) stations.
- **Discovery tree ("Ağ" tab)**, inspired by everynoise.com: start from a station; each tap
  plays a station and branches out to related ones — three from the same country (solid
  lines) and three from other countries (dashed lines). Long-press a box to fold its
  branches. Relatedness is estimated from shared genre tags, language and popularity
  (Radio Browser has no co-listening data). Long-press any station in a list, or use
  "Benzerlerini ağda keşfet" in the player, to start a tree from it.
- Search by name, filter by **country** (Türkiye by default, or the whole world) and **genre**.
- Background playback with notification / lock-screen controls, current song title (ICY metadata).
- **Favorites** (drag to reorder) and recently played stations.
- **Sleep timer** (15–120 min, fades out).
- **Radio alarm clock**
  - repeat on chosen weekdays or ring once
  - 30-second fade-in, full-screen wake-up screen over the lock screen, snooze (10 min) / stop
  - falls back to the phone's alarm tone when there is no internet or the stream fails
  - survives reboots; "test in 5 seconds" button
  - setup card that points to any Android setting that could block alarms
    (notifications, exact alarms, full-screen intent, battery optimization)

Stations that broadcast only over the air (no internet stream) cannot be played:
phones do not expose an FM tuner to apps.

## Install

Every push to `main` builds a signed APK in GitHub Actions
(`.github/workflows/build-apk.yml`) and publishes it as a GitHub Release
(`radio-v1.0.N`). Open the latest release on the phone, download
`DunyaRadyo-arm64.apk` (or the universal `DunyaRadyo.apk` for older 32-bit phones) and allow "install unknown apps" when Android asks.
New versions install over the old one and keep favorites and alarms: the release
signing key is generated on the first CI run and reused from the Actions cache (never committed).
If the cache is ever evicted, the next APK gets a new key and the old app must be uninstalled first.

## Structure

| Path | What |
|---|---|
| `lib/services/radio_browser.dart` | Radio Browser API client with mirror fallback |
| `lib/services/player.dart` | just_audio playback, sleep timer |
| `lib/services/alarms.dart` | Method-channel bridge to the native alarm engine |
| `lib/theme.dart`, `lib/widgets/brut.dart` | Brutalist theme and building blocks |
| `lib/map/world_map_data.dart`, `lib/pages/map_page.dart` | World map: outlines, projection, station dots, tap handling |
| `lib/services/similar.dart`, `lib/pages/graph_page.dart` | Related-station scoring and the discovery tree |
| `lib/services/geo_stations.dart` | Popular stations with coordinates (cached 3 days) |
| `lib/pages/` | Map, search, library, alarms, alarm editor, full-screen player |
| `assets/world.json` | Coastlines, borders and country shapes, built by `tool/build_map.py` from Natural Earth 1:50m |
| `android/app/src/main/kotlin/.../AlarmScheduler.kt` | Stores alarms, schedules `AlarmManager.setAlarmClock` |
| `android/app/src/main/kotlin/.../AlarmService.kt` | Foreground service: Media3 stream + fade-in + fallback tone |
| `android/app/src/main/kotlin/.../AlarmActivity.kt` | Lock-screen wake-up screen |

The alarm engine is native so it works while the Flutter UI is closed.

## Development

```bash
flutter pub get
flutter analyze && flutter test
flutter build apk --release
```

Fonts: Space Grotesk and JetBrains Mono (SIL Open Font License, see `assets/fonts/`).
Map data: Natural Earth (public domain).

Roadmap: Windows desktop build, iPadOS (needs a Mac or cloud build), station map.
