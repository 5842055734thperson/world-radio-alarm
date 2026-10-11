import 'package:flutter_test/flutter_test.dart';
import 'package:world_radio/models/station.dart';
import 'package:world_radio/services/similar.dart';

Station st(String id, String cc, String tags, {String lang = ''}) =>
    Station(uuid: id, name: id, url: 'http://$id', countryCode: cc, tags: tags, language: lang);

void main() {
  final seed = st('seed', 'TR', 'jazz,smooth jazz,music', lang: 'turkish');

  test('main tag skips generic tags', () {
    expect(Similar.mainTag(st('x', 'TR', 'Music, Radio, Jazz')), 'jazz');
    expect(Similar.mainTag(st('x', 'TR', 'music')), '');
  });

  test('ranks by shared tags and splits same / other countries', () {
    final candidates = [
      st('tr-pop', 'TR', 'pop'),
      st('tr-jazz', 'TR', 'jazz,smooth jazz'),
      st('tr-jazz2', 'TR', 'jazz'),
      st('de-jazz', 'DE', 'jazz,smooth jazz'),
      st('de-jazz2', 'DE', 'jazz'), // same country as de-jazz: skipped for diversity
      st('fr-jazz', 'FR', 'jazz'),
      st('us-rock', 'US', 'rock'),
      st('nl-jazz', 'NL', 'jazz', lang: 'dutch'),
    ];
    final r = Similar.rank(seed, candidates).map((s) => s.uuid).toList();
    expect(r.take(2), ['tr-jazz', 'tr-jazz2']);
    expect(r.length, 6);
    expect(r.sublist(3), ['de-jazz', 'fr-jazz', 'nl-jazz']);
    expect(r, isNot(contains('de-jazz2')));
  });

  test('excludes stations already in the tree and duplicate streams', () {
    final candidates = [
      st('a', 'TR', 'jazz'),
      Station(uuid: 'b', name: 'b', url: 'http://a', countryCode: 'TR', tags: 'jazz'),
      st('c', 'TR', 'jazz'),
    ];
    final r = Similar.rank(seed, candidates, exclude: {'c'}).map((s) => s.uuid).toList();
    expect(r, ['a']);
  });
}
