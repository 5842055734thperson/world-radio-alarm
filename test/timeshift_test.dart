import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:world_radio/services/timeshift.dart';

List<int> icyBlock(String meta) {
  final bytes = utf8.encode(meta);
  final len = (bytes.length + 15) ~/ 16;
  return [len, ...bytes, ...List.filled(len * 16 - bytes.length, 0)];
}

void main() {
  test('strips ICY metadata and records song titles by offset', () {
    final b = TimeshiftBuffer('x', window: const Duration(minutes: 15), bitrateKbps: 128);
    final audio1 = List<int>.filled(8, 1);
    final audio2 = List<int>.filled(8, 2);
    final stream = [...audio1, ...icyBlock("StreamTitle='Miles Davis - So What';"), ...audio2, 0];
    // Deliver in awkward pieces to exercise the parser state machine.
    for (var i = 0; i < stream.length; i += 5) {
      b.debugFeed(stream.sublist(i, i + 5 > stream.length ? stream.length : i + 5), metaInt: 8);
    }
    expect(b.liveOffset, 16); // only audio bytes are kept
    expect(b.titleAt(0), isNull);
    expect(b.titleAt(8), 'Miles Davis - So What');
  });

  test('reads from an offset and follows the live edge', () async {
    final b = TimeshiftBuffer('x', window: const Duration(minutes: 15), bitrateKbps: 128);
    b.debugFeed([1, 2, 3, 4]);
    b.debugFeed([5, 6]);
    final received = <int>[];
    final sub = b.readFrom(2).listen(received.addAll);
    await Future<void>.delayed(Duration.zero);
    b.debugFeed([7, 8]);
    await Future<void>.delayed(Duration.zero);
    expect(received, [3, 4, 5, 6, 7, 8]);
    b.stop(); // wakes the reader so the subscription can finish
    await sub.cancel();
  });

  test('drops audio older than the window', () {
    // 1 kbps = 125 bytes/s; a 1-minute window keeps ~7500 bytes.
    final b = TimeshiftBuffer('x', window: const Duration(minutes: 1), bitrateKbps: 1);
    for (var i = 0; i < 20; i++) {
      b.debugFeed(List.filled(1000, i));
    }
    expect(b.liveOffset, 20000);
    expect(b.liveOffset - b.firstOffset, lessThanOrEqualTo(8500));
    expect(b.bufferedSeconds, closeTo(60, 8));
  });
}
