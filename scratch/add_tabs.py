import os

new_code = """import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

const _emulatorJsDataPath = String.fromEnvironment('EMULATOR_JS_DATA_PATH');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const RetroHubApp());
}

class RetroHubApp extends StatelessWidget {
  const RetroHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Retro Hub',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0914),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF9D4EDD),
          surface: Color(0xFF151026),
        ),
      ),
      home: const MainTabScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ==========================================
// THEMES & MODELS
// ==========================================

class EmulatorTheme {
  final String id;
  final String name;
  final String backgroundCss;
  final String glowColor;
  final String overlayCss;

  const EmulatorTheme({
    required this.id,
    required this.name,
    required this.backgroundCss,
    required this.glowColor,
    required this.overlayCss,
  });
}

const List<EmulatorTheme> availableThemes = [
  EmulatorTheme(
    id: 'neon',
    name: 'Neon Cyberpunk',
    backgroundCss: 'linear-gradient(135deg, #0D0518 0%, #1A0B2E 100%)',
    glowColor: '#9D4EDD',
    overlayCss: '''
      background: linear-gradient(rgba(18, 16, 16, 0) 50%, rgba(0, 0, 0, 0.25) 50%), linear-gradient(90deg, rgba(255, 0, 0, 0.06), rgba(0, 255, 0, 0.02), rgba(0, 0, 255, 0.06));
      background-size: 100% 4px, 6px 100%;
      opacity: 0.15;
    ''',
  ),
  EmulatorTheme(
    id: 'classic',
    name: 'Classic CRT',
    backgroundCss: '#222222',
    glowColor: '#73DB9A',
    overlayCss: '''
      background: repeating-linear-gradient(0deg, transparent, transparent 2px, rgba(0,0,0,0.2) 2px, rgba(0,0,0,0.2) 4px);
      opacity: 0.3;
    ''',
  ),
  EmulatorTheme(
    id: 'clean',
    name: 'Clean Dark',
    backgroundCss: '#000000',
    glowColor: 'transparent',
    overlayCss: 'display: none;',
  ),
];

class HomebrewGame {
  final String title;
  final String developer;
  final String description;
  final String coverUrl;
  final String downloadUrl;

  const HomebrewGame({
    required this.title,
    required this.developer,
    required this.description,
    required this.coverUrl,
    required this.downloadUrl,
  });
}

// This list contains 100% legal, public domain / homebrew games.
// You will need to host the actual .gba ROM files on your server and update the 'downloadUrl'.
final List<HomebrewGame> legalGames = [
  const HomebrewGame(
    title: 'Anguna: Warriors of Virtue',
    developer: 'Bite the Chili Productions',
    description: 'A top-down fantasy action-RPG featuring multiple dungeons, hidden items, and boss fights. Completely free and open-source.',
    coverUrl: 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&w=500&q=80', // Placeholder
    downloadUrl: 'https://engfordev.top/gbagame/homebrew/anguna.gba', // Example URL
  ),
  const HomebrewGame(
    title: 'Apotris',
    developer: 'akouzoukos',
    description: 'A highly polished block puzzle game designed specifically for the GBA. Fast-paced and fully featured.',
    coverUrl: 'https://images.unsplash.com/photo-1614680376573-df3480f0c6ff?auto=format&fit=crop&w=500&q=80', // Placeholder
    downloadUrl: 'https://engfordev.top/gbagame/homebrew/apotris.gba', // Example URL
  ),
  const HomebrewGame(
    title: 'Celeste Classic GBA',
    developer: 'Lemonhaze',
    description: 'A faithful port of the original Pico-8 Celeste mountain climbing game to the Game Boy Advance.',
    coverUrl: 'https://images.unsplash.com/photo-1522115174737-2497162f69ec?auto=format&fit=crop&w=500&q=80', // Placeholder
    downloadUrl: 'https://engfordev.top/gbagame/homebrew/celeste.gba', // Example URL
  ),
  const HomebrewGame(
    title: 'Goodboy Advance',
    developer: 'Homebrew Community',
    description: 'An exciting and charming platformer created by indie developers for the retro handheld community.',
    coverUrl: 'https://images.unsplash.com/photo-1552820728-8b83bb6b773f?auto=format&fit=crop&w=500&q=80', // Placeholder
    downloadUrl: 'https://engfordev.top/gbagame/homebrew/goodboy.gba', // Example URL
  )
];

// Global state for theme selection
EmulatorTheme _globalSelectedTheme = availableThemes.first;

// ==========================================
// MAIN TAB SCREEN
// ==========================================

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomebrewLibraryScreen(),
    const ConsoleConfigScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: const Color(0xFF0B0914),
          selectedItemColor: const Color(0xFF9D4EDD),
          unselectedItemColor: Colors.white38,
          selectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.normal, fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Library',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_input_component_rounded),
              label: 'My Console',
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// LIBRARY SCREEN (TAB 0)
// ==========================================

class HomebrewLibraryScreen extends StatelessWidget {
  const HomebrewLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'INDIE LIBRARY',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '100% Free & Legal Homebrew Games',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                color: const Color(0xFF73DB9A),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: legalGames.length,
                separatorBuilder: (_, __) => const SizedBox(height: 20),
                itemBuilder: (context, index) {
                  final game = legalGames[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1525),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 140,
                          child: CachedNetworkImage(
                            imageUrl: game.coverUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: const Color(0xFF2A2A2A)),
                            errorWidget: (context, url, error) => Container(
                              color: const Color(0xFF2A2A2A),
                              child: const Icon(Icons.image_not_supported, color: Colors.white24, size: 40),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                game.title,
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'By \${game.developer}',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: const Color(0xFF9D4EDD),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                game.description,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: Colors.white60,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    // You can implement download logic here or direct play
                                    // For now, we will show a snackbar since URLs are placeholders
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Upload \${game.title} ROM to your server first!')),
                                    );
                                  },
                                  icon: const Icon(Icons.cloud_download_rounded, color: Colors.white, size: 20),
                                  label: Text(
                                    'GET GAME',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF9D4EDD),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// CONSOLE CONFIG SCREEN (TAB 1)
// ==========================================

class ConsoleConfigScreen extends StatefulWidget {
  const ConsoleConfigScreen({super.key});

  @override
  State<ConsoleConfigScreen> createState() => _ConsoleConfigScreenState();
}

class _ConsoleConfigScreenState extends State<ConsoleConfigScreen> {
  Future<void> _joinDiscord() async {
    final url = Uri.parse('https://discord.com');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Discord link')),
      );
    }
  }

  Future<void> _importGame() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gba', 'zip', 'gbc', 'gb', 'nes'],
      );
      if (result != null && result.files.single.path != null) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EmulatorScreen(
              romPath: result.files.single.path!,
              theme: _globalSelectedTheme,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting file: \$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MY CONSOLE',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 32),
            _buildActionCard(
              title: 'Join Community',
              subtitle: 'Connect with other homebrew players on Discord.',
              icon: Icons.discord,
              color: const Color(0xFF5865F2),
              onTap: _joinDiscord,
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              title: 'Import & Play',
              subtitle: 'Load your legally obtained .gba or .zip ROMs.',
              icon: Icons.sports_esports_rounded,
              color: const Color(0xFF73DB9A),
              onTap: _importGame,
            ),
            const SizedBox(height: 48),
            Text(
              'GAME THEME',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: availableThemes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final theme = availableThemes[index];
                  final isSelected = _globalSelectedTheme.id == theme.id;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _globalSelectedTheme = theme;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF9D4EDD).withOpacity(0.2) : const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF9D4EDD) : const Color(0xFF333333),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? const Color(0xFF9D4EDD) : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? const Color(0xFF9D4EDD) : Colors.white54,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 16, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            theme.name,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color.withOpacity(0.5), size: 16),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// EMULATOR SCREEN
// ==========================================

class EmulatorScreen extends StatefulWidget {
  const EmulatorScreen({super.key, required this.romPath, required this.theme});

  final String romPath;
  final EmulatorTheme theme;

  @override
  State<EmulatorScreen> createState() => _EmulatorScreenState();
}

class _EmulatorScreenState extends State<EmulatorScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadHtmlString(_emulatorHtml());
  }

  String _emulatorHtml() {
    final gameUrl = 'file://${widget.romPath}';
    final title = widget.romPath.split('/').last;

    if (_emulatorJsDataPath.isEmpty) {
      return '''
<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    html, body {
      height: 100%; margin: 0; background: #0D0518; color: #9D4EDD; font-family: sans-serif;
      display: grid; place-items: center; text-align: center; padding: 24px; box-sizing: border-box;
    }
  </style>
</head>
<body>
  <main>
    <h3>Emulator runtime is not bundled.</h3>
  </main>
</body>
</html>
''';
    }
    return '''
<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" />
  <style>
    html, body {
      width: 100%; height: 100%; margin: 0;
      background: ${widget.theme.backgroundCss};
      overflow: hidden; touch-action: none; font-family: 'Courier New', Courier, monospace;
    }
    #game-container { width: 100%; height: 100%; display: flex; justify-content: center; align-items: center; position: relative; }
    #game { width: 100%; height: 100%; box-shadow: 0 0 30px ${widget.theme.glowColor}; }
    .crt-overlay {
      position: absolute; top: 0; left: 0; right: 0; bottom: 0; pointer-events: none; z-index: 999;
      ${widget.theme.overlayCss}
    }
  </style>
</head>
<body>
  <div id="game-container">
    <div id="game"></div>
    <div class="crt-overlay"></div>
  </div>
  <script>
    window.EJS_player = '#game';
    window.EJS_core = 'gba';
    window.EJS_gameName = ${jsonEncode(title)};
    window.EJS_gameUrl = ${jsonEncode(gameUrl)};
    window.EJS_pathtodata = ${jsonEncode(_emulatorJsDataPath)};
    window.EJS_startOnLoaded = true;
    window.EJS_theme = 'dark';
    window.EJS_color = '${widget.theme.glowColor == 'transparent' ? '#000000' : widget.theme.glowColor}';
    window.EJS_Buttons = { playPause: true, restart: true, mute: true, settings: true, fullscreen: true, saveState: true, loadState: true };
  </script>
  <script src="${_emulatorJsDataPath}loader.js"></script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: WebViewWidget(controller: _controller),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
          ),
          if (_loading)
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF9D4EDD).withOpacity(0.1),
                          boxShadow: [BoxShadow(color: const Color(0xFF9D4EDD).withOpacity(0.3), blurRadius: 30)],
                        ),
                        child: const CircularProgressIndicator(color: Color(0xFFD2BBFF), strokeWidth: 3),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'BOOTING ROM...',
                        style: GoogleFonts.outfit(color: const Color(0xFFD2BBFF), fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
"""

with open('lib/main.dart', 'w') as f:
    f.write(new_code)
