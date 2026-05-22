import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:iptv_player/models/playlist.dart';
import 'package:iptv_player/services/m3u_parser.dart';

class ApiService {
  static const String defaultM3UUrl =
      'http://auth.talegal.click/get.php?username=64984163246&password=ql2wlomp6yr&type=m3u_plus&output=m3u8';

  final M3UParser _parser = M3UParser();

  Future<String> fetchRawPlaylist({String url = defaultM3UUrl}) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return utf8.decode(response.bodyBytes);
      } else {
        throw Exception('Falha ao carregar lista: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  Future<Playlist> parseContentAsync(
    String content, {
    void Function(Playlist partialPlaylist, double progress)? onProgress,
  }) async {
    return await _parser.parse(content, onProgress: onProgress);
  }

  Future<Playlist> fetchPlaylist({
    String url = defaultM3UUrl,
    void Function(Playlist partialPlaylist, double progress)? onProgress,
  }) async {
    final content = await fetchRawPlaylist(url: url);
    return await parseContentAsync(content, onProgress: onProgress);
  }
}
