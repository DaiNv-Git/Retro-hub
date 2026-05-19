import re

with open('lib/main.dart', 'r') as f:
    content = f.read()

def replace_between(text, start_str, end_str, new_str):
    start = text.find(start_str)
    if start == -1: return text
    end = text.find(end_str, start)
    if end == -1: return text
    return text[:start] + new_str + text[end:]

new_emulator = """  String _emulatorHtml() {
    final gameUrl = widget.game.fullUrl;
    final title = widget.game.title;
    if (_emulatorJsDataPath.isEmpty) {
      return '''
<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    html, body {
      height: 100%;
      margin: 0;
      background: #0D0518;
      color: #9D4EDD;
      font-family: sans-serif;
      display: grid;
      place-items: center;
      text-align: center;
      padding: 24px;
      box-sizing: border-box;
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
      width: 100%;
      height: 100%;
      margin: 0;
      background: linear-gradient(135deg, #0D0518 0%, #1A0B2E 100%);
      overflow: hidden;
      touch-action: none;
      font-family: 'Courier New', Courier, monospace;
    }
    #game-container {
      width: 100%;
      height: 100%;
      display: flex;
      justify-content: center;
      align-items: center;
      position: relative;
    }
    #game {
      width: 100%;
      height: 100%;
      box-shadow: 0 0 30px rgba(157, 78, 221, 0.4);
    }
    .crt-overlay {
      position: absolute;
      top: 0; left: 0; right: 0; bottom: 0;
      background: linear-gradient(rgba(18, 16, 16, 0) 50%, rgba(0, 0, 0, 0.25) 50%), linear-gradient(90deg, rgba(255, 0, 0, 0.06), rgba(0, 255, 0, 0.02), rgba(0, 0, 255, 0.06));
      background-size: 100% 4px, 6px 100%;
      pointer-events: none;
      z-index: 999;
      opacity: 0.15;
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
    window.EJS_color = '#9D4EDD';
    window.EJS_Buttons = {
      playPause: true,
      restart: true,
      mute: true,
      settings: true,
      fullscreen: true,
      saveState: true,
      loadState: true
    };
  </script>
  <script src="\${_emulatorJsDataPath}loader.js"></script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0518),
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
                color: const Color(0xFF0D0518),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF9D4EDD).withOpacity(0.1),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF9D4EDD).withOpacity(0.3), blurRadius: 30)
                          ],
                        ),
                        child: const CircularProgressIndicator(
                          color: Color(0xFFD2BBFF),
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.romPath == null ? 'BOOTING ROM...' : 'LOADING GAME...',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFD2BBFF),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
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
"""

content = replace_between(content, "  String _emulatorHtml() {", "class GameSearchDelegate", new_emulator + "}\n")

with open('lib/main.dart', 'w') as f:
    f.write(content)
