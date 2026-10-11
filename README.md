# World Radio — radio alarm clock

Android app (Flutter) to listen to radio stations from all over the world and
wake up to a station of your choice. The UI is in English.

## Design

Minimal, brutalist, monochrome: pure black on white (light) or white on black (dark),
square corners, 2px borders, set in Chillax (JetBrains Mono for clock digits).
Theme follows the system or can be forced light/dark (the ◐ button).

## Features

- **World map home screen**: a line-only world map in the **Mercator** projection (down to
  80°S, Antarctica included), which tiles seamlessly as the map repeats sideways. The first view shows only land and sea;
  political borders fade in as you zoom. Pinch to zoom, drag to pan; the map repeats
  endlessly to the left and right. Each square
  dot is a station; tap a dot to see the stations there, or tap a country to open all
  of its stations.

- **~50,000 stations** from the free [Radio Browser](https://www.radio-browser.info)
  directory: internet radios and the online streams of terrestrial (FM/AM) stations.
- **Discover tree**, inspired by everynoise.com. Opening the tab starts from the station
  that is playing; when nothing plays it starts from a "For you" node with suggestions
  based on recently played and favorite stations. Each tap plays a
  station and branches out to related ones — three from the same country (solid lines)
  and three from other countries (dashed lines). Hold a box to fold its branches.
  Relatedness is estimated from shared genre tags, language and popularity (Radio
  Browser has no co-listening data). Long-press any station, or use "Discover similar
  stations" in the player, to start from it.
- Search by name, filter by **country** (Türkiye by default, or the whole world) and **genre**.
- Background playback with notification / lock-screen controls, current song title (ICY metadata).
- **Library** (under Discover): favorites (drag to reorder) and recently played stations.
- **Settings** (button on the map and in the player) open a small floating panel: theme
  (auto / light / dark) and the timeshift buffer length.
- **Timeshift (rewind live radio)**: the live MP3/AAC stream is recorded into a rolling
  15- or 30-minute in-memory buffer (settings panel; off is possible). Pause really
  pauses, the player shows how far behind live you are, and you drag the rewind bar to
  move through the buffer (the right end is live). Song titles (ICY metadata) follow the rewound
  position. HLS/Ogg streams and servers that can't be recorded fall back to normal live
  playback.
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

## Offline catalog

Radio Browser sometimes goes down. Every query then falls back to an offline catalog:
the ~8,000 most popular stations, fetched at build time by `tool/snapshot_stations.py`
into `assets/stations.json` (the last good snapshot is reused from the CI cache when the
directory is unreachable during a build), plus the map stations cached on the device and
the user's favorites. Search, the country list, the map and Discover keep working, and
the UI says when it is showing the offline catalog.

## Install

Every push to `main` builds a signed APK in GitHub Actions
(`.github/workflows/build-apk.yml`) and publishes it as a GitHub Release
(`radio-v1.0.N`). Open the latest release on the phone, download
`WorldRadio-arm64.apk` (or the universal `WorldRadio.apk` for older 32-bit phones) and allow "install unknown apps" when Android asks.
New versions install over the old one and keep favorites and alarms: the release
signing key is generated on the first CI run and reused from the Actions cache (never committed).
If the cache is ever evicted, the next APK gets a new key and the old app must be uninstalled first.

## Structure

| Path | What |
|---|---|
| `lib/services/radio_browser.dart` | Radio Browser API client with mirror fallback |
| `lib/services/player.dart` | just_audio playback, timeshift control, sleep timer |
| `lib/services/timeshift.dart` | Rolling stream recorder (ICY de-interleaving) and player source |
| `lib/services/alarms.dart` | Method-channel bridge to the native alarm engine |
| `lib/theme.dart`, `lib/widgets/brut.dart` | Brutalist theme and building blocks |
| `lib/map/world_map_data.dart`, `lib/pages/map_page.dart` | World map: outlines, projection, station dots, tap handling |
| `lib/services/similar.dart`, `lib/pages/graph_page.dart` | Related-station scoring and the Discover tree |
| `lib/services/geo_stations.dart` | Popular stations with coordinates (cached 3 days) |
| `lib/pages/` | Map, search, library, alarms, alarm editor, full-screen player |
| `assets/world.json` | Coastlines, borders and country shapes, built by `tool/build_map.py` from Natural Earth 1:50m |
| `android/app/src/main/kotlin/.../AlarmScheduler.kt` | Stores alarms, schedules `AlarmManager.setAlarmClock` |
| `android/app/src/main/kotlin/.../AlarmService.kt` | Foreground service: Media3 stream + fade-in + fallback tone |
| `android/app/src/main/kotlin/.../AlarmActivity.kt` | Lock-screen wake-up screen |

The alarm engine is native so it works while the Flutter UI is closed.

## Development

```bash
tool/get_fonts.sh                 # downloads Chillax into assets/fonts/
python3 tool/snapshot_stations.py # offline station catalog (assets/stations.json)
flutter pub get
flutter analyze && flutter test
flutter build apk --release
```

Fonts: Chillax by Indian Type Foundry (ITF Free Font License, from fontshare.com) is
downloaded at build time by `tool/get_fonts.sh` and embedded in the APK, but not committed,
since the license does not allow redistributing the font files. Run the script once before
building locally. JetBrains Mono (SIL Open Font License) is in `assets/fonts/`.
Map data: Natural Earth (public domain).

Roadmap: Windows desktop build, iPadOS (needs a Mac or cloud build), station map.
