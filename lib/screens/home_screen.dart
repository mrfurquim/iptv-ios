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
          _buildGroupFilter(groups),
          Expanded(
            child: widget.selectedType == ChannelType.series
                ? _buildSeriesGrid()
                : _buildChannelGrid(channels),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupFilter(List<String> groups) {
    // If the selected group is not in the current list of groups (and not Favorites), 
    // we might have an empty view. We let the user see all groups to pick one.
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: groups.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildFilterChip('Favoritos', '__FAVORITOS__');
          }
          final group = groups[index - 1];
          return _buildFilterChip(group, group);
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = widget.selectedGroup == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            widget.onGroupSelected(value);
          }
        },
        selectedColor: Colors.blue,
        backgroundColor: Colors.grey[800],
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[300],
        ),
      ),
    );
  }

  Widget _buildChannelGrid(List<Channel> channels) {
    if (channels.isEmpty) {
      return const Center(child: Text('Nenhum conteúdo encontrado nesta categoria'));
    }
    return GridView.builder(
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
    );
  }

  Widget _buildSeriesGrid() {
    final seriesList = _getCurrentSeries();
    if (seriesList.isEmpty) {
      return const Center(child: Text('Nenhuma série encontrada nesta categoria'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: seriesList.length,
      itemBuilder: (context, index) {
        final series = seriesList[index];
        return _buildSeriesCard(series);
      },
    );
  }

  List<Series> _getCurrentSeries() {
    if (widget.selectedGroup == '__FAVORITOS__') {
      return []; // To be implemented for series
    }
    return widget.playlist.series[widget.selectedGroup] ?? [];
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

  Widget _buildSeriesCard(Series series) {
    return Card(
      color: Colors.grey[900],
      child: InkWell(
        onTap: () => _showSeriesDialog(series),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (series.logo != null && series.logo!.isNotEmpty)
              Image.network(
                series.logo!,
                height: 60,
                width: 60,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _seriesPlaceholder(series),
              )
            else
              _seriesPlaceholder(series),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                series.title,
                style: const TextStyle(fontSize: 12, color: Colors.white),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seriesPlaceholder(Series series) {
    return Container(
      height: 60,
      width: 60,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          series.title.isNotEmpty ? series.title[0] : '?',
          style: const TextStyle(fontSize: 24, color: Colors.white),
        ),
      ),
    );
  }

  void _showSeriesDialog(Series series) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            final seasons = series.seasons.keys.toList()..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(series.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: seasons.length,
                    itemBuilder: (context, index) {
                      final season = seasons[index];
                      final episodes = series.seasons[season]!..sort((a, b) {
                         return a.name.compareTo(b.name);
                      });
                      return ExpansionTile(
                        title: Text('Temporada $season', style: const TextStyle(color: Colors.white)),
                        children: episodes.map((episode) => ListTile(
                          title: Text(episode.name, style: TextStyle(color: Colors.grey[300])),
                          trailing: const Icon(Icons.play_arrow, color: Colors.blue),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onPlayChannel(episode);
                          },
                        )).toList(),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
