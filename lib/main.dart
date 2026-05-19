import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart' hide X509Certificate;

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const AiWallpaperApp());
}

class AiWallpaperApp extends StatelessWidget {
  const AiWallpaperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentTheme, child) {
        return MaterialApp(
          title: 'Retro Hub',
          debugShowCheckedModeBanner: false,
          themeMode: currentTheme,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFD2BBFF),
              brightness: Brightness.light,
              surface: const Color(0xFFF0F0F0),
            ),
            scaffoldBackgroundColor: const Color(0xFFF0F0F0),
            textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
            appBarTheme: const AppBarTheme(
              centerTitle: false,
              backgroundColor: Colors.transparent,
              elevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle.dark,
              titleTextStyle: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
              iconTheme: IconThemeData(color: Colors.black),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFD2BBFF),
              brightness: Brightness.dark,
              surface: const Color(0xFF131313),
            ),
            scaffoldBackgroundColor: const Color(0xFF131313),
            textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
            appBarTheme: const AppBarTheme(
              centerTitle: false,
              backgroundColor: Colors.transparent,
              elevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle.light,
            ),
          ),
          home: const GalleryScreen(),
        );
      },
    );
  }
}

class Wallpaper {
  const Wallpaper({
    required this.id,
    required this.title,
    required this.category,
    required this.thumbUrl,
    required this.fullUrl,
    required this.accent,
    this.sourceUrl,
    this.platform,
    this.region,
    this.version,
    this.releaseDate,
    this.licenseName,
    this.licenseUrl,
    this.contentOwner,
    this.downloadSizeBytes,
    this.distributionRightsConfirmed = false,
  });

  final String id;
  final String title;
  final String category;
  final String thumbUrl;
  final String fullUrl;
  final Color accent;
  final String? sourceUrl;
  final String? platform;
  final String? region;
  final String? version;
  final DateTime? releaseDate;
  final String? licenseName;
  final String? licenseUrl;
  final String? contentOwner;
  final int? downloadSizeBytes;
  final bool distributionRightsConfirmed;

  factory Wallpaper.fromJson(Map<String, dynamic> json, int index) {
    final id = '${json['id'] ?? index}';
    final platform = _cleanString(json['platform']);
    final region = _cleanString(json['region']);
    final platformStr = platform ?? region ?? 'Other';
    final title = _cleanString(json['title']) ?? 'Game #$id';
    final thumb = _cleanString(json['thumbnail']) ?? '';
    final full = _cleanString(json['download_link']) ??
        _cleanString(json['downloadUrl']) ??
        _cleanString(json['url']) ??
        '';
    final sizeValue = json['download_size_bytes'] ?? json['downloadSizeBytes'];

    return Wallpaper(
      id: id,
      title: title,
      category: platformStr.isEmpty ? 'Other' : platformStr,
      thumbUrl: thumb,
      fullUrl: full,
      accent: _accentColors[index % _accentColors.length],
      sourceUrl: _cleanString(json['link']),
      platform: platform,
      region: region,
      version: _cleanString(json['version']),
      releaseDate: DateTime.tryParse('${json['date'] ?? ''}'),
      licenseName: _cleanString(json['license']) ?? _cleanString(json['licenseName']),
      licenseUrl: _cleanString(json['license_url']) ?? _cleanString(json['licenseUrl']),
      contentOwner: _cleanString(json['content_owner']) ?? _cleanString(json['contentOwner']),
      downloadSizeBytes: sizeValue is int ? sizeValue : int.tryParse('$sizeValue'),
      distributionRightsConfirmed: json['distribution_rights_confirmed'] == true ||
          json['distributionRightsConfirmed'] == true,
    );
  }

  bool get isPlayableRom {
    final path = Uri.tryParse(fullUrl)?.path.toLowerCase() ?? fullUrl.toLowerCase();
    return path.endsWith('.zip') ||
        path.endsWith('.gba') ||
        path.endsWith('.gbc') ||
        path.endsWith('.gb');
  }

  bool get canDistribute {
    return isPlayableRom && fullUrl.startsWith('https://');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Wallpaper && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

String? _cleanString(Object? value) {
  final text = '$value'.trim();
  if (value == null || text.isEmpty || text == 'null') return null;
  return text
      .replaceAll('&#8211;', '-')
      .replaceAll('&amp;', '&')
      .replaceAll('&#038;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'");
}

String _fileExtensionFromUrl(String url, String fallback) {
  final path = Uri.tryParse(url)?.path ?? url;
  final lastSegment = path.split('/').last;
  final dotIndex = lastSegment.lastIndexOf('.');
  if (dotIndex == -1 || dotIndex == lastSegment.length - 1) return fallback;
  return lastSegment.substring(dotIndex);
}

String _formatByteSize(int bytes) {
  if (bytes <= 0) return '';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }
  final precision = value >= 10 || unitIndex == 0 ? 0 : 1;
  return '${value.toStringAsFixed(precision)} ${units[unitIndex]}';
}

String _formatDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

Future<File> _downloadGameFile(
  Wallpaper item, {
  void Function(double progress)? onProgress,
}) async {
  final ext = _fileExtensionFromUrl(item.fullUrl, '.zip');
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/${item.id}$ext');

  await Dio().download(
    item.fullUrl,
    file.path,
    onReceiveProgress: (received, total) {
      if (total > 0) onProgress?.call(received / total);
    },
  );
  return file;
}

Future<bool> _confirmDownload(BuildContext context, Wallpaper item) async {
  final size = item.downloadSizeBytes == null
      ? null
      : _formatByteSize(item.downloadSizeBytes!);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1C1B1B),
        title: Text(
          'Download game?',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          [
            if (size != null) 'Download size: $size',
            if (item.contentOwner != null) 'Owner: ${item.contentOwner}',
            if (item.licenseName != null) 'License: ${item.licenseName}',
            'Only download games you are allowed to use.',
          ].join('\n'),
          style: GoogleFonts.outfit(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Download'),
          ),
        ],
      );
    },
  );
  return result == true;
}

const _dataUrl = String.fromEnvironment(
  'RETRO_HUB_CATALOG_URL',
  defaultValue: 'https://engfordev.top/gbagame/data.json',
);
const _emulatorJsDataPath = String.fromEnvironment('EMULATOR_JS_DATA_PATH');

const _accentColors = [
  Color(0xFF00E5FF),
  Color(0xFFFF3D00),
  Color(0xFFB388FF),
  Color(0xFF00E676),
  Color(0xFFFFC400),
  Color(0xFFFF4081),
];

class WallpaperRepository {
  Future<List<Wallpaper>> fetch() async {
    print('DataUrl: "$_dataUrl"');
    if (_dataUrl.isEmpty) return [];
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
          'Accept': 'application/json',
        },
      ),
    );
    final response = await dio.get(_dataUrl);
    final data = response.data;
    if (data == null) return [];
    
    List<dynamic> raw;
    if (data is String) {
      if (data.isEmpty) return [];
      raw = jsonDecode(data) as List<dynamic>;
    } else if (data is List) {
      raw = data;
    } else {
      raw = [];
    }
    
    final result = raw
        .whereType<Map<String, dynamic>>()
        .toList()
        .asMap()
        .entries
        .map((entry) => Wallpaper.fromJson(entry.value, entry.key))
        .where((item) => item.canDistribute)
        .toList();
    print('Fetched ${result.length} items');
    return result;
  }
}

class InterstitialAdService {
  InterstitialAdService._();
  static final instance = InterstitialAdService._();

  void recordAction() {}
}

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with SingleTickerProviderStateMixin {
  final WallpaperRepository _repository = WallpaperRepository();
  List<Wallpaper> _allItems = [];
  List<Wallpaper> _items = [];

  bool _loading = true;
  String? _error;

  static const _all = 'All Licensed Games';
  String _activeCategory = _all;
  List<String> _categories = [];

  int _visibleCount = 20;
  final int _batchSize = 20;

  int _currentIndex = 0;
  final Set<Wallpaper> _favorites = {};

  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  late AnimationController _animController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadWallpapers();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text;
        _applyFilters();
      });
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilters() {
    Iterable<Wallpaper> filtered = _allItems;
    if (_activeCategory != _all) {
      filtered = filtered.where((e) => e.category == _activeCategory);
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where(
        (e) => e.title.toLowerCase().contains(_searchQuery.toLowerCase()),
      );
    }
    _items = filtered.take(_visibleCount).toList();
  }

  Future<void> _loadWallpapers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repository.fetch();
      items.shuffle();
      if (!mounted) return;
      setState(() {
        _allItems = items;
        _categories = [
          _all,
          ...{for (final item in items) item.category}.toList()..sort(),
        ];
        _applyFilters();
        _loading = false;
        _animController.forward();
      });
    } catch (e, st) {
      print('Fetch Error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Oops! We could not fetch the latest games.';
      });
    }
  }

  Widget _buildHomeView() {
    final featured = _allItems.isNotEmpty ? _allItems.first : null;
    final trending = _allItems.skip(1).take(5).toList();

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          toolbarHeight: 70,
          pinned: true,
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.85),
          surfaceTintColor: Colors.transparent,
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(color: Colors.transparent),
            ),
          ),
          titleSpacing: 16,
          title: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9D4EDD), Color(0xFF5A189A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF9D4EDD).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Icon(
                  Icons.sports_esports_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Retro Hub',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: IconButton(
                onPressed: () {
                  showSearch(context: context, delegate: GameSearchDelegate(_allItems));
                },
                icon: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (featured != null) ...[
                  Text(
                    'Featured',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRetroHero(featured),
                  const SizedBox(height: 32),
                ],
                Text(
                  'Categories',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final active = cat == _activeCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _activeCategory = cat;
                              _visibleCount = _batchSize;
                              _applyFilters();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: active
                                  ? const LinearGradient(colors: [Color(0xFF9D4EDD), Color(0xFF5A189A)])
                                  : null,
                              color: active ? null : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: active ? Colors.transparent : Colors.white.withOpacity(0.1),
                              ),
                              boxShadow: active
                                  ? [BoxShadow(color: const Color(0xFF9D4EDD).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                                  : [],
                            ),
                            child: Text(
                              cat,
                              style: GoogleFonts.outfit(
                                color: active ? Colors.white : Colors.white70,
                                fontSize: 14,
                                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Explore Games',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == _items.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _visibleCount += _batchSize;
                            _applyFilters();
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF9D4EDD).withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.arrow_downward_rounded, color: Color(0xFFD2BBFF)),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Load More',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFD2BBFF),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return _buildItemCard(_items[index], index);
              },
              childCount: _items.length < _allItems.length ? _items.length + 1 : _items.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLibraryView() {
    final favoritesList = _favorites.toList();
    return Scaffold(
      backgroundColor: const Color(0xFF131313),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131313),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF3F008E)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const Icon(Icons.person, color: Color(0xFFD2BBFF), size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'RETRO HUB',
              style: GoogleFonts.spaceGrotesk(
                color: const Color(0xFFD2BBFF),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF4A4455)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.search, color: Color(0xFFD2BBFF), size: 20),
              onPressed: () {
                showSearch(
                  context: context,
                  delegate: GameSearchDelegate(_allItems),
                );
              },
            ),
          )
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('ALL', true),
                _buildFilterChip('GBA', false),
                _buildFilterChip('GBC', false),
                _buildFilterChip('GB', false),
                _buildFilterChip('NES', false),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Library', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Icon(Icons.sort, color: Color(0xFF73DB9A), size: 16),
                    const SizedBox(width: 4),
                    Text('RECENT', style: GoogleFonts.jetBrainsMono(color: const Color(0xFF73DB9A), fontSize: 12, fontWeight: FontWeight.bold)),
                    const Icon(Icons.keyboard_arrow_down, color: Color(0xFF73DB9A), size: 16),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: favoritesList.isEmpty
                ? const Center(child: Text('No licensed games saved yet.', style: TextStyle(color: Colors.white54)))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: favoritesList.length,
                    itemBuilder: (context, index) {
                      return _buildItemCard(favoritesList[index], index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFD2BBFF) : Colors.transparent,
        border: Border.all(color: isSelected ? const Color(0xFFD2BBFF) : const Color(0xFF4A4455)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          color: isSelected ? const Color(0xFF3F008E) : const Color(0xFFE5E2E1),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  Widget _buildSocialView() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Community'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2B125A), Color(0xFF100825)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x33D2BBFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFD2BBFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.forum_rounded, color: Color(0xFF3F008E)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Join the Hub Social',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Connect with other retro players. Share scores, discuss homebrew projects, and follow licensed releases.',
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final Uri url = Uri.parse('https://discord.gg/vSh2kmcR');
                    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Could not launch Discord link.')),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD2BBFF),
                    foregroundColor: const Color(0xFF3F008E),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Go to Discord', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Recent Posts',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 16),
          _buildPostCard('HomebrewDev', 'Testing a new public-domain platformer build tonight. Feedback on controls is welcome.', '2h ago', 12, 4),
          const SizedBox(height: 12),
          _buildPostCard('PixelRunner', 'Looking for licensed chiptune packs for a tiny arcade project.', '5h ago', 4, 1),
          const SizedBox(height: 12),
          _buildPostCard('SpeedRunGuy', 'New personal best on an open homebrew runner: 11m 42s.', '1d ago', 45, 8),
        ],
      ),
    );
  }

  Widget _buildPostCard(String author, String content, String time, int likes, int comments) {
    return Card(
      color: Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                  child: Text(author[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(author, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(content, style: const TextStyle(height: 1.4)),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.thumb_up_alt_outlined, size: 18, color: Colors.grey),
                const SizedBox(width: 4),
                Text('$likes', style: const TextStyle(color: Colors.grey)),
                const SizedBox(width: 16),
                const Icon(Icons.comment_outlined, size: 18, color: Colors.grey),
                const SizedBox(width: 4),
                Text('$comments', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsView() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentTheme, _) {
        final isDark = currentTheme == ThemeMode.dark;
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: const Text('Settings'),
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              ListTile(
                leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                title: const Text('Theme'),
                subtitle: Text(isDark ? 'Dark Mode (Tap to toggle)' : 'Light Mode (Tap to toggle)'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.storage),
                title: const Text('Clear Cache'),
                subtitle: const Text('Free up storage space'),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache cleared!')));
                },
              ),
              const Divider(),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('About'),
                subtitle: Text('Retro Hub v1.0.0'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRetroHero(Wallpaper? item) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        onTap: item == null
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DetailScreen(
                      wallpaper: item,
                      isFavorite: false,
                      onFavorite: () {},
                    ),
                  ),
                );
              },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x554A4455)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item != null)
                CachedNetworkImage(
                  imageUrl: item.thumbUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      Container(color: const Color(0xFF201F1F)),
                  errorWidget: (_, _, _) => Container(
                    color: const Color(0xFF201F1F),
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: Color(0xFFCCC3D8),
                    ),
                  ),
                )
              else
                Container(color: const Color(0xFF201F1F)),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.35),
                      const Color(0xFF131313),
                    ],
                    stops: const [0, 0.52, 1],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x3300834B),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: const Color(0x5573DB9A)),
                      ),
                      child: Text(
                        'GAME OF THE DAY',
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFF73DB9A),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (item?.title ?? 'THE LEGEND OF ZELDA').toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        color: const Color(0xFFE5E2E1),
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: item == null
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => DetailScreen(
                                        wallpaper: item,
                                        isFavorite: false,
                                        onFavorite: () {},
                                      ),
                                    ),
                                  );
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD2BBFF),
                            foregroundColor: const Color(0xFF3F008E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 10,
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: const Text(
                            'DETAILS',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton(
                          onPressed: () {
                            if (item != null) {
                              setState(() {
                                if (_favorites.contains(item)) {
                                  _favorites.remove(item);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${item.title} removed from library!'),
                                      backgroundColor: const Color(0xFF7C3AED),
                                    ),
                                  );
                                } else {
                                  _favorites.add(item);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${item.title} added to library!'),
                                      backgroundColor: const Color(0xFF7C3AED),
                                    ),
                                  );
                                }
                              });
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            fixedSize: const Size(48, 32),
                            padding: EdgeInsets.zero,
                            foregroundColor: const Color(0xFF73DB9A),
                            side: const BorderSide(color: Color(0xFF73DB9A)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Icon(Icons.add_rounded, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return Column(
      children: [
        _CategoryTile(
          title: 'New Releases',
          subtitle: 'Latest patches & indie ports',
          icon: Icons.rocket_launch_outlined,
          wide: true,
          onTap: () => _selectCategory(_all),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _CategoryTile(
                title: 'Ready\nTo Play',
                subtitle: 'Community\nfavorites',
                icon: Icons.trending_up_rounded,
                onTap: () => _selectCategory(_all),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CategoryTile(
                title: 'Anime\nGems',
                subtitle: 'Japanese\nexclusives',
                icon: Icons.auto_awesome_rounded,
                onTap: () => _selectCategory(
                  _categories.length > 1 ? _categories[1] : _all,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _selectCategory(String category) {
    setState(() {
      _activeCategory = category;
      _visibleCount = _batchSize;
      _applyFilters();
    });
    // Scroll down to the grid
    _scrollController.animateTo(
      650,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  Widget _buildTrendingSection(List<Wallpaper> items) {
    final rows = items.isEmpty ? _items.take(3).toList() : items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(width: 4, height: 32, color: const Color(0xFFD2BBFF)),
            const SizedBox(width: 12),
            Text(
              'Licensed Picks',
              style: GoogleFonts.spaceGrotesk(
                color: const Color(0xFFE5E2E1),
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                _selectCategory(_all);
                setState(() => _visibleCount = _allItems.length);
                _scrollController.animateTo(
                  650,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                );
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'VIEW ALL',
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFFD2BBFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < rows.length; i++) ...[
          _TrendingRomRow(item: rows[i], progress: [0.75, 1.0, 0.5][i % 3]),
          if (i != rows.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }



  Widget _buildItemCard(Wallpaper item, int index) {
    final meta = [
      item.platform ?? item.category,
      if (item.region != null) item.region!,
      if (item.version != null) 'v${item.version}',
    ].join(' • ');

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DetailScreen(
              wallpaper: item,
              isFavorite: _favorites.contains(item),
              onFavorite: () {
                setState(() {
                  if (_favorites.contains(item)) {
                    _favorites.remove(item);
                  } else {
                    _favorites.add(item);
                  }
                });
              },
              allItems: _allItems,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: item.accent.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: item.thumbUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: const Color(0xFF1A1A1A)),
                errorWidget: (_, __, ___) => Container(color: const Color(0xFF1A1A1A)),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.4),
                        Colors.black.withOpacity(0.95),
                      ],
                      stops: const [0.4, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Text(
                        item.category.toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(
                        color: item.accent.withOpacity(0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.videogame_asset_off_rounded,
                    size: 64,
                    color: Colors.white54,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loadWallpapers,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                IndexedStack(
                  index: _currentIndex,
                  children: [
                    _buildHomeView(),
                    _buildLibraryView(),
                    _buildSocialView(),
                    _buildSettingsView(),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _RetroBottomNav(
                    currentIndex: _currentIndex,
                    onTap: (index) {
                      setState(() => _currentIndex = index);
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.wide = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xFF201F1F),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF4A4455)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                Positioned(
                  top: -2,
                  right: 0,
                  child: Icon(
                    icon,
                    color: const Color(0x664A4455),
                    size: wide ? 34 : 30,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          style: GoogleFonts.spaceGrotesk(
                            color: const Color(0xFFE5E2E1),
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFCCC3D8),
                          fontSize: 14,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendingRomRow extends StatefulWidget {
  const _TrendingRomRow({required this.item, required this.progress});

  final Wallpaper item;
  final double progress;

  @override
  State<_TrendingRomRow> createState() => _TrendingRomRowState();
}

class _TrendingRomRowState extends State<_TrendingRomRow> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  Future<void> _download() async {
    if (_isDownloading || !widget.item.canDistribute) return;
    final accepted = await _confirmDownload(context, widget.item);
    if (!accepted || !mounted) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final file = await _downloadGameFile(
        widget.item,
        onProgress: (progress) {
          if (mounted) setState(() => _downloadProgress = progress);
        },
      );

      InterstitialAdService.instance.recordAction();
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmulatorScreen(game: widget.item, romPath: file.path),
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
    final progressColor = _isDownloading ? const Color(0xFFD2BBFF) : const Color(0xFF73DB9A);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DetailScreen(
              wallpaper: widget.item,
              isFavorite: false,
              onFavorite: () {},
              allItems: const [],
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 106,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1B1B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF4A4455)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: widget.item.thumbUrl,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  width: 64,
                  height: 64,
                  color: const Color(0xFF3A3939),
                ),
                errorWidget: (_, _, _) => Container(
                  width: 64,
                  height: 64,
                  color: const Color(0xFF3A3939),
                  child: const Icon(
                    Icons.videogame_asset_outlined,
                    color: Color(0xFFCCC3D8),
                    size: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFE5E2E1),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isDownloading 
                            ? '${(_downloadProgress * 100).round()}%\nDOWNLOADING' 
                            : 'GAME',
                        style: GoogleFonts.jetBrainsMono(
                          color: progressColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    [
                      widget.item.platform ?? widget.item.category,
                      if (widget.item.region != null) widget.item.region!,
                      if (widget.item.version != null) 'v${widget.item.version}',
                    ].join('  -  ').toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFFCCC3D8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  if (_isDownloading) ...[
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LinearProgressIndicator(
                        value: _downloadProgress,
                        minHeight: 4,
                        backgroundColor: const Color(0xFF353534),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFD2BBFF),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _download,
              child: Container(
                width: 36,
                height: 40,
                decoration: BoxDecoration(
                  color: _isDownloading ? const Color(0xFF3F008E) : const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _isDownloading ? const Color(0xFFD2BBFF) : const Color(0xFF4A4455)),
                ),
                child: _isDownloading
                    ? const Padding(
                        padding: EdgeInsets.all(10.0),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFD2BBFF),
                        ),
                      )
                    : const Icon(
                        Icons.download_rounded,
                        color: Color(0xFFD2BBFF),
                        size: 18,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RetroBottomNav extends StatelessWidget {
  const _RetroBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 73,
          padding: EdgeInsets.only(
            left: 26,
            right: 26,
            bottom: MediaQuery.paddingOf(context).bottom > 0 ? 8 : 0,
          ),
          decoration: BoxDecoration(
            color: const Color(0xCC0E0E0E),
            border: const Border(top: BorderSide(color: Color(0xFF4A4455))),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF73DB9A).withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                active: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.videogame_asset_outlined,
                label: 'Library',
                active: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.groups_2_outlined,
                label: 'Social',
                active: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                active: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF73DB9A) : const Color(0xFFCCC3D8);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: active ? const Color(0x3300834B) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: active ? Border.all(color: const Color(0x5573DB9A)) : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: active
                ? const EdgeInsets.symmetric(horizontal: 14, vertical: 5)
                : const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: active ? 18 : 20),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: GoogleFonts.jetBrainsMono(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



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
      final result = await FilePicker.pickFiles(
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

  @override
  Widget build(BuildContext context) {
    final infoRows = <MapEntry<String, String>>[
      if (widget.wallpaper.platform != null) MapEntry('Platform', widget.wallpaper.platform!),
      if (widget.wallpaper.region != null) MapEntry('Region', widget.wallpaper.region!),
      if (widget.wallpaper.version != null) MapEntry('Version', widget.wallpaper.version!),
      if (widget.wallpaper.releaseDate != null)
        MapEntry('Release date', _formatDate(widget.wallpaper.releaseDate!)),
      if (_fileSizeLabel != null) MapEntry('Download size', _fileSizeLabel!),
      if (widget.wallpaper.sourceUrl != null) MapEntry('Source', Uri.tryParse(widget.wallpaper.sourceUrl!)?.host ?? widget.wallpaper.sourceUrl!),
    ];
    final statBoxes = <Widget>[
      if (_fileSizeLabel != null)
        _buildStatBox(Icons.sd_storage, const Color(0xFFD2BBFF), _fileSizeLabel!, 'SIZE'),
      if (widget.wallpaper.version != null)
        _buildStatBox(Icons.info_outline, const Color(0xFF73DB9A), 'v${widget.wallpaper.version}', 'VERSION'),
      if (widget.wallpaper.region != null)
        _buildStatBox(Icons.public, const Color(0xFFD2BBFF), widget.wallpaper.region!, 'REGION'),
    ];

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
                    errorWidget: (context, error, stackTrace) => Container(height: 350, color: const Color(0xFF2A2A2A)),
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
                        const SizedBox(width: 48),
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
                          color: Colors.green.withValues(alpha: 0.1),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
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
                  if (statBoxes.isNotEmpty) ...[
                    _buildStatRow(statBoxes),
                    const SizedBox(height: 24),
                  ],
                  ElevatedButton.icon(
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
                  ),
                  if (infoRows.isNotEmpty) ...[
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
                        children: [
                          for (var i = 0; i < infoRows.length; i++) ...[
                            _buildInfoRow(infoRows[i].key, infoRows[i].value),
                            if (i != infoRows.length - 1) const Divider(color: Color(0xFF333333), height: 18),
                          ],
                        ],
                      ),
                    ),
                  ],
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

  Widget _buildStatRow(List<Widget> statBoxes) {
    return Row(
      children: [
        for (var i = 0; i < statBoxes.length; i++) ...[
          Expanded(child: statBoxes[i]),
          if (i != statBoxes.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14, height: 1.3),
          ),
        ),
      ],
    );
  }
}

class EmulatorScreen extends StatefulWidget {
  const EmulatorScreen({super.key, required this.game, this.romPath});

  final Wallpaper game;
  final String? romPath;

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
    window.EJS_gameName = ${jsonEncode(title)};
    window.EJS_gameUrl = ${jsonEncode(gameUrl)};
    window.EJS_pathtodata = ${jsonEncode(_emulatorJsDataPath)};
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
  <script src="${_emulatorJsDataPath}loader.js"></script>
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
}
class GameSearchDelegate extends SearchDelegate<Wallpaper?> {
  final List<Wallpaper> items;
  GameSearchDelegate(this.items);

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF131313),
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.white54),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    if (query.isEmpty) return null;
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildList();

  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    final results = items.where((e) => e.title.toLowerCase().contains(query.toLowerCase())).toList();
    if (results.isEmpty) {
      return Container(
        color: const Color(0xFF131313),
        child: const Center(
          child: Text('No licensed games found.', style: TextStyle(color: Colors.white54)),
        ),
      );
    }
    return Container(
      color: const Color(0xFF131313),
      child: ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, index) {
          final item = results[index];
          return ListTile(
            leading: CachedNetworkImage(
              imageUrl: item.thumbUrl,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
            title: Text(item.title, style: const TextStyle(color: Colors.white)),
            subtitle: Text(item.category, style: TextStyle(color: item.accent)),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DetailScreen(
                    wallpaper: item,
                    isFavorite: false,
                    onFavorite: () {},
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
