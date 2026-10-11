import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/station.dart';
import 'favorites.dart';
import 'radio_browser.dart';

/// Plays radio streams in the background (notification + lock screen controls)
/// and runs the sleep timer.
class RadioPlayer extends ChangeNotifier {
  RadioPlayer(this._api, this._favorites) {
    _init();
  }

  final RadioBrowser _api;
  final Favorites _favorites;
  final AudioPlayer _player = AudioPlayer();

  Station? station;
  String? nowPlaying;
  String? error;
  bool get playing => _player.playing;
  bool get loading =>
      _player.playing &&
      (_player.processingState == ProcessingState.loading ||
          _player.processingState == ProcessingState.buffering);

  Timer? _sleepTimer;
  Timer? _sleepTicker;
  DateTime? sleepAt;

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _player.playerStateStream.listen((_) => notifyListeners());
    _player.icyMetadataStream.listen((m) {
      final title = m?.info?.title?.trim();
      nowPlaying = (title == null || title.isEmpty) ? null : title;
      notifyListeners();
    });
    _player.playbackEventStream.listen((_) {}, onError: (Object e, _) {
      error = 'Bu istasyon şu an çalınamıyor.';
      notifyListeners();
    });
  }

  Future<void> play(Station s) async {
    station = s;
    nowPlaying = null;
    error = null;
    notifyListeners();
    _favorites.addRecent(s);
    unawaited(_api.registerClick(s.uuid));
    try {
      await _player.setAudioSource(AudioSource.uri(
        Uri.parse(s.url),
        tag: MediaItem(
          id: s.uuid,
          title: s.name,
          artist: s.country,
          artUri: s.favicon.startsWith('http') ? Uri.tryParse(s.favicon) : null,
        ),
      ));
      unawaited(_player.play());
    } catch (e) {
      error = 'Bu istasyon şu an çalınamıyor.';
      notifyListeners();
    }
  }

  Future<void> toggle() async {
    if (station == null) return;
    if (_player.playing) {
      await _player.stop();
    } else {
      // Live streams: reconnect instead of resuming stale buffered audio.
      await play(station!);
    }
  }

  Future<void> stop() => _player.stop();

  // ---- Sleep timer ----

  void setSleepTimer(int? minutes) {
    _sleepTimer?.cancel();
    _sleepTicker?.cancel();
    sleepAt = null;
    if (minutes != null) {
      sleepAt = DateTime.now().add(Duration(minutes: minutes));
      _sleepTimer = Timer(Duration(minutes: minutes), _fadeOutAndStop);
      _sleepTicker =
          Timer.periodic(const Duration(seconds: 30), (_) => notifyListeners());
    }
    notifyListeners();
  }

  Future<void> _fadeOutAndStop() async {
    _sleepTicker?.cancel();
    for (var v = 1.0; v > 0; v -= 0.1) {
      await _player.setVolume(v);
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    await _player.stop();
    await _player.setVolume(1.0);
    sleepAt = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
