import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:iptv_player/screens/home_screen.dart';
import 'package:iptv_player/services/storage_service.dart';
import 'package:iptv_player/services/api_service.dart';
import 'package:iptv_player/models/playlist.dart';
import 'package:iptv_player/models/channel.dart';
import 'package:iptv_player/screens/player_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);  
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Playlist? _playlist;
  ChannelType _selectedType = ChannelType.live;
  String _selectedGroup = '';
  bool _isLoading = true;
  String? _error;
  bool _showSearch = false;

  bool _needsCacheDecision = false;
  String? _cachedContent;
  
  double _parseProgress = 0.0;
  bool _isParsingBackground = false;

  final _storageService = StorageService();
  final _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _checkLocalCache();
  }

  Future<void> _checkLocalCache() async {
    final cached = await _storageService.loadM3U();
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _needsCacheDecision = true;
        _cachedContent = cached;
        _isLoading = false;
      });
    } else {
      await _fetchNewM3U();
    }
  }

  Future<void> _fetchNewM3U() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final content = await _apiService.fetchRawPlaylist();
      await _storageService.saveM3U(content);
      _processM3UContent(content);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _processM3UContent(String content) async {
    try {
      setState(() {
        _isParsingBackground = true;
        _parseProgress = 0.0;
        _error = null;
      });

      await _apiService.parseContentAsync(
        content,
        onProgress: (partialPlaylist, progress) {
          setState(() {
            _playlist = partialPlaylist;
            _parseProgress = progress;
            _isLoading = false; // Show Home screen as soon as we have initial content

            if (_selectedGroup.isEmpty) {
              final groups = partialPlaylist.getGroups(_selectedType);
              if (groups.isNotEmpty) {
                _selectedGroup = groups.first;
              }
            }
          });
        },
      );

      setState(() {
        _isParsingBackground = false;
        _parseProgress = 1.0;
      });
    } catch (e) {
      setState(() {
        _error = "Erro ao processar lista: $e";
        _isLoading = false;
        _isParsingBackground = false;
      });
    }
  }

  void _selectType(ChannelType type) {
    setState(() {
      _selectedType = type;
      final groups = _playlist?.getGroups(type) ?? [];
      if (groups.isNotEmpty) {
        _selectedGroup = groups.first;
      } else {
        _selectedGroup = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IPTV Player',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900],
        ),
      ),
      home: Builder(
        builder: (context) => _buildHome(context),
      ),
      debugShowCheckedModeBanner: false,
    );
  }

  Widget _buildHome(BuildContext context) {
    if (_needsCacheDecision) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.storage, size: 64, color: Colors.blue),
              SizedBox(height: 24),
              Text('Lista Offline Encontrada', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              Text('Deseja usar a lista offline ou baixar a mais recente?', textAlign: TextAlign.center),
              SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: Icon(Icons.offline_bolt),
                    onPressed: () {
                      setState(() {
                        _needsCacheDecision = false;
                        _isLoading = true;
                      });
                      _processM3UContent(_cachedContent!);
                    },
                    label: Text('Usar Offline'),
                  ),
                  SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: Icon(Icons.cloud_download),
                    onPressed: () {
                      setState(() {
                        _needsCacheDecision = false;
                      });
                      _fetchNewM3U();
                    },
                    label: Text('Baixar Nova'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Carregando sua lista IPTV...'),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.orange, size: 50),
              SizedBox(height: 16),
              Text(_error!),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchNewM3U,
                child: Text('Tentar Novamente'),
              ),
            ],
          ),
        ),
      );
    }
    if (_playlist == null) {
      return Scaffold(
        body: Center(
          child: Text('Nenhum conteúdo encontrado.'),
        ),
      );
    }
    return HomeScreen(
      playlist: _playlist!,
      selectedType: _selectedType,
      selectedGroup: _selectedGroup,
      onTypeChanged: _selectType,
      onGroupSelected: (group) => setState(() => _selectedGroup = group),
      onPlayChannel: (channel) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PlayerScreen(channel: channel),
          ),
        );
      },
      onSearch: () => setState(() => _showSearch = true),
      onCloseSearch: () => setState(() => _showSearch = false),
      showSearch: _showSearch,
      isParsingBackground: _isParsingBackground,
      parseProgress: _parseProgress,
    );
  }
}
