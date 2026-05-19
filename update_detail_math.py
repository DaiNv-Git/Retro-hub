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
    this.allItems = const [],
  });

  final Wallpaper wallpaper;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final List<Wallpaper> allItems;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _fileSize = '--MB';
  String _rating = '5.0';
  String _saves = '0M';
  List<String> _tags = [];
  
  @override
  void initState() {
    super.initState();
    _fetchFileSize();
    _generateRandomStats();
  }

  void _generateRandomStats() {
    final rand = math.Random(widget.wallpaper.id.hashCode);
    _rating = (4.0 + rand.nextDouble() * 0.9).toStringAsFixed(1);
    _saves = '${(rand.nextDouble() * 5 + 0.1).toStringAsFixed(1)}M';
    
    final allTags = ['RPG', 'COLLECTOR', 'TURN-BASED', 'ACTION', 'PLATFORMER', 'FIGHTING', 'PUZZLE', 'RACING', 'ADVENTURE'];
    allTags.shuffle(rand);
    _tags = allTags.take(3).toList();
  }

  Future<void> _fetchFileSize() async {
    try {
      final response = await Dio().head(widget.wallpaper.fullUrl);
      final contentLength = response.headers.value('content-length');
      if (contentLength != null) {
        final bytes = int.tryParse(contentLength);
        if (bytes != null) {
          if (mounted) {
            setState(() {
              _fileSize = '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
            });
          }
        }
      }
    } catch (_) {}
  }

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
                            IconButton(
                              icon: const Icon(Icons.search, color: Color(0xFFD2BBFF)),
                              onPressed: () {
                                if (widget.allItems.isNotEmpty) {
                                  showSearch(
                                    context: context,
                                    delegate: GameSearchDelegate(widget.allItems),
                                  );
                                }
                              },
                            ),
                            const SizedBox(width: 4),
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
                      Expanded(child: _buildStatBox(Icons.star, Colors.green, _rating, 'RATING')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatBox(Icons.download, const Color(0xFFD2BBFF), _saves, 'SAVES')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatBox(Icons.sd_storage, const Color(0xFFD2BBFF), _fileSize, 'SIZE')),
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                'Battle through the region with new expanded features. Navigate the clash to awaken legendary allies. Experience the ultimate RPG odyssey with enhanced challenges and seamless compatibility.',
                                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14, height: 1.5),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.info_outline, color: Colors.white24, size: 20),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _tags.map((t) => _buildTag(t)).toList(),
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
                  _buildReviewCard('AceTrainer_92', 'The definitive experience. Emulator runs smooth as silk on Retro Hub at 60fps with zero input lag.', 5),
                  const SizedBox(height: 12),
                  _buildReviewCard('PixelQueen', 'Best version of the games. Battle Frontier is still a masterclass in endgame design.', 5),
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

  Widget _buildReviewCard(String user, String text, int stars) {
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
              Row(
                children: List.generate(
                  stars,
                  (index) => const Icon(Icons.star, color: Colors.green, size: 12),
                ),
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
"""

content = re.sub(r'class DetailScreen extends StatefulWidget \{.*?(?=class EmulatorScreen)', new_detail, content, flags=re.DOTALL)

with open("lib/main.dart", "w") as f:
    f.write(content)

