import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iptv_player/models/channel.dart';
import 'package:iptv_player/models/playlist.dart';
import 'package:iptv_player/screens/search_screen.dart';
import 'package:iptv_player/services/storage_service.dart';
import 'package:iptv_player/services/tmdb_service.dart';
import 'package:iptv_player/models/tmdb_metadata.dart';
import 'package:iptv_player/widgets/tmdb_details_modal.dart';

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
  final bool isParsingBackground;
  final double parseProgress;

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
    this.isParsingBackground = false,
    this.parseProgress = 0.0,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final StorageService _storageService = StorageService();
  int _visibleItemCount = 50;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedGroup != oldWidget.selectedGroup ||
        widget.selectedType != oldWidget.selectedType) {
      setState(() {
        _visibleItemCount = 50;
      });
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final totalItems = widget.selectedType == ChannelType.series
          ? _getCurrentSeries().length
          : _getCurrentChannels().length;
      if (_visibleItemCount < totalItems) {
        setState(() {
          _visibleItemCount += 50;
        });
      }
    }
  }

  void _showMovieDetails(Channel movie) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TMDBDetailsModal(
        movie: movie,
        onPlay: widget.onPlayChannel,
      ),
    );
  }

  void _showSeriesDetails(Series series) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TMDBDetailsModal(
        series: series,
        onPlay: widget.onPlayChannel,
      ),
    );
  }

  void _showSettingsDialog() async {
    final currentKey = await _storageService.getTMDBApiKey() ?? '';
    final controller = TextEditingController(text: currentKey);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configurações TMDB'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Insira sua chave de API do TMDB (v3 API Key) para obter pôsteres e sinopses em tempo real:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'TMDB API Key',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _storageService.saveTMDBApiKey(controller.text.trim());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Configurações do TMDB salvas com sucesso!')),
              );
              setState(() {});
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

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
          if (widget.isParsingBackground) ...[
            Container(
              color: Colors.blue.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Carregando canais em segundo plano... ${(widget.parseProgress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: widget.parseProgress,
              backgroundColor: Colors.transparent,
              color: Colors.blue,
              minHeight: 2,
            ),
          ],
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
    final displayCount = channels.length < _visibleItemCount ? channels.length : _visibleItemCount;
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: displayCount,
      itemBuilder: (context, index) {
        final channel = channels[index];
        if (widget.selectedType == ChannelType.movie) {
          return TMDBMediaCard(
            channel: channel,
            onTap: () => _showMovieDetails(channel),
          );
        }
        return _buildChannelCard(channel);
      },
    );
  }

  Widget _buildSeriesGrid() {
    final seriesList = _getCurrentSeries();
    if (seriesList.isEmpty) {
      return const Center(child: Text('Nenhuma série encontrada nesta categoria'));
    }
    final displayCount = seriesList.length < _visibleItemCount ? seriesList.length : _visibleItemCount;
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: displayCount,
      itemBuilder: (context, index) {
        final series = seriesList[index];
        return TMDBMediaCard(
          series: series,
          onTap: () => _showSeriesDetails(series),
        );
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
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.blue),
            title: const Text('Configurações TMDB'),
            onTap: () {
              Navigator.pop(context);
              _showSettingsDialog();
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

class TMDBMediaCard extends StatefulWidget {
  final Channel? channel;
  final Series? series;
  final VoidCallback onTap;

  const TMDBMediaCard({
    Key? key,
    this.channel,
    this.series,
    required this.onTap,
  }) : super(key: key);

  @override
  _TMDBMediaCardState createState() => _TMDBMediaCardState();
}

class _TMDBMediaCardState extends State<TMDBMediaCard> {
  final TMDBService _tmdbService = TMDBService();
  TMDBMetadata? _metadata;

  @override
  void initState() {
    super.initState();
    _fetchMetadata();
  }

  @override
  void didUpdateWidget(TMDBMediaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.channel?.uuid != oldWidget.channel?.uuid ||
        widget.series?.title != oldWidget.series?.title) {
      setState(() {
        _metadata = null;
      });
      _fetchMetadata();
    }
  }

  Future<void> _fetchMetadata() async {
    final title = widget.channel != null ? widget.channel!.name : widget.series!.title;
    final type = widget.channel != null ? ChannelType.movie : ChannelType.series;
    final year = widget.channel != null ? widget.channel!.year : widget.series!.year;

    final metadata = await _tmdbService.fetchMetadata(title, type, year: year);
    if (mounted) {
      setState(() {
        _metadata = metadata;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = widget.channel != null ? widget.channel!.displayName : widget.series!.title;
    final fallbackLogo = widget.channel != null ? widget.channel!.logo : widget.series!.logo;

    return Card(
      color: Colors.grey[900],
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: _metadata?.posterUrl != null
                    ? CachedNetworkImage(
                        imageUrl: _metadata!.posterUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => _buildFallback(fallbackLogo, displayTitle),
                      )
                    : _buildFallback(fallbackLogo, displayTitle),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              child: Column(
                children: [
                  Text(
                    displayTitle,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_metadata != null && _metadata!.voteAverage > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 12),
                        const SizedBox(width: 2),
                        Text(
                          _metadata!.voteAverage.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback(String? logo, String title) {
    if (logo != null && logo.isNotEmpty) {
      return Container(
        color: Colors.grey[800],
        padding: const EdgeInsets.all(8.0),
        child: CachedNetworkImage(
          imageUrl: logo,
          fit: BoxFit.contain,
          errorWidget: (context, url, error) => _buildTextPlaceholder(title),
        ),
      );
    }
    return _buildTextPlaceholder(title);
  }

  Widget _buildTextPlaceholder(String title) {
    return Container(
      color: Colors.grey[800],
      child: Center(
        child: Text(
          title.isNotEmpty ? title[0] : '?',
          style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
