import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iptv_player/models/channel.dart';
import 'package:iptv_player/models/tmdb_metadata.dart';
import 'package:iptv_player/services/tmdb_service.dart';

class TMDBDetailsModal extends StatefulWidget {
  final Channel? movie;
  final Series? series;
  final Function(Channel) onPlay;

  const TMDBDetailsModal({
    Key? key,
    this.movie,
    this.series,
    required this.onPlay,
  })  : assert(movie != null || series != null, 'Deve fornecer um filme ou uma série'),
        super(key: key);

  @override
  _TMDBDetailsModalState createState() => _TMDBDetailsModalState();
}

class _TMDBDetailsModalState extends State<TMDBDetailsModal> {
  final TMDBService _tmdbService = TMDBService();
  TMDBMetadata? _metadata;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMetadata();
  }

  Future<void> _fetchMetadata() async {
    final title = widget.movie != null ? widget.movie!.name : widget.series!.title;
    final type = widget.movie != null ? ChannelType.movie : ChannelType.series;
    final year = widget.movie != null ? widget.movie!.year : widget.series!.year;

    final metadata = await _tmdbService.fetchMetadata(title, type, year: year);
    if (mounted) {
      setState(() {
        _metadata = metadata;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMovie = widget.movie != null;
    final displayTitle = isMovie ? widget.movie!.name : widget.series!.title;
    final fallbackLogo = isMovie ? widget.movie!.logo : widget.series!.logo;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 350,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Backdrop Image Banner
                    Stack(
                      children: [
                        if (_metadata?.backdropUrl != null)
                          ShaderMask(
                            shaderCallback: (rect) {
                              return const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.black, Colors.transparent],
                              ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
                            },
                            blendMode: BlendMode.dstIn,
                            child: CachedNetworkImage(
                              imageUrl: _metadata!.backdropUrl!,
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: Colors.grey[900]),
                              errorWidget: (_, __, ___) => const SizedBox(),
                            ),
                          )
                        else
                          Container(
                            height: 120,
                            color: Colors.grey[900]?.withOpacity(0.5),
                          ),
                        // Close button
                        Positioned(
                          top: 16,
                          right: 16,
                          child: CircleAvatar(
                            backgroundColor: Colors.black.withOpacity(0.5),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Poster image card
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _metadata?.posterUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: _metadata!.posterUrl!,
                                    height: 150,
                                    width: 100,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(color: Colors.grey[800]),
                                    errorWidget: (_, __, ___) => _buildFallbackPoster(fallbackLogo, displayTitle),
                                  )
                                : _buildFallbackPoster(fallbackLogo, displayTitle),
                          ),
                          const SizedBox(width: 16),
                          // Movie Info Title, Rating, Year
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Text(
                                  _metadata?.title ?? displayTitle,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 18),
                                    const SizedBox(width: 4),
                                    Text(
                                      _metadata != null ? _metadata!.voteAverage.toStringAsFixed(1) : 'N/A',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 16),
                                    if (_metadata?.releaseDate != null && _metadata!.releaseDate!.length >= 4)
                                      Text(
                                        _metadata!.releaseDate!.substring(0, 4),
                                        style: TextStyle(color: Colors.grey[400]),
                                      )
                                    else if (isMovie && widget.movie!.year != null)
                                      Text(
                                        widget.movie!.year.toString(),
                                        style: TextStyle(color: Colors.grey[400]),
                                      )
                                    else if (!isMovie && widget.series!.year != null)
                                      Text(
                                        widget.series!.year.toString(),
                                        style: TextStyle(color: Colors.grey[400]),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (_metadata?.genres != null && _metadata!.genres.isNotEmpty)
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: _metadata!.genres
                                        .map((genre) => Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.blue.withOpacity(0.3), width: 0.5),
                                              ),
                                              child: Text(
                                                genre,
                                                style: const TextStyle(fontSize: 10, color: Colors.blue),
                                              ),
                                            ))
                                        .toList(),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Play Button for movies
                    if (isMovie)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.blue, Colors.indigo],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onPlay(widget.movie!);
                            },
                            icon: const Icon(Icons.play_arrow, size: 28, color: Colors.white),
                            label: const Text(
                              'Assista Agora',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Synopsis / Overview
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sinopse',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _metadata?.overview ?? 'Nenhuma sinopse disponível.',
                            style: TextStyle(fontSize: 14, color: Colors.grey[300], height: 1.4),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Seasons / Episodes list for Series
                    if (!isMovie) _buildSeasonsList(),
                    
                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildFallbackPoster(String? logo, String title) {
    return Container(
      height: 150,
      width: 100,
      color: Colors.grey[800],
      child: Center(
        child: logo != null && logo.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: logo,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => _buildTextPlaceholder(title),
              )
            : _buildTextPlaceholder(title),
      ),
    );
  }

  Widget _buildTextPlaceholder(String title) {
    return Text(
      title.isNotEmpty ? title[0] : '?',
      style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildSeasonsList() {
    final seasons = widget.series!.seasons.keys.toList()
      ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));

    if (seasons.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.0),
        child: Text('Nenhum episódio disponível para esta série.', style: TextStyle(color: Colors.grey)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
            child: Text(
              'Temporadas & Episódios',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          ...seasons.map((season) {
            final episodes = widget.series!.seasons[season]!
              ..sort((a, b) => a.name.compareTo(b.name));
            return Card(
              color: Colors.grey[950]?.withOpacity(0.5),
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
              child: ExpansionTile(
                collapsedTextColor: Colors.white,
                textColor: Colors.blue,
                iconColor: Colors.blue,
                collapsedIconColor: Colors.grey,
                title: Text(
                  'Temporada $season',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${episodes.length} episódios',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                children: episodes.map((episode) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    title: Text(episode.name, style: TextStyle(color: Colors.grey[300])),
                    trailing: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.play_arrow, color: Colors.blue, size: 20),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onPlay(episode);
                    },
                  );
                }).toList(),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
