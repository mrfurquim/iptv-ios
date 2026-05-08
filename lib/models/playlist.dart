import 'package:iptv_player/models/channel.dart';

class Playlist {
  final Map<String, List<Channel>> live;
  final Map<String, List<Channel>> movie;
  final Map<String, List<Series>> series;

  Playlist({
    Map<String, List<Channel>>? live,
    Map<String, List<Channel>>? movie,
    Map<String, List<Series>>? series,
  })  : live = live ?? {},
        movie = movie ?? {},
        series = series ?? {};

  List<Channel> getAllChannels(ChannelType type) {
    switch (type) {
      case ChannelType.live:
        return live.values.expand((list) => list).toList();
      case ChannelType.movie:
        return movie.values.expand((list) => list).toList();
      case ChannelType.series:
        return [];
    }
  }

  List<String> getGroups(ChannelType type) {
    switch (type) {
      case ChannelType.live:
        return live.keys.toList()..sort();
      case ChannelType.movie:
        return movie.keys.toList()..sort();
      case ChannelType.series:
        return series.keys.toList()..sort();
    }
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      live: (json['live'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(
              k,
              (v as List).map((e) => Channel.fromJson(e)).toList(),
            ),
          ) ??
          {},
      movie: (json['movie'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(
              k,
              (v as List).map((e) => Channel.fromJson(e)).toList(),
            ),
          ) ??
          {},
      series: (json['series'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(
              k,
              (v as List).map((e) => Series.fromJson(e)).toList(),
            ),
          ) ??
          {},
    );
  }

  Map<String, dynamic> toJson() => {
        'live': live.map(
          (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
        ),
        'movie': movie.map(
          (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
        ),
        'series': series.map(
          (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
        ),
      };
}
