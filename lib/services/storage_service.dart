import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class StorageService {
  static const _m3uCacheKey = 'iptv_m3u_cache';
  static const _favoritesKey = 'iptv_favorites';

  Future<File?> _getLocalFile() async {
    if (kIsWeb) return null;
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_m3uCacheKey.m3u');
  }

  Future<bool> saveM3U(String content) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        return await prefs.setString(_m3uCacheKey, content);
      } else {
        final file = await _getLocalFile();
        if (file != null) {
          await file.writeAsString(content);
          return true;
        }
        return false;
      }
    } catch (e) {
      print('Error saving M3U: $e');
      return false;
    }
  }

  Future<String?> loadM3U() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(_m3uCacheKey);
      } else {
        final file = await _getLocalFile();
        if (file != null && await file.exists()) {
          return await file.readAsString();
        }
        return null;
      }
    } catch (e) {
      print('Error loading M3U: $e');
      return null;
    }
  }

  Future<void> clearM3UCache() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_m3uCacheKey);
    } else {
      final file = await _getLocalFile();
      if (file != null && await file.exists()) {
        await file.delete();
      }
    }
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
