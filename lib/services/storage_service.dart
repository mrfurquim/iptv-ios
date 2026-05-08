import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/channel.dart';

class StorageService {
  static const _m3uCacheKey = 'iptv_m3u_cache';
  static const _favoritesKey = 'iptv_favorites';

  Future<bool> saveM3U(String content) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_m3uCacheKey, content);
  }

  Future<String?> loadM3U() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_m3uCacheKey);
  }

  Future<void> clearM3UCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_m3uCacheKey);
  }

  Future<List<String>> getFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoritesKey) ?? [];
  }

  Future<void> toggleFavorite(String channelUuid) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavoriteIds();
    if (favorites.contains(channelUuid)) {
      favorites.remove(channelUuid);
    } else {
      favorites.add(channelUuid);
    }
    await prefs.setStringList(_favoritesKey, favorites);
  }

  Future<bool> isFavorite(String channelUuid) async {
    final favorites = await getFavoriteIds();
    return favorites.contains(channelUuid);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_m3uCacheKey);
    await prefs.remove(_favoritesKey);
  }
}
