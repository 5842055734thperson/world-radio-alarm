/// A single radio station, as returned by the Radio Browser API.
class Station {
  const Station({
    required this.uuid,
    required this.name,
    required this.url,
    this.favicon = '',
    this.country = '',
    this.countryCode = '',
    this.tags = '',
    this.codec = '',
    this.bitrate = 0,
    this.language = '',
    this.lat,
    this.lon,
  });

  final String uuid;
  final String name;
  final String url;
  final String favicon;
  final String country;
  final String countryCode;
  final String tags;
  final String codec;
  final int bitrate;

  /// Comma-separated languages, e.g. "turkish,english".
  final String language;

  /// Station location, when Radio Browser knows it (used by the map).
  final double? lat;
  final double? lon;

  bool get hasGeo => lat != null && lon != null;

  factory Station.fromApi(Map<String, dynamic> j) {
    final resolved = (j['url_resolved'] ?? '').toString().trim();
    return Station(
      uuid: (j['stationuuid'] ?? '').toString(),
      name: (j['name'] ?? '').toString().trim(),
      url: resolved.isNotEmpty ? resolved : (j['url'] ?? '').toString().trim(),
      favicon: (j['favicon'] ?? '').toString().trim(),
      country: (j['country'] ?? '').toString(),
      countryCode: (j['countrycode'] ?? '').toString(),
      tags: (j['tags'] ?? '').toString(),
      codec: (j['codec'] ?? '').toString(),
      bitrate: (j['bitrate'] is int) ? j['bitrate'] as int : 0,
      language: (j['language'] ?? '').toString(),
      lat: (j['geo_lat'] as num?)?.toDouble(),
      lon: (j['geo_long'] as num?)?.toDouble(),
    );
  }

  factory Station.fromJson(Map<String, dynamic> j) => Station(
        uuid: j['uuid'] as String? ?? '',
        name: j['name'] as String? ?? '',
        url: j['url'] as String? ?? '',
        favicon: j['favicon'] as String? ?? '',
        country: j['country'] as String? ?? '',
        countryCode: j['countryCode'] as String? ?? '',
        tags: j['tags'] as String? ?? '',
        codec: j['codec'] as String? ?? '',
        bitrate: j['bitrate'] as int? ?? 0,
        language: j['language'] as String? ?? '',
        lat: (j['lat'] as num?)?.toDouble(),
        lon: (j['lon'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'name': name,
        'url': url,
        'favicon': favicon,
        'country': country,
        'countryCode': countryCode,
        'tags': tags,
        'codec': codec,
        'bitrate': bitrate,
        if (language.isNotEmpty) 'language': language,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
      };

  /// Lower-case, trimmed genre tags.
  Set<String> get tagSet => tags
      .toLowerCase()
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toSet();

  Set<String> get languageSet => language
      .toLowerCase()
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toSet();

  /// Short "Country · tag, tag · 128 kbps" description line.
  String get subtitle {
    final parts = <String>[];
    if (country.isNotEmpty) parts.add(country);
    final t = tags.split(',').where((e) => e.trim().isNotEmpty).take(3).join(', ');
    if (t.isNotEmpty) parts.add(t);
    if (bitrate > 0) parts.add('$bitrate kbps');
    return parts.join(' · ');
  }

  @override
  bool operator ==(Object other) => other is Station && other.uuid == uuid;

  @override
  int get hashCode => uuid.hashCode;
}

/// A country entry from the Radio Browser API.
class Country {
  const Country(this.code, this.name, this.stationCount);

  final String code;
  final String name;
  final int stationCount;
}

/// Turns an ISO country code ("TR") into its flag emoji.
String flagEmoji(String code) {
  if (code.length != 2) return '🌍';
  final c = code.toUpperCase();
  return String.fromCharCodes(c.codeUnits.map((u) => 0x1F1E6 + u - 65));
}
