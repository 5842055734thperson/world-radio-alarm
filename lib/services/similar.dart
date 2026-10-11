import '../models/station.dart';
import 'radio_browser.dart';

/// "If you like this, try these": stations related to a seed station.
///
/// Radio Browser has no co-listening data, so relatedness is estimated from
/// shared genre tags, shared language and popularity. Each call returns a few
/// stations from the seed's own country and a few from other countries.
class Similar {
  Similar(this._api);

  final RadioBrowser _api;
  final _cache = <String, List<Station>>{};

  /// Tags that say nothing about the sound.
  static const _generic = {
    'music', 'radio', 'fm', 'am', 'online', 'internet', 'live', 'local', 'misc',
    'various', 'webradio', 'web radio', 'stereo', 'hd', 'public radio', 'community radio',
  };

  /// Up to four descriptive tags for display.
  static List<String> displayTags(Station s) =>
      s.tagSet.difference(_generic).take(4).toList();

  /// The most telling tag, used to query candidates.
  static String mainTag(Station s) {
    for (final t in s.tags.toLowerCase().split(',').map((e) => e.trim())) {
      if (t.isNotEmpty && !_generic.contains(t)) return t;
    }
    return '';
  }

  Future<List<Station>> related(Station seed, {Set<String> exclude = const {}}) async {
    final candidates = _cache[seed.uuid] ??= await _candidates(seed);
    return rank(seed, candidates, exclude: exclude);
  }

  Future<List<Station>> _candidates(Station seed) async {
    final tag = mainTag(seed);
    final lang = seed.languageSet.isEmpty ? '' : seed.languageSet.first;
    final results = await Future.wait([
      // Same country: same genre, or just popular when the seed has no genre.
      _api.search(countryCode: seed.countryCode, tag: tag, limit: 40),
      // Everywhere: same genre, or same language.
      if (tag.isNotEmpty)
        _api.search(tag: tag, limit: 150)
      else if (lang.isNotEmpty)
        _api.search(language: lang, limit: 150),
    ].map((f) => f.catchError((_) => <Station>[])));
    return [for (final r in results) ...r];
  }

  /// Picks [sameCountry] stations from the seed's country and [otherCountries]
  /// from distinct other countries, best matches first.
  static List<Station> rank(
    Station seed,
    List<Station> candidates, {
    Set<String> exclude = const {},
    int sameCountry = 3,
    int otherCountries = 3,
  }) {
    final seedTags = seed.tagSet.difference(_generic);
    final seedLangs = seed.languageSet;
    final seenUrls = <String>{seed.url};
    final scored = <(double, int, Station)>[];
    for (var i = 0; i < candidates.length; i++) {
      final c = candidates[i];
      if (c.uuid == seed.uuid || exclude.contains(c.uuid) || !seenUrls.add(c.url)) continue;
      final tags = c.tagSet.difference(_generic);
      final union = seedTags.union(tags).length;
      final jaccard = union == 0 ? 0.0 : seedTags.intersection(tags).length / union;
      final lang = seedLangs.intersection(c.languageSet).isNotEmpty ? 0.5 : 0.0;
      // Candidates arrive sorted by popularity; keep a small bonus for that order.
      final popularity = 0.3 * (1 - i / (candidates.length + 1));
      scored.add((2 * jaccard + lang + popularity, i, c));
    }
    scored.sort((a, b) => b.$1 != a.$1 ? b.$1.compareTo(a.$1) : a.$2.compareTo(b.$2));

    final same = <Station>[];
    final other = <Station>[];
    final countries = <String>{seed.countryCode};
    for (final (_, _, c) in scored) {
      if (c.countryCode == seed.countryCode) {
        if (same.length < sameCountry) same.add(c);
      } else if (other.length < otherCountries && countries.add(c.countryCode)) {
        other.add(c);
      }
      if (same.length == sameCountry && other.length == otherCountries) break;
    }
    return [...same, ...other];
  }
}
