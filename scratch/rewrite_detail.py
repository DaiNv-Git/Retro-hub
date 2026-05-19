import re

with open('lib/main.dart', 'r') as f:
    content = f.read()

def replace_between(text, start_str, end_str, new_str):
    start = text.find(start_str)
    if start == -1: return text
    end = text.find(end_str, start)
    if end == -1: return text
    return text[:start] + new_str + text[end:]

# Replace state variables and download method with joinDiscord and importGame
new_methods = """class _DetailScreenState extends State<DetailScreen> {
  String? _fileSizeLabel;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFileSize());
  }

  Future<void> _loadFileSize() async {
    if (!widget.wallpaper.isPlayableRom) return;
    if (widget.wallpaper.downloadSizeBytes != null &&
        widget.wallpaper.downloadSizeBytes! > 0) {
      setState(() => _fileSizeLabel = _formatByteSize(widget.wallpaper.downloadSizeBytes!));
      return;
    }
  }

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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gba', 'zip', 'gbc', 'gb'],
      );
      if (result != null && result.files.single.path != null) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EmulatorScreen(
              game: widget.wallpaper,
              romPath: result.files.single.path,
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

"""

content = replace_between(content, "class _DetailScreenState extends State<DetailScreen> {", "  @override\n  Widget build(BuildContext context) {", new_methods)

# Now replace the buttons
new_buttons = """                  ElevatedButton.icon(
                    onPressed: _joinDiscord,
                    icon: const Icon(Icons.discord, color: Colors.white),
                    label: const Text('JOIN DISCORD COMMUNITY', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5865F2), // Discord Blurple
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _importGame,
                    icon: const Icon(Icons.file_upload_outlined, color: Color(0xFF73DB9A)),
                    label: const Text('IMPORT & PLAY LOCAL ROM', style: TextStyle(color: Color(0xFF73DB9A), fontSize: 14, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF73DB9A)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),"""

content = replace_between(content, "                  ElevatedButton.icon(", "                  if (infoRows.isNotEmpty) ...[", new_buttons + "\n")

with open('lib/main.dart', 'w') as f:
    f.write(content)
