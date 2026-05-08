enum ChannelType { live, movie, series }

class Channel {
  final String uuid;
  final String name;
  final String? logo;
  final String group;
  final ChannelType type;
  final String url;
  final String originalUrl;
  final String? tvgId;
  final int? year;
  final Map<String, Channel>? qualities;

  Channel({
    required this.uuid,
    required this.name,
    this.logo,
    required this.group,
    required this.type,
    required this.url,
    required this.originalUrl,
    this.tvgId,
    this.year,
    this.qualities,
  });

  String get displayName => name;

  bool get hasLogo => logo != null && logo!.isNotEmpty;

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      uuid: json['uuid'] ?? '',
      name: json['name'] ?? '',
      logo: json['logo'],
      group: json['group'] ?? 'Sem Categoria',
      type: _parseChannelType(json['type']),
      url: json['url'] ?? '',
      originalUrl: json['originalUrl'] ?? '',
      tvgId: json['tvgId'],
      year: json['year'],
      qualities: json['qualities'] != null
          ? Map<String, Channel>.from(
              json['qualities'].map((k, v) => MapEntry(k, Channel.fromJson(v))))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'name': name,
        'logo': logo,
        'group': group,
        'type': type.name,
        'url': url,
        'originalUrl': originalUrl,
        'tvgId': tvgId,
        'year': year,
        'qualities': qualities?.map((k, v) => MapEntry(k, v.toJson())),
      };

  static ChannelType _parseChannelType(String? typeStr) {
    switch (typeStr) {
      case 'movie':
        return ChannelType.movie;
      case 'series':
        return ChannelType.series;
      default:
        return ChannelType.live;
    }
  }
}

class Series {
  final String title;
  final String? logo;
  final int? year;
  final Map<String, List<Channel>> seasons;

  Series({
    required this.title,
    this.logo,
    this.year,
    required this.seasons,
  });

  factory Series.fromJson(Map<String, dynamic> json) {
    return Series(
      title: json['title'] ?? '',
      logo: json['logo'],
      year: json['year'],
      seasons: (json['seasons'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(
              k,
              (v as List).map((e) => Channel.fromJson(e)).toList(),
            ),
          ) ??
          {},
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'logo': logo,
        'year': year,
        'seasons': seasons.map(
          (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
        ),
      };
}
