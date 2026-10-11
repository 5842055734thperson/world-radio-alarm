import 'dart:async';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/station.dart';
import 'favorites.dart';
import 'radio_browser.dart';
import 'settings.dart';
import 'timeshift.dart';

/// Plays radio streams in the background (notification + lock screen controls),
/// keeps a rewindable timeshift buffer of the live stream, and runs the sleep timer.
class RadioPlayer extends ChangeNotifier {
  RadioPlayer(this._api, this._favorites, this._settings) {
    _init();
  }

  final RadioBrowser _api;
  final Favorites _favorites;
  final Settings _settings;
  final AudioPlayer _player = AudioPlayer();

  Station? station;
  String? nowPlaying;
  String? error;
  bool get playing => _player.playing;
  bool get loading =>
      _player.playing &&
      (_player.processingState == ProcessingState.loading ||
          _player.processingState == ProcessingState.buffering);

  // ---- Timeshift ----
  TimeshiftBuffer? _buffer;
  int _sourceStart = 0; // absolute buffer offset where the current source begins
  int _generation = 0; // guards against overlapping play() calls
  Timer? _ticker;
  Timer? _pausedTooLong;
  int _seekGeneration = 0;

  /// Lag (seconds) between the buffer's live edge and playback when we are
  /// "live". Servers send a burst of older audio on connect, so this is not 0.
  double _liveLag = 0;

  /// True when the current station is recorded and can be rewound.
  bool get canTimeshift => _buffer != null && !_buffer!.stopped;

  /// Seconds of audio that can be rewound.
  double get bufferedSeconds => canTimeshift ? _buffer!.bufferedSeconds : 0;

  /// Seconds between the buffer's live edge and what is being played.
  double get _rawLag {
    final b = _buffer;
    if (b == null) return 0;
    final playedBytes = _player.position.inMilliseconds / 1000 * b.byteRate;
    return (b.liveOffset - _sourceStart - playedBytes) / b.byteRate;
  }

  /// How far behind the live broadcast playback is, in seconds.
  double get behindSeconds {
    final b = _buffer;
    if (b == null) return 0;
    return (_rawLag - _liveLag).clamp(0.0, b.bufferedSeconds);
  }

  bool get isLive => behindSeconds < 8;

  Timer? _sleepTimer;
  Timer? _sleepTicker;
  DateTime? sleepAt;

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _player.playerStateStream.listen((_) => notifyListeners());
    _player.icyMetadataStream.listen((m) {
      if (_buffer != null) return; // titles come from the buffer instead
      final title = m?.info?.title?.trim();
      nowPlaying = (title == null || title.isEmpty) ? null : title;
      notifyListeners();
    });
    _player.playbackEventStream.listen((_) {}, onError: (Object e, _) {
      error = 'This station cannot be played right now.';
      notifyListeners();
    });
  }

  MediaItem _mediaItem(Station s) => MediaItem(
        id: s.uuid,
        title: s.name,
        artist: s.country,
        artUri: s.favicon.startsWith('http') ? Uri.tryParse(s.favicon) : null,
      );

  /// HLS playlists and Ogg/Opus can't be cut at arbitrary bytes; everything
  /// else (MP3, AAC) is recorded into the timeshift buffer.
  static bool _recordable(Station s) {
    final url = s.url.toLowerCase();
    final codec = s.codec.toLowerCase();
    if (url.contains('.m3u8') || codec.contains('ogg') || codec.contains('opus') || codec.contains('flac')) {
      return false;
    }
    return codec.isEmpty || codec.contains('mp3') || codec.contains('aac') || codec.contains('mpeg');
  }

  Future<void> play(Station s) async {
    final gen = ++_generation;
    _dropBuffer();
    station = s;
    nowPlaying = null;
    error = null;
    notifyListeners();
    _favorites.addRecent(s);
    unawaited(_api.registerClick(s.uuid));
    try {
      final minutes = _settings.timeshiftMinutes;
      if (minutes > 0 && _recordable(s)) {
        final buffer = TimeshiftBuffer(s.url, window: Duration(minutes: minutes), bitrateKbps: s.bitrate);
        try {
          await buffer.start();
        } catch (_) {
          buffer.stop();
          if (gen != _generation) return;
          return await _playDirect(s, gen); // server not recordable: plain streaming
        }
        if (gen != _generation) {
          buffer.stop();
          return;
        }
        _buffer = buffer;
        _sourceStart = buffer.firstOffset;
        await _player.setAudioSource(TimeshiftSource(buffer, _sourceStart, tag: _mediaItem(s)));
        // What we start with counts as "live", connect burst included.
        _liveLag = math.max(0, _rawLag);
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
        unawaited(_player.play());
      } else {
        await _playDirect(s, gen);
      }
    } catch (e) {
      if (gen != _generation) return;
      error = 'This station cannot be played right now.';
      notifyListeners();
    }
  }

  Future<void> _playDirect(Station s, int gen) async {
    await _player.setAudioSource(AudioSource.uri(Uri.parse(s.url), tag: _mediaItem(s)));
    if (gen == _generation) unawaited(_player.play());
  }

  void _tick() {
    final b = _buffer;
    if (b == null) return;
    final offset = _sourceStart + (_player.position.inMilliseconds / 1000 * b.byteRate).round();
    nowPlaying = b.titleAt(offset);
    notifyListeners();
  }

  void _dropBuffer() {
    _ticker?.cancel();
    _pausedTooLong?.cancel();
    _buffer?.stop();
    _buffer = null;
  }

  /// With a timeshift buffer: pause/resume (recording continues while paused).
  /// Without one: stop, and reconnect on play.
  Future<void> toggle() async {
    final s = station;
    if (s == null) return;
    if (_player.playing) {
      if (canTimeshift) {
        await _player.pause();
        // Don't keep downloading forever while paused.
        _pausedTooLong?.cancel();
        _pausedTooLong = Timer(Duration(minutes: _settings.timeshiftMinutes), _dropBuffer);
      } else {
        await _player.stop();
      }
    } else if (canTimeshift) {
      _pausedTooLong?.cancel();
      await _player.play();
    } else {
      await play(s);
    }
  }

  /// Jumps to [seconds] behind the live broadcast (0 = live).
  Future<void> seekBehind(double seconds) async {
    final b = _buffer;
    final s = station;
    if (b == null || s == null || b.stopped) return;
    final gen = ++_seekGeneration;
    // Keep at least a few seconds of data ahead so the player can buffer.
    final lagBytes = (seconds.clamp(0.0, b.bufferedSeconds) + math.max(_liveLag, 3.0)) * b.byteRate;
    final target = (b.liveOffset - lagBytes).round().clamp(b.firstOffset, b.liveOffset);
    _pausedTooLong?.cancel();
    try {
      // A fresh source flushes the player's read-ahead buffer.
      await _player.stop();
      if (gen != _seekGeneration) return;
      _sourceStart = target;
      await _player.setAudioSource(TimeshiftSource(b, target, tag: _mediaItem(s)));
      if (gen != _seekGeneration) return;
      unawaited(_player.play());
      error = null;
    } catch (e) {
      debugPrint('timeshift seek failed: $e');
      if (gen == _seekGeneration) error = 'Could not rewind this station.';
    }
    _tick();
    notifyListeners();
  }

  Future<void> stop() async {
    _dropBuffer();
    await _player.stop();
    notifyListeners();
  }

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
    _dropBuffer();
    _player.dispose();
    super.dispose();
  }
}
