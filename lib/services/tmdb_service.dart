import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:iptv_player/models/channel.dart';
import 'package:iptv_player/models/tmdb_metadata.dart';
import 'package:iptv_player/services/storage_service.dart';

class TMDBService {
  static const String _defaultApiKey = 'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI4YjJkYjYxYjBiYTI0MTc3ZmE5ZWIwNTRmZTIxMjU5ZiIsIm5iZiI6MTc3OTE0ODY3MS43MDEsInN1YiI6IjZhMGJhNzdmZmMzOWQ4YjZlMjQ2NzkwZSIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.5e5q4K_H7n8qQ9Q8cE5TRZMw1mnyhMOPxzwK7IjN4Zc';
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  final StorageService _storageService = StorageService();
  
  Box? _cacheBox;

  Future<void> _initCache() async {
    if (_cacheBox == null || !_cacheBox!.isOpen) {
      _cacheBox = await Hive.openBox('tmdb_metadata_cache');
    }
  }

  Future<String> _getApiKey() async {
    final userKey = await _storageService.getTMDBApiKey();
    if (userKey != null && userKey.trim().isNotEmpty) {
      return userKey.trim();
    }
    return _defaultApiKey;
  }

  // Offline TMDB Genre IDs mapping to Portuguese names
  static const Map<int, String> _genreMap = {
    // Movies
    28: 'Ação',
    12: 'Aventura',
    16: 'Animação',
    35: 'Comédia',
    80: 'Crime',
    99: 'Documentário',
    18: 'Drama',
    10751: 'Família',
    14: 'Fantasia',
    36: 'História',
    27: 'Terror',
    10402: 'Música',
    9648: 'Mistério',
    10749: 'Romance',
    878: 'Ficção Científica',
    10770: 'Cinema TV',
    53: 'Suspense',
    10752: 'Guerra',
    37: 'Faroeste',
    // TV (Series) additions/differences
    10759: 'Ação e Aventura',
    10762: 'Kids',
    10763: 'Notícias',
    10764: 'Reality Show',
    10765: 'Sci-Fi & Fantasy',
    10766: 'Novela',
    10767: 'Talk Show',
    10768: 'Guerra e Política',
  };

  List<String> _mapGenreIds(List<dynamic>? ids) {
    if (ids == null) return [];
    return ids
        .map((id) => _genreMap[id])
        .where((name) => name != null)
        .cast<String>()
        .toList();
  }

  Future<TMDBMetadata?> fetchMetadata(String title, ChannelType type, {int? year}) async {
    await _initCache();
    final cleanTitle = _sanitizeSearchTitle(title);
    if (cleanTitle.isEmpty) return null;

    final cacheKey = '${type.name}_${cleanTitle.toLowerCase()}_${year ?? ''}';
    
    // Check local Hive cache
    if (_cacheBox!.containsKey(cacheKey)) {
      final cachedData = _cacheBox!.get(cacheKey);
      if (cachedData != null) {
        try {
          final Map<String, dynamic> json = Map<String, dynamic>.from(
            cachedData is String ? jsonDecode(cachedData) : cachedData,
          );
          return TMDBMetadata.fromJson(json);
        } catch (e) {
          // If error reading cache, we query api again
        }
      }
    }

    // Call TMDB API
    try {
      final apiKey = await _getApiKey();
      final isMovie = type == ChannelType.movie;
      final endpoint = isMovie ? '/search/movie' : '/search/tv';
      
      final queryParams = {
        'query': cleanTitle,
        'language': 'pt-BR',
        'include_adult': 'false',
      };

      if (year != null) {
        if (isMovie) {
          queryParams['year'] = year.toString();
        } else {
          queryParams['first_air_date_year'] = year.toString();
        }
      }

      final headers = <String, String>{};
      if (apiKey.length > 50 || apiKey.startsWith('ey')) {
        headers['Authorization'] = 'Bearer $apiKey';
      } else {
        queryParams['api_key'] = apiKey;
      }

      final uri = Uri.parse('$_baseUrl$endpoint').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List?;
        
        if (results != null && results.isNotEmpty) {
          final firstResult = results.first;
          final genreIds = firstResult['genre_ids'] as List?;
          final genres = _mapGenreIds(genreIds);
          
          final metadataJson = <String, dynamic>{
            'title': firstResult['title'] ?? firstResult['name'] ?? '',
            'poster_path': firstResult['poster_path'],
            'backdrop_path': firstResult['backdrop_path'],
            'overview': firstResult['overview'] ?? 'Sem sinopse disponível.',
            'vote_average': firstResult['vote_average'] ?? 0.0,
            'release_date': firstResult['release_date'] ?? firstResult['first_air_date'],
            'genres': genres,
          };

          final metadata = TMDBMetadata.fromJson(metadataJson);
          
          // Save to Cache
          await _cacheBox!.put(cacheKey, metadataJson);
          return metadata;
        } else {
          // Store empty result in cache to avoid repeatedly querying non-existent media
          await _cacheBox!.put(cacheKey, {'title': title, 'overview': 'Nenhum resultado encontrado no TMDB.', 'genres': <String>[]});
        }
      }
    } catch (e) {
      // Return null on failure (offline/timeout/api error)
    }

    return null;
  }

  String _sanitizeSearchTitle(String title) {
    var clean = title;
    
    // Remove common IPTV decorators
    clean = clean.replaceAll(RegExp(r'\[.*?\]'), ''); // Remove [anything]
    clean = clean.replaceAll(RegExp(r'\(.*?\)'), ''); // Remove (anything)
    clean = clean.replaceAll(RegExp(r'\b(DUBLADO|LEGENDADO|DUB|LEG|2D|3D|MAX|H264|H265|HEVC|4K|1080P|720P|SD|HD|FHD)\b', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'[-:|]'), ' '); // Replace separators with space
    
    // Replace multiple spaces with a single space
    clean = clean.replaceAll(RegExp(r'\s+'), ' ');
    
    return clean.trim();
  }
}
