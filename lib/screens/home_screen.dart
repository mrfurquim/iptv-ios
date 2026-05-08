import 'package:flutter/material.dart';
import 'package:iptv_player/models/channel.dart';
import 'package:iptv_player/models/playlist.dart';
import 'package:iptv_player/screens/player_screen.dart';
import 'package:iptv_player/screens/search_screen.dart';

class HomeScreen extends StatefulWidget {
  final Playlist playlist;
  final ChannelType selectedType;
  final String selectedGroup;
  final Function(ChannelType) onTypeChanged;
  final Function(String) onGroupSelected;
  final Function(Channel) onPlayChannel;
  final Function() onSearch;
  final Function() onCloseSearch;
  final bool showSearch;

  const HomeScreen({
    Key? key,
    required this.playlist,
    required this.selectedType,
    required this.selectedGroup,
    required this.onTypeChanged,
    required this.onGroupSelected,
    required this.onPlayChannel,
    required this.onSearch,
    required this.onCloseSearch,
    required this.showSearch,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    if (widget.showSearch) {
      return SearchScreen(
        playlist: widget.playlist,
        onPlay: widget.onPlayChannel,
        onClose: widget.onCloseSearch,
      );
    }

    final groups = widget.playlist.getGroups(widget.selectedType);
    final channels = _getCurrentChannels();

    return Scaffold(
      appBar: AppBar(
        title: const Text('IPTV Player'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: widget.onSearch,
            tooltip: 'Buscar (Ctrl+K)',
          ),
        ],
      ),
      drawer: _buildSidebar(groups),
      body: Column(
        children: [
          _buildTypeSelector(),
          if (widget.selectedGroup == '__FAVORITOS__')
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Favoritos', style: TextStyle(fontSize: 18)),
            ),
          Expanded(
            child: channels.isEmpty
                ? const Center(child: Text('Nenhum conteúdo encontrado'))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.8,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: channels.length,
                    itemBuilder: (context, index) {
                      final channel = channels[index];
                      return _buildChannelCard(channel);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SegmentedButton<ChannelType>(
        segments: const [
          ButtonSegment(
            value: ChannelType.live,
            label: Text('TV Ao Vivo'),
            icon: Icon(Icons.live_tv),
          ),
          ButtonSegment(
            value: ChannelType.movie,
            label: Text('Filmes'),
            icon: Icon(Icons.movie),
          ),
          ButtonSegment(
            value: ChannelType.series,
            label: Text('Séries'),
            icon: Icon(Icons.tv),
          ),
        ],
        selected: {widget.selectedType},
        onSelectionChanged: (selected) {
          widget.onTypeChanged(selected.first);
        },
      ),
    );
  }

  Widget _buildSidebar(List<String> groups) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text('Categorias', style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          ListTile(
            leading: const Icon(Icons.favorite, color: Colors.red),
            title: const Text('Favoritos'),
            onTap: () {
              Navigator.pop(context);
              widget.onGroupSelected('__FAVORITOS__');
            },
          ),
          const Divider(),
          ...groups.map((group) => ListTile(
                title: Text(group),
                onTap: () {
                  Navigator.pop(context);
                  widget.onGroupSelected(group);
                },
              )),
        ],
      ),
    );
  }

  Widget _buildChannelCard(Channel channel) {
    return Card(
      color: Colors.grey[900],
      child: InkWell(
        onTap: () => widget.onPlayChannel(channel),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (channel.hasLogo)
              Image.network(
                channel.logo!,
                height: 60,
                width: 60,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _placeholder(channel),
              )
            else
              _placeholder(channel),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                channel.displayName,
                style: const TextStyle(fontSize: 12, color: Colors.white),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.play_circle_fill, color: Colors.blue),
              onPressed: () => widget.onPlayChannel(channel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(Channel channel) {
    return Container(
      height: 60,
      width: 60,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          channel.displayName.isNotEmpty ? channel.displayName[0] : '?',
          style: const TextStyle(fontSize: 24, color: Colors.white),
        ),
      ),
    );
  }

  List<Channel> _getCurrentChannels() {
    if (widget.selectedGroup == '__FAVORITOS__') {
      // Return favorites - need to get favorite ids from storage
      // For simplicity, return empty
      return [];
    }
    switch (widget.selectedType) {
      case ChannelType.live:
        return widget.playlist.live[widget.selectedGroup] ?? [];
      case ChannelType.movie:
        return widget.playlist.movie[widget.selectedGroup] ?? [];
      case ChannelType.series:
        return []; // Series handled differently
    }
  }
}
