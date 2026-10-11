// StreamAudioSource is marked experimental in just_audio but is the supported
// way to feed custom bytes to the player on Android.
// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

/// Records a live MP3/AAC stream into a rolling in-memory buffer (the last
/// [window] of audio) so playback can pause, rewind and catch up to live.
///
/// Byte offsets are absolute (counted since the recording started). Time is
/// derived from the stream's byte rate, which is constant for the CBR
/// streams most stations use.
class TimeshiftBuffer {
  TimeshiftBuffer(this.url, {required this.window, int bitrateKbps = 0})
      : _declaredByteRate = bitrateKbps > 0 ? bitrateKbps * 125.0 : null;

  final String url;
  final Duration window;
  final double? _declaredByteRate;

  /// Hard memory cap regardless of window and bitrate.
  static const maxBytes = 48 * 1024 * 1024;

  final List<_Chunk> _chunks = [];
  final List<(int, String)> _titles = []; // (offset, StreamTitle)
  final _grew = StreamController<void>.broadcast();
  http.Client? _client;
  StreamSubscription<List<int>>? _sub;
  bool _stopped = false;
  DateTime? _startedAt;
  String contentType = 'audio/mpeg';

  // ICY metadata de-interleaving state.
  int _metaInt = 0;
  int _audioLeft = 0;
  int _metaLeft = -1; // -1: expecting the length byte
  final _meta = BytesBuilder();

  /// First and one-past-last buffered byte offsets.
  int get firstOffset => _chunks.isEmpty ? _total : _chunks.first.start;
  int get liveOffset => _total;
  int _total = 0;

  double get byteRate {
    final d = _declaredByteRate;
    if (d != null) return d;
    final started = _startedAt;
    if (started == null) return 16000;
    final secs = DateTime.now().difference(started).inMilliseconds / 1000;
    // Early on the server's connect burst inflates the measured rate.
    return secs < 8 ? 16000 : math.max(4000.0, _total / secs);
  }

  /// Seconds of audio currently buffered.
  double get bufferedSeconds => (liveOffset - firstOffset) / byteRate;

  /// Connects and waits for the first audio bytes. Throws if the stream
  /// cannot be recorded (unsupported server, no data within the timeout).
  Future<void> start() async {
    _client = http.Client();
    final req = http.Request('GET', Uri.parse(url))
      ..headers['Icy-MetaData'] = '1'
      ..headers['User-Agent'] = 'WorldRadioAlarm/1.0';
    final res = await _client!.send(req).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final type = res.headers['content-type'] ?? 'audio/mpeg';
    if (!(type.contains('mpeg') || type.contains('aac') || type.contains('mp3'))) {
      throw Exception('unsupported content type $type');
    }
    contentType = type.split(';').first.trim();
    _metaInt = int.tryParse(res.headers['icy-metaint'] ?? '') ?? 0;
    _audioLeft = _metaInt;
    _startedAt = DateTime.now();
    final first = Completer<void>();
    _sub = res.stream.listen(
      (data) {
        _onData(data);
        if (!first.isCompleted && _total > 0) first.complete();
      },
      onError: (Object e) {
        if (!first.isCompleted) first.completeError(e);
      },
      onDone: () {
        if (!first.isCompleted) first.completeError(Exception('stream ended'));
        _grew.add(null);
      },
      cancelOnError: true,
    );
    await first.future.timeout(const Duration(seconds: 10));
  }

  /// Feeds bytes without a network connection (tests only).
  @visibleForTesting
  void debugFeed(List<int> data, {int metaInt = 0}) {
    if (_startedAt == null) {
      _startedAt = DateTime.now();
      _metaInt = metaInt;
      _audioLeft = metaInt;
    }
    _onData(data);
  }

  void stop() {
    _stopped = true;
    _sub?.cancel();
    _client?.close();
    _grew.add(null);
  }

  bool get stopped => _stopped;

  void _onData(List<int> data) {
    if (_metaInt == 0) {
      _addAudio(data, 0, data.length);
      return;
    }
    var i = 0;
    while (i < data.length) {
      if (_audioLeft > 0) {
        final n = math.min(_audioLeft, data.length - i);
        _addAudio(data, i, i + n);
        _audioLeft -= n;
        i += n;
      } else if (_metaLeft < 0) {
        _metaLeft = data[i++] * 16;
        if (_metaLeft == 0) {
          _metaLeft = -1;
          _audioLeft = _metaInt;
        }
      } else {
        final n = math.min(_metaLeft, data.length - i);
        _meta.add(data.sublist(i, i + n));
        _metaLeft -= n;
        i += n;
        if (_metaLeft == 0) {
          _onMetadata(_meta.takeBytes());
          _metaLeft = -1;
          _audioLeft = _metaInt;
        }
      }
    }
  }

  void _onMetadata(List<int> bytes) {
    final text = latin1.decode(bytes, allowInvalid: true);
    final m = RegExp(r"StreamTitle='(.*?)';").firstMatch(text);
    final title = m?.group(1)?.trim() ?? '';
    // Many streams send UTF-8 despite the ICY spec saying Latin-1.
    String decoded;
    try {
      decoded = utf8.decode(latin1.encode(title));
    } catch (_) {
      decoded = title;
    }
    if (_titles.isEmpty || _titles.last.$2 != decoded) _titles.add((_total, decoded));
  }

  void _addAudio(List<int> data, int from, int to) {
    if (to <= from) return;
    final bytes = Uint8List.fromList(data.sublist(from, to));
    _chunks.add(_Chunk(_total, bytes));
    _total += bytes.length;
    final maxBuffered = math.min(maxBytes.toDouble(), byteRate * window.inSeconds);
    while (_chunks.length > 1 && _total - _chunks.first.start - _chunks.first.data.length > maxBuffered) {
      _chunks.removeAt(0);
    }
    while (_titles.length > 1 && _titles[1].$1 <= firstOffset) {
      _titles.removeAt(0);
    }
    _grew.add(null);
  }

  /// Song title playing at [offset], if the station sends one.
  String? titleAt(int offset) {
    String? t;
    for (final (o, title) in _titles) {
      if (o > offset) break;
      t = title;
    }
    return (t == null || t.isEmpty) ? null : t;
  }

  /// Endless byte stream from [offset]; follows the live edge as it grows.
  Stream<List<int>> readFrom(int offset) async* {
    var pos = offset;
    while (!_stopped) {
      if (pos < firstOffset) pos = firstOffset; // fell out of the window
      if (pos >= _total) {
        await _grew.stream.first;
        continue;
      }
      var i = _indexOf(pos);
      while (i < _chunks.length) {
        final c = _chunks[i];
        final from = pos - c.start;
        if (from < c.data.length) {
          yield from == 0 ? c.data : Uint8List.sublistView(c.data, from);
          pos = c.start + c.data.length;
        }
        i++;
        // Chunks may have been trimmed while we yielded.
        if (i >= _chunks.length || _chunks[i].start != pos) break;
      }
    }
  }

  int _indexOf(int pos) {
    var lo = 0, hi = _chunks.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_chunks[mid].start <= pos) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }
}

class _Chunk {
  _Chunk(this.start, this.data);
  final int start;
  final Uint8List data;
}

/// Feeds the player from a [TimeshiftBuffer] starting at an absolute offset.
class TimeshiftSource extends StreamAudioSource {
  TimeshiftSource(this.buffer, this.start, {super.tag});

  final TimeshiftBuffer buffer;
  final int start;

  @override
  Future<StreamAudioResponse> request([int? from, int? to]) async => StreamAudioResponse(
        rangeRequestsSupported: false,
        sourceLength: null,
        contentLength: null,
        offset: null,
        contentType: buffer.contentType,
        stream: buffer.readFrom(start),
      );
}
