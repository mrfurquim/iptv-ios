class TMDBMetadata {
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final String overview;
  final double voteAverage;
  final String? releaseDate;
  final List<String> genres;

  TMDBMetadata({
    required this.title,
    this.posterPath,
    this.backdropPath,
    required this.overview,
    required this.voteAverage,
    this.releaseDate,
    required this.genres,
  });

  String? get posterUrl => posterPath != null && posterPath!.isNotEmpty
      ? 'https://image.tmdb.org/t/p/w500$posterPath'
      : null;

  String? get backdropUrl => backdropPath != null && backdropPath!.isNotEmpty
      ? 'https://image.tmdb.org/t/p/w780$backdropPath'
      : null;

  factory TMDBMetadata.fromJson(Map<String, dynamic> json) {
    var genreList = <String>[];
    if (json['genres'] != null) {
      genreList = List<String>.from(json['genres']);
    } else if (json['genre_ids'] != null) {
      // Map basic genre ids to names if needed, or leave empty. We can map some common ones or keep it simple.
      // If fetched from detailed endpoint, it will have genre names.
    }
    
    return TMDBMetadata(
      title: json['title'] ?? json['name'] ?? '',
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      overview: json['overview'] ?? 'Sem sinopse disponível.',
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      releaseDate: json['release_date'] ?? json['first_air_date'],
      genres: genreList,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'poster_path': posterPath,
        'backdrop_path': backdropPath,
        'overview': overview,
        'vote_average': voteAverage,
        'release_date': releaseDate,
        'genres': genres,
      };
}
