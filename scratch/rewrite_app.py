import os

new_code = """import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  EmulatorTheme _selectedTheme = availableThemes.first;

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
              theme: _selectedTheme,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting file: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RETRO HUB',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your Legal Emulation Station',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  color: const Color(0xFFD2BBFF),
                ),
              ),
              const SizedBox(height: 48),
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
                    final isSelected = _selectedTheme.id == theme.id;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedTheme = theme),
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
    final gameUrl = 'file://\${widget.romPath}';
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
      background: \${widget.theme.backgroundCss};
      overflow: hidden; touch-action: none; font-family: 'Courier New', Courier, monospace;
    }
    #game-container { width: 100%; height: 100%; display: flex; justify-content: center; align-items: center; position: relative; }
    #game { width: 100%; height: 100%; box-shadow: 0 0 30px \${widget.theme.glowColor}; }
    .crt-overlay {
      position: absolute; top: 0; left: 0; right: 0; bottom: 0; pointer-events: none; z-index: 999;
      \${widget.theme.overlayCss}
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
    window.EJS_gameName = \${jsonEncode(title)};
    window.EJS_gameUrl = \${jsonEncode(gameUrl)};
    window.EJS_pathtodata = \${jsonEncode(_emulatorJsDataPath)};
    window.EJS_startOnLoaded = true;
    window.EJS_theme = 'dark';
    window.EJS_color = '\${widget.theme.glowColor == 'transparent' ? '#000000' : widget.theme.glowColor}';
    window.EJS_Buttons = { playPause: true, restart: true, mute: true, settings: true, fullscreen: true, saveState: true, loadState: true };
  </script>
  <script src="\${_emulatorJsDataPath}loader.js"></script>
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
