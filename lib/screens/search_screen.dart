import 'package:flutter/material.dart';
import 'package:iptv_player/models/channel.dart';
import 'package:iptv_player/models/playlist.dart';
import 'package:iptv_player/screens/player_screen.dart';
class SearchScreen extends StatefulWidget {
  final Playlist playlist;
  final Function(Channel) onPlay;
  final Function() onClose;

  const SearchScreen({
    Key? key,
    required this.playlist,
    required this.onPlay,
    required this.onClose,
  }) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Channel> _results = [];

  void _performSearch(String query) {
    if (query.length < 2) {
      setState(() => _results = []);
      return;
    }

    final q = query.toLowerCase();
    final found = <Channel>[];

    // Search in live channels
    for (final group in widget.playlist.live.values) {
      for (final channel in group) {
        if (channel.name.toLowerCase().contains(q)) {
          found.add(channel);
        }
      }
    }

    // Search in movies
    for (final group in widget.playlist.movie.values) {
      for (final channel in group) {
        if (channel.name.toLowerCase().contains(q)) {
          found.add(channel);
        }
      }
    }

    setState(() => _results = found.take(30).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Busca Global'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onClose,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar canais, filmes e séries...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch('');
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _performSearch,
            ),
          ),
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchController.text.length < 2) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 50, color: Colors.grey),
            SizedBox(height: 16),
            Text('Digite pelo menos 2 caracteres para buscar'),
            SizedBox(height: 8),
            Text('Busca simultânea em TV Ao Vivo, Filmes e Séries',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 50, color: Colors.orange),
            const SizedBox(height: 16),
            Text('Nenhum resultado para "${_searchController.text}"'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final channel = _results[index];
        return ListTile(
          leading: channel.hasLogo
              ? Image.network(channel.logo!, width: 40, height: 40, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _placeholder(channel))
              : _placeholder(channel),
          title: Text(channel.displayName),
          subtitle: Text(channel.group),
          trailing: const Icon(Icons.play_arrow, color: Colors.blue),
          onTap: () {
            widget.onPlay(channel);
          },
        );
      },
    );
  }

  Widget _placeholder(Channel channel) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          channel.displayName.isNotEmpty ? channel.displayName[0] : '?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
