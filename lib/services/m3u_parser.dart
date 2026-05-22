import 'package:iptv_player/models/channel.dart';
import 'package:iptv_player/models/playlist.dart';

class M3UParser {
  /// Parse M3U content and return a Playlist asynchronously to avoid UI freezing
  Future<Playlist> parse(
    String content, {
    void Function(Playlist partialPlaylist, double progress)? onProgress,
  }) async {
    if (content.trim().isEmpty) {
      throw FormatException('Conteúdo M3U vazio');
    }

    final lines = content.split('\n');
    final playlist = Playlist();
    Map<String, String> currentChannelData = {};
    int channelCount = 0;
    const int updateBatchSize = 150; // Update UI every 150 channels

    for (var i = 0; i < lines.length; i++) {
      if (i % 1500 == 0) {
        // Yield to the event loop so UI doesn't freeze
        await Future.delayed(Duration.zero);
      }
      
      final line = lines[i];
      final trimmedLine = line.trim();
      if (trimmedLine.startsWith('#EXTINF:')) {
        currentChannelData = _parseExtInf(trimmedLine);
      } else if (trimmedLine.startsWith('http') && currentChannelData.isNotEmpty) {
        final channel = _createChannel(currentChannelData, trimmedLine);
        if (channel != null) {
          _addChannelToPlaylist(channel, playlist);
          channelCount++;
          
          if (onProgress != null && channelCount % updateBatchSize == 0) {
            // Create a shallow copy of maps to trigger a clean State rebuild
            final progress = i / lines.length;
            final partial = Playlist(
              live: Map<String, List<Channel>>.from(playlist.live.map((k, v) => MapEntry(k, List<Channel>.from(v)))),
              movie: Map<String, List<Channel>>.from(playlist.movie.map((k, v) => MapEntry(k, List<Channel>.from(v)))),
              series: Map<String, List<Series>>.from(playlist.series.map((k, v) => MapEntry(k, List<Series>.from(v)))),
            );
            onProgress(partial, progress);
            
            // Give UI a tiny window to build
            await Future.delayed(const Duration(milliseconds: 2));
          }
        }
        currentChannelData = {};
      }
    }

    if (onProgress != null) {
      onProgress(playlist, 1.0);
    }
    
    return playlist;
  }

  void _addChannelToPlaylist(Channel channel, Playlist playlist) {
    switch (channel.type) {
      case ChannelType.live:
        playlist.live.putIfAbsent(channel.group, () => []).add(channel);
        break;
      case ChannelType.movie:
        _organizeMovieChannel(channel, playlist.movie);
        break;
      case ChannelType.series:
        _organizeSeriesChannel(channel, playlist.series);
        break;
    }
  }

  Map<String, String> _parseExtInf(String line) {
    final result = <String, String>{};

    // Regex patterns for attributes
    final patterns = {
      'tvgId': r'tvg-id="([^"]*)"',
      'tvgName': r'tvg-name="([^"]*)"',
      'logo': r'tvg-logo="([^"]*)"',
      'group': r'group-title="([^"]*)"',
    };

    patterns.forEach((key, pattern) {
      final regExp = RegExp(pattern);
      final match = regExp.firstMatch(line);
      if (match != null) {
        result[key] = match.group(1) ?? '';
      }
    });

    // Extract name after last comma if tvg-name not present
    if (!result.containsKey('tvgName') || result['tvgName']!.isEmpty) {
      final lastCommaIndex = line.lastIndexOf(',');
      if (lastCommaIndex != -1) {
        final name = line.substring(lastCommaIndex + 1).trim();
        if (name.isNotEmpty) {
          result['tvgName'] = name;
        }
      }
    }

    return result;
  }

  Channel? _createChannel(Map<String, String> data, String url) {
    final name = data['tvgName'] ?? '';
    final logo = data['logo'];
    final group = data['group'] ?? 'Sem Categoria';
    final tvgId = data['tvgId'];

    final type = _determineChannelType(url, group);
    final processedUrl = _processUrl(url);
    final year = _extractYear(name);

    return Channel(
      uuid: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      logo: logo,
      group: group,
      type: type,
      url: processedUrl,
      originalUrl: url,
      tvgId: tvgId,
      year: year,
    );
  }

  ChannelType _determineChannelType(String url, String group) {
    final lowerUrl = url.toLowerCase();
    final lowerGroup = group.toLowerCase();

    if (lowerUrl.contains('/series/')) return ChannelType.series;
    if (lowerUrl.contains('/movie/')) return ChannelType.movie;
    if (lowerUrl.contains('/live/')) return ChannelType.live;

    // Fallback to group-title
    if (lowerGroup.contains('série') ||
        lowerGroup.contains('novela') ||
        lowerGroup.contains('series')) {
      return ChannelType.series;
    }
    if (lowerGroup.contains('filme')) return ChannelType.movie;

    return ChannelType.live;
  }

  String _processUrl(String url) {
    // If live and ends with .ts, change to .m3u8
    if (url.endsWith('.ts') && url.toLowerCase().contains('/live/')) {
      return url.substring(0, url.length - 3) + '.m3u8';
    }
    return url;
  }

  int? _extractYear(String name) {
    final pattern = r'\s*\(?(\d{4})\)?\s*$';
    final regExp = RegExp(pattern);
    final match = regExp.firstMatch(name);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }



  void _organizeMovieChannel(
      Channel channel, Map<String, List<Channel>> movie) {
    final baseName = _extractBaseName(channel.name);
    final quality = _extractQuality(channel.name);

    movie.putIfAbsent(channel.group, () => []);

    final existingIndex = movie[channel.group]!
        .indexWhere((c) => _extractBaseName(c.name) == baseName);

    if (existingIndex != -1) {
      final existing = movie[channel.group]![existingIndex];
      final updatedQualities = Map<String, Channel>.from(existing.qualities ?? {});
      updatedQualities[quality] = channel;
      movie[channel.group]![existingIndex] = Channel(
        uuid: existing.uuid,
        name: existing.name,
        logo: existing.logo,
        group: existing.group,
        type: existing.type,
        url: existing.url,
        originalUrl: existing.originalUrl,
        tvgId: existing.tvgId,
        year: existing.year,
        qualities: updatedQualities,
      );
    } else {
      movie[channel.group]!.add(Channel(
        uuid: channel.uuid,
        name: channel.name,
        logo: channel.logo,
        group: channel.group,
        type: channel.type,
        url: channel.url,
        originalUrl: channel.originalUrl,
        tvgId: channel.tvgId,
        year: channel.year,
        qualities: {quality: channel},
      ));
    }
  }

  void _organizeSeriesChannel(
      Channel channel, Map<String, List<Series>> series) {
    final (title, season, episode) = _parseSeriesInfo(channel.name);

    series.putIfAbsent(channel.group, () => []);

    final seriesIndex =
        series[channel.group]!.indexWhere((s) => s.title == title);

    if (seriesIndex == -1) {
      final newSeries = Series(
        title: title,
        logo: channel.logo,
        year: channel.year,
        seasons: {},
      );
      series[channel.group]!.add(newSeries);
    }

    final targetSeries = series[channel.group]!
        .firstWhere((s) => s.title == title);

    final updatedSeasons = Map<String, List<Channel>>.from(targetSeries.seasons);
    updatedSeasons.putIfAbsent(season, () => []);

    final episodeChannel = Channel(
      uuid: channel.uuid,
      name: 'Episódio $episode',
      logo: channel.logo,
      group: channel.group,
      type: channel.type,
      url: channel.url,
      originalUrl: channel.originalUrl,
      tvgId: channel.tvgId,
      year: channel.year,
    );

    updatedSeasons[season]!.add(episodeChannel);

    // Update series in list (recreate with new seasons)
    final newSeries = Series(
      title: targetSeries.title,
      logo: targetSeries.logo ?? channel.logo,
      year: targetSeries.year ?? channel.year,
      seasons: updatedSeasons,
    );

    final idx = series[channel.group]!.indexWhere((s) => s.title == title);
    series[channel.group]![idx] = newSeries;
  }

  String _extractBaseName(String name) {
    var base = name;
    final patterns = [
      r'\s*[-|\[|\(]?\s*(FHD|1080p|1080|HD|720p|720|SD|480p|480|4K|8K|H265|HEVC)\s*[\]|\)]?\s*$',
      r'\s*\(?(\d{4})\)?\s*$',
    ];

    for (final pattern in patterns) {
      final regExp = RegExp(pattern);
      base = base.replaceAll(regExp, '');
    }

    return base.trim();
  }

  String _extractQuality(String name) {
    final pattern =
        r'^(.*?)\s*[-|\[|\(]?\s*(FHD|1080p|1080|HD|720p|720|SD|480p|480|4K|8K|H265|HEVC)\s*[\]|\)]?\s*$';
    final regExp = RegExp(pattern);
    final match = regExp.firstMatch(name);
    if (match != null) {
      return match.group(2)!.toUpperCase();
    }
    return 'NORMAL';
  }

  (String, String, String) _parseSeriesInfo(String name) {
    // Try S01E20 pattern
    final sePattern = r"(.*?)\s*[Ss](\d+)\s*[Ee](\d+)";
    final seRegExp = RegExp(sePattern);
    final seMatch = seRegExp.firstMatch(name);
    if (seMatch != null) {
      return (
        seMatch.group(1)!.trim(),
        seMatch.group(2)!,
        seMatch.group(3)!,
      );
    }

    // Try "Episodio X" pattern
    final epPattern = r"(.*?)\s*[-]*\s*[Ee]pis[óo]dio\s*(\d+)";
    final epRegExp = RegExp(epPattern);
    final epMatch = epRegExp.firstMatch(name);
    if (epMatch != null) {
      return (
        epMatch.group(1)!.trim(),
        '1',
        epMatch.group(2)!,
      );
    }

    return (name, '1', '1');
  }
}
