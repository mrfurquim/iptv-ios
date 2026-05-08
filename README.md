# IPTV Player - Flutter Edition

Aplicativo cross-platform (iOS, Android, Web) desenvolvido em **Flutter** para reprodução de conteúdo IPTV.

## Estrutura do Projeto

```
/home/ubuntu/iptv-flutter/
├── lib/
│   ├── models/
│   │   └── channel.dart          # Channel, Series, Playlist, ChannelType
│   ├── services/
│   │   ├── m3u_parser.dart     # Parser M3U em Dart
│   │   ├── storage_service.dart # SharedPreferences
│   │   └── api_service.dart    # HTTP fetch
│   ├── screens/
│   │   ├── home_screen.dart    # Tela principal com grid
│   │   ├── player_screen.dart  # Player com video_player + chewie
│   │   └── search_screen.dart  # Busca global
│   └── main.dart               # Entry point
├── assets/                      # Imagens (se necessário)
├── documentation/               # Docs adicionais
└── pubspec.yaml                 # Dependências
```

## Tecnologias

- **Flutter 3.x** (Dart 3)
- **video_player** + **chewie** para reprodução de vídeo HLS
- **shared_preferences** para persistência
- **cached_network_image** para logos
- **http** para networking

## Funcionalidades Implementadas

### ✅ Core

1. **M3U Parser (Dart)**
   - Parse de M3U/M3U8
   - Categorização (Live, Movies, Series)
   - Extração de metadados (logo, group, tvg-id)
   - Organização por qualidade (FHD, HD, 4K)
   - Parsing de séries (S01E20)

2. **Video Player**
   - Integração com video_player (HLS nativo)
   - Controles via Chewie (play/pause, fullscreen)
   - Suporte a streams m3u8

3. **UI (Material Design)**
   - Home screen com SegmentedButton para categorias
   - Drawer (sidebar) com grupos
   - Grid de canais com cards
   - Busca global
   - Player fullscreen

4. **Armazenamento**
   - Cache de playlist (SharedPreferences)
   - Estrutura para favoritos

## Como Executar

### Pré-requisitos
- Flutter SDK instalado (3.0+)
- Dart SDK
- Dispositivo iOS/Android ou emulador

### Passos

```bash
cd /home/ubuntu/iptv-flutter
flutter pub get
flutter run  # iOS, Android, Web, Desktop
```

Para iOS específico:
```bash
flutter build ios  # Gera IPA para distribuição
```

## Configuração

### URL da Playlist
Edite `lib/services/api_service.dart`:
```dart
static const String defaultM3UUrl = 'SUA_URL_AQUI';
```

### Permissões (iOS/Android)
- **iOS**: No `ios/Runner/Info.plist`, adicione:
  ```xml
  <key>NSAppTransportSecurity</key>
  <dict>
      <key>NSAllowsArbitraryLoads</key>
      <true/>
  </dict>
  ```
- **Android**: No `android/app/src/main/AndroidManifest.xml`, adicione permissão de internet.

## Status do Projeto

| Componente | Status |
|------------|--------|
| Models | ✅ Completo |
| M3U Parser | ✅ Completo |
| Storage Service | ✅ Estrutura pronta |
| Home Screen | ✅ Funcional |
| Player Screen | ✅ Usando Chewie |
| Search Screen | ✅ Funcional |
| Favoritos | ⏳ Estrutura criada |
| Séries Grid | ⏳ Pendente |
| Testes | ⏳ Pendente |

## Diferenças: SwiftUI vs Flutter

| Aspecto | SwiftUI | Flutter |
|---------|---------|--------|
| Linguagem | Swift 6 | Dart 3 |
| UI Framework | Nativo Apple | Widget tree |
| Player | AVKit | video_player + Chewie |
| Plataforma | Apenas iOS | iOS, Android, Web, Desktop |
| Hot Reload | ❌ | ✅ |
| Performance | Nativa | Nativa (Skia) |

## Próximos Passos

1. ✅ Estrutura base criada
2. ⏳ Implementar Series Grid
3. ⏳ Adicionar favoritos completos
4. ⏳ Testes unitários (M3U Parser)
5. ⏳ Build IPA (via `flutter build ios` ou CI/CD)

---

**Data**: 2026-05-08  
**Desenvolvedor**: iOS Senior Engineer (migrado para Flutter)  
**Projeto Original**: iptv-ios (React/Electron)  
**Projeto SwiftUI**: iptv-ios-native (SwiftUI)  
**Projeto Flutter**: iptv-flutter (Dart/Flutter) 🚀
