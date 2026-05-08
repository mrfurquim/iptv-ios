import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptv_player/screens/home_screen.dart';
import 'package:iptv_player/services/storage_service.dart';
import 'package:iptv_player/services/api_service.dart';
import 'package:iptv_player/models/playlist.dart';
import 'package:iptv_player/models/channel.dart';
import 'package:iptv_player/screens/player_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCacheDialog(cached);
      });
    } else {
      await _fetchNewM3U();
    }
  }

  void _showCacheDialog(String cachedContent) {
    setState(() {
      _isLoading = false;
    });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Lista Encontrada'),
        content: Text('Você deseja usar a lista salva offline ou baixar uma versão atualizada da internet?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              _processM3UContent(cachedContent);
            },
            child: Text('Usar Offline'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _fetchNewM3U();
            },
            child: Text('Baixar Atualizada'),
          ),
        ],
      ),
    );
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

  void _processM3UContent(String content) {
    try {
      final playlist = _apiService.parseContent(content);
      setState(() {
        _playlist = playlist;
        if (playlist.getGroups(ChannelType.live).isNotEmpty) {
          _selectedGroup = playlist.getGroups(ChannelType.live).first;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Erro ao processar lista: $e";
        _isLoading = false;
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
    );
  }
}
