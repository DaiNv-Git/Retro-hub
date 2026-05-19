import re

with open("lib/main.dart", "r") as f:
    content = f.read()

new_detail = """
class DetailScreen extends StatefulWidget {
  const DetailScreen({
    super.key,
    required this.wallpaper,
    required this.isFavorite,
    required this.onFavorite,
  });

  final Wallpaper wallpaper;
  final bool isFavorite;
  final VoidCallback onFavorite;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final downloadUrl = widget.wallpaper.fullUrl;
      final lowerUrl = downloadUrl.toLowerCase();
      final isImage = lowerUrl.endsWith('.jpg') || lowerUrl.endsWith('.jpeg') || lowerUrl.endsWith('.png') || lowerUrl.endsWith('.webp');
      
      final ext = downloadUrl.contains('.') ? '.${downloadUrl.split('.').last}' : (isImage ? '.jpg' : '.zip');
      
      final temp = await getTemporaryDirectory();
      final file = File('${temp.path}/${widget.wallpaper.id}$ext');

      await Dio().download(
        downloadUrl, 
        file.path,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      if (!isImage) {
        await Share.shareXFiles([XFile(file.path)], text: 'Save your ROM');
      } else {
        final bytes = await file.readAsBytes();
        await Gal.putImageBytes(bytes, name: widget.wallpaper.id, album: 'Retro Hub');
      }

      InterstitialAdService.instance.recordAction();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!isImage ? 'Ready to save/share!' : 'Saved to Gallery! 🎉'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E2630),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Download failed. Please try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131313),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                ShaderMask(
                  shaderCallback: (rect) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black, Colors.transparent],
                      stops: [0.6, 1.0],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: CachedNetworkImage(
                    imageUrl: widget.wallpaper.thumbUrl,
                    height: 350,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(height: 350, color: const Color(0xFF2A2A2A)),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Text(
                          'RETRO HUB',
                          style: GoogleFonts.spaceGrotesk(
                            color: const Color(0xFFD2BBFF),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.search, color: Color(0xFFD2BBFF)),
                            const SizedBox(width: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 28, height: 28,
                                color: const Color(0xFF3F008E),
                                child: const Icon(Icons.person, color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          border: Border.all(color: Colors.green.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.wallpaper.category.toUpperCase(),
                          style: GoogleFonts.jetBrainsMono(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.wallpaper.title,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildStatBox(Icons.star, Colors.green, '4.9', 'RATING')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatBox(Icons.download, const Color(0xFFD2BBFF), '2.4M', 'SAVES')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatBox(Icons.sd_storage, const Color(0xFFD2BBFF), '16MB', 'SIZE')),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => EmulatorScreen(game: widget.wallpaper)));
                    },
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    label: const Text('PLAY NOW', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _download,
                    icon: _isDownloading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green))
                        : const Icon(Icons.cloud_download_outlined, color: Colors.green),
                    label: Text(
                      _isDownloading ? 'DOWNLOADING ${(_downloadProgress * 100).toInt()}%' : 'DOWNLOAD ROM',
                      style: const TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold)
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.green),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text('SYSTEM INTEL', style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF333333)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Battle through the region with new expanded features. Navigate the clash to awaken legendary allies. Experience the ultimate RPG odyssey with enhanced challenges and seamless compatibility.',
                          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14, height: 1.5),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildTag('RPG'),
                            const SizedBox(width: 8),
                            _buildTag('COLLECTOR'),
                            const SizedBox(width: 8),
                            _buildTag('TURN-BASED'),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('COMMUNITY FEEDBACK', style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      Text('View All', style: GoogleFonts.outfit(color: const Color(0xFFD2BBFF), fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildReviewCard('AceTrainer_92', 'The definitive experience. Emulator runs smooth as silk on Retro Hub at 60fps with zero input lag.'),
                  const SizedBox(height: 12),
                  _buildReviewCard('PixelQueen', 'Best version of the games. Battle Frontier is still a masterclass in endgame design.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(IconData icon, Color iconColor, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 6),
              Text(value, style: GoogleFonts.jetBrainsMono(color: iconColor, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF333333),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 10)),
    );
  }

  Widget _buildReviewCard(String user, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 12,
                backgroundColor: Color(0xFF3F008E),
                child: Icon(Icons.person, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(user, style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              const Row(
                children: [
                  Icon(Icons.star, color: Colors.green, size: 12),
                  Icon(Icons.star, color: Colors.green, size: 12),
                  Icon(Icons.star, color: Colors.green, size: 12),
                  Icon(Icons.star, color: Colors.green, size: 12),
                  Icon(Icons.star, color: Colors.green, size: 12),
                ],
              )
            ],
          ),
          const SizedBox(height: 12),
          Text(text, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}

class EmulatorScreen extends StatefulWidget {
  final Wallpaper game;
  const EmulatorScreen({super.key, required this.game});

  @override
  State<EmulatorScreen> createState() => _EmulatorScreenState();
}

class _EmulatorScreenState extends State<EmulatorScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131313),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'RETRO HUB',
          style: GoogleFonts.spaceGrotesk(
            color: const Color(0xFFD2BBFF),
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 32, height: 32,
                  color: const Color(0xFF3F008E),
                  child: const Icon(Icons.person, color: Colors.white, size: 18),
                ),
              ),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTriggerBtn('L-TRIGGER'),
                  _buildTriggerBtn('R-TRIGGER'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Game screen
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 240,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF73DB9A), width: 2),
                image: DecorationImage(
                  image: CachedNetworkImageProvider(widget.game.thumbUrl),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.2), BlendMode.darken),
                )
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        border: Border.all(color: const Color(0xFF73DB9A)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('FPS', style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 10)),
                          const SizedBox(width: 8),
                          Text('59.8', style: GoogleFonts.jetBrainsMono(color: const Color(0xFF73DB9A), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const Center(
                    child: Icon(Icons.play_circle_fill, color: Colors.white54, size: 64),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // D-Pad and AB Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDPad(),
                  _buildActionButtons(),
                ],
              ),
            ),
            const Spacer(),
            // Select and Start
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPillButton('SELECT'),
                const SizedBox(width: 32),
                _buildPillButton('START'),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTriggerBtn(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4A4455)),
      ),
      child: Text(label, style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDPad() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Align(alignment: Alignment.topCenter, child: _dpadArrow(Icons.arrow_drop_up)),
          Align(alignment: Alignment.bottomCenter, child: _dpadArrow(Icons.arrow_drop_down)),
          Align(alignment: Alignment.centerLeft, child: _dpadArrow(Icons.arrow_left)),
          Align(alignment: Alignment.centerRight, child: _dpadArrow(Icons.arrow_right)),
          Center(
            child: Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(color: Color(0xFF2A2A2A), shape: BoxShape.circle),
            ),
          )
        ],
      ),
    );
  }

  Widget _dpadArrow(IconData icon) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: Colors.white54, size: 24),
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: 140, height: 120,
      child: Stack(
        children: [
          Positioned(
            top: 0, right: 0,
            child: _buildRoundBtn('A', const Color(0xFF8B5CF6)),
          ),
          Positioned(
            bottom: 0, left: 0,
            child: _buildRoundBtn('B', const Color(0xFF333333)),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundBtn(String label, Color color) {
    return Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: Center(
        child: Text(label, style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildPillButton(String label) {
    return Column(
      children: [
        Container(
          width: 56, height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF4A4455)),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 10)),
      ],
    );
  }
}
"""

content = re.sub(r'class DetailScreen extends StatefulWidget \{.*?(?=class GameSearchDelegate)', new_detail, content, flags=re.DOTALL)

with open("lib/main.dart", "w") as f:
    f.write(content)

