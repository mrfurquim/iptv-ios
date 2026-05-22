import 'dart:async';
import 'dart:isolate';
import 'package:iptv_player/models/channel.dart';
import 'package:iptv_player/models/playlist.dart';

class _IsolateParserArgs {
  final String content;
  final SendPort sendPort;

  _IsolateParserArgs(this.content, this.sendPort);
}

class M3UParser {
  /// Parse M3U content and return a Playlist asynchronously using a background Isolate
  Future<Playlist> parse(
    String content, {
    void Function(Playlist partialPlaylist, double progress)? onProgress,
  }) async {
    if (content.trim().isEmpty) {
      throw const FormatException('Conteúdo M3U vazio');
    }

    final receivePort = ReceivePort();
    final completer = Completer<Playlist>();
    final playlist = Playlist();

    // Lookup maps: Group -> Title/BaseName -> Index in the Playlist lists (O(1) updates)
    final Map<String, Map<String, int>> movieIndexLookup = {};
    final Map<String, Map<String, int>> seriesIndexLookup = {};

    void addChannels(List<Channel> channels) {
      for (final channel in channels) {
        switch (channel.type) {
          case ChannelType.live:
            playlist.live.putIfAbsent(channel.group, () => []).add(channel);
            break;
          case ChannelType.movie:
            _organizeMovieChannelO1(channel, playlist.movie, movieIndexLookup);
            break;
          case ChannelType.series:
            _organizeSeriesChannelO1(channel, playlist.series, seriesIndexLookup);
            break;
        }
      }
    }

    receivePort.listen((message) {
      if (message is Map) {
        final type = message['type'];
        if (type == 'chunk') {
          final channels = message['channels'] as List<Channel>;
          final progress = message['progress'] as double;
          addChannels(channels);
          if (onProgress != null) {
            onProgress(playlist, progress);
          }
        } else if (type == 'done') {
          final channels = message['channels'] as List<Channel>;
          addChannels(channels);
          receivePort.close();
          if (onProgress != null) {
            onProgress(playlist, 1.0);
          }
          completer.complete(playlist);
        } else if (type == 'error') {
          receivePort.close();
          completer.completeError(Exception(message['error']));
        }
      }
    });

    try {
      await Isolate.spawn(
        _parseIsolateEntry,
        _IsolateParserArgs(content, receivePort.sendPort),
      );
    } catch (e) {
      receivePort.close();
      completer.completeError(e);
    }

    return completer.future;
  }

  static void _parseIsolateEntry(_IsolateParserArgs args) {
    final content = args.content;
    final sendPort = args.sendPort;

    try {
      final lines = content.split('\n');
      final int totalLines = lines.length;
      Map<String, String> currentChannelData = {};
      int uuidCounter = 0;
      
      final List<Channel> batch = [];
      const int batchSize = 1000;

      final parser = M3UParser();

      for (var i = 0; i < totalLines; i++) {
        final line = lines[i];
        final trimmedLine = line.trim();
        if (trimmedLine.startsWith('#EXTINF:')) {
          currentChannelData = parser._parseExtInf(trimmedLine);
        } else if (trimmedLine.startsWith('http') && currentChannelData.isNotEmpty) {
          final uuid = '${DateTime.now().millisecondsSinceEpoch}_${uuidCounter++}';
          final channel = parser._createChannel(currentChannelData, trimmedLine, uuid);
          if (channel != null) {
            batch.add(channel);

            if (batch.length >= batchSize) {
              final progress = i / totalLines;
              sendPort.send({
                'type': 'chunk',
                'channels': List<Channel>.from(batch),
                'progress': progress,
              });
              batch.clear();
            }
          }
          currentChannelData = {};
        }
      }

      // Send last chunk and finish
      sendPort.send({
        'type': 'done',
        'channels': batch,
      });
    } catch (e) {
      sendPort.send({
        'type': 'error',
        'error': e.toString(),
      });
    }
  }

  void _organizeMovieChannelO1(
    Channel channel,
    Map<String, List<Channel>> movieMap,
    Map<String, Map<String, int>> movieIndexLookup,
  ) {
    final baseName = _extractBaseName(channel.name);
    final quality = _extractQuality(channel.name);

    movieMap.putIfAbsent(channel.group, () => []);
    final groupList = movieMap[channel.group]!;

    final groupLookup = movieIndexLookup.putIfAbsent(channel.group, () => {});
    final existingIndex = groupLookup[baseName];

    if (existingIndex != null) {
      final existing = groupList[existingIndex];
      final updatedQualities = Map<String, Channel>.from(existing.qualities ?? {});
      updatedQualities[quality] = channel;
      
      groupList[existingIndex] = Channel(
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
      groupList.add(Channel(
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
      groupLookup[baseName] = groupList.length - 1;
    }
  }

  void _organizeSeriesChannelO1(
    Channel channel,
    Map<String, List<Series>> seriesMap,
    Map<String, Map<String, int>> seriesIndexLookup,
  ) {
    final (title, season, episode) = _parseSeriesInfo(channel.name);

    seriesMap.putIfAbsent(channel.group, () => []);
    final groupList = seriesMap[channel.group]!;

    final groupLookup = seriesIndexLookup.putIfAbsent(channel.group, () => {});
    final existingIndex = groupLookup[title];

    if (existingIndex != null) {
      final targetSeries = groupList[existingIndex];
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

      groupList[existingIndex] = Series(
        title: targetSeries.title,
        logo: targetSeries.logo ?? channel.logo,
        year: targetSeries.year ?? channel.year,
        seasons: updatedSeasons,
      );
    } else {
      final newSeries = Series(
        title: title,
        logo: channel.logo,
        year: channel.year,
        seasons: {
          season: [
            Channel(
              uuid: channel.uuid,
              name: 'Episódio $episode',
              logo: channel.logo,
              group: channel.group,
              type: channel.type,
              url: channel.url,
              originalUrl: channel.originalUrl,
              tvgId: channel.tvgId,
              year: channel.year,
            )
          ]
        },
      );
      groupList.add(newSeries);
      groupLookup[title] = groupList.length - 1;
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

  Channel? _createChannel(Map<String, String> data, String url, String uuid) {
    final name = data['tvgName'] ?? '';
    final logo = data['logo'];
    final group = data['group'] ?? 'Sem Categoria';
    final tvgId = data['tvgId'];

    final type = _determineChannelType(url, group);
    final processedUrl = _processUrl(url);
    final year = _extractYear(name);

    return Channel(
      uuid: uuid,
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
    const pattern = r'\s*\(?(\d{4})\)?\s*$';
    final regExp = RegExp(pattern);
    final match = regExp.firstMatch(name);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
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
    const pattern =
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
    const sePattern = r"(.*?)\s*[Ss](\d+)\s*[Ee](\d+)";
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
    const epPattern = r"(.*?)\s*[-]*\s*[Ee]pis[óo]dio\s*(\d+)";
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
