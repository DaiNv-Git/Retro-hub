import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    // Run Ad initialization asynchronously so it doesn't block app startup
    unawaited(() async {
      try {
        await AdConsentService.instance.prepare();
        if (await ConsentInformation.instance.canRequestAds()) {
          unawaited(MobileAds.instance.initialize());
        }
      } catch (_) {}
    }());
  }
  runApp(const AiWallpaperApp());
}

class AiWallpaperApp extends StatelessWidget {
  const AiWallpaperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, currentTheme, __) {
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
  });

  final String id;
  final String title;
  final String category;
  final String thumbUrl;
  final String fullUrl;
  final Color accent;

  factory Wallpaper.fromJson(Map<String, dynamic> json, int index) {
    final id = '${json['id'] ?? index}';
    final platformStr = '${json['platform'] ?? json['region'] ?? 'Other'}'
        .trim();
    final title = json['title'] as String? ?? 'Wallpaper #$id';

    // Since the original endpoints use these prefixes, we will fallback to them
    const fallbackThumb = 'https://engfordev.top/gbagame/thumbs/';
    final thumb = json['thumbnail'] as String? ?? '$fallbackThumb$id.webp';
    final full = json['download_link'] as String? ?? thumb;

    return Wallpaper(
      id: id,
      title: title,
      category: platformStr.isEmpty ? 'Other' : platformStr,
      thumbUrl: thumb,
      fullUrl: full,
      accent: _accentColors[index % _accentColors.length],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Wallpaper && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

const _dataUrl = 'https://engfordev.top/gbagame/data.json';

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
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
          'Accept': 'application/json',
        },
      ),
    );
    final response = await dio.get<String>(_dataUrl);
    final raw = jsonDecode(response.data ?? '[]') as List<dynamic>;
    return raw
        .whereType<Map<String, dynamic>>()
        .toList()
        .asMap()
        .entries
        .map((entry) => Wallpaper.fromJson(entry.value, entry.key))
        .toList();
  }
}

class AdIds {
  static const banner = 'ca-app-pub-3940256099942544/6300978111';
  static const interstitial = 'ca-app-pub-3940256099942544/1033173712';
}

class AdConsentService {
  AdConsentService._();
  static final instance = AdConsentService._();

  Future<void> prepare() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((error) {
          if (!completer.isCompleted) completer.complete();
        });
      },
      (_) {
        if (!completer.isCompleted) completer.complete();
      },
    );
    await completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {},
    );
  }

  Future<void> showPrivacyOptions() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    await ConsentForm.showPrivacyOptionsForm((_) {});
  }
}

class InterstitialAdService {
  InterstitialAdService._();
  static final instance = InterstitialAdService._();

  InterstitialAd? _ad;
  int _actions = 0;
  DateTime _lastShown = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> load() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    if (!await ConsentInformation.instance.canRequestAds()) return;
    await InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _ad = ad,
        onAdFailedToLoad: (_) => _ad = null,
      ),
    );
  }

  void recordAction() {
    _actions += 1;
    if (_actions >= 3) {
      // Show slightly more frequently for commercial app
      showIfReady();
    }
  }

  void showIfReady() {
    final canShowNow = DateTime.now().difference(_lastShown).inSeconds > 60;
    if (_ad == null || !canShowNow) return;

    final ad = _ad;
    _ad = null;
    _actions = 0;
    _lastShown = DateTime.now();
    ad?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        unawaited(load());
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        unawaited(load());
      },
    );
    ad?.show();
  }
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

  static const _all = 'All Games';
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
    } catch (_) {
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
              toolbarHeight: 64,
              pinned: true,
              elevation: 0,
              backgroundColor: const Color(0xFF131313),
              surfaceTintColor: Colors.transparent,
              titleSpacing: 16,
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x55D2BBFF)),
                    ),
                    child: const Icon(
                      Icons.sports_esports_rounded,
                      color: Color(0xFFD2BBFF),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'RETRO HUB',
                    style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFFD2BBFF),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: () {
                    showSearch(
                      context: context,
                      delegate: GameSearchDelegate(_allItems),
                    );
                  },
                  icon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFFD2BBFF),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: const Color(0xFF4A4455)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRetroHero(featured),
                    const SizedBox(height: 24),
                    _buildCategoryGrid(),
                    const SizedBox(height: 24),
                    _buildTrendingSection(trending),
                    const SizedBox(height: 32),
                    Text(
                      'All Games',
                      style: GoogleFonts.spaceGrotesk(
                        color: const Color(0xFFE5E2E1),
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1,
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
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == _items.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _visibleCount += _batchSize;
                              _applyFilters();
                            });
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD2BBFF),
                            foregroundColor: const Color(0xFF3F008E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Load More',
                            style: TextStyle(fontWeight: FontWeight.w900),
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
                ? const Center(child: Text('No ROMs saved yet.', style: TextStyle(color: Colors.white54)))
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
                  'Connect with other retro gamers. Share high scores, discuss ROM hacks, and stay updated on the latest drops.',
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final Uri url = Uri.parse('https://discord.gg/vSh2kmcR');
                    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not launch Discord link.')),
                        );
                      }
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
          _buildPostCard('RetroGamer99', 'Just beat Chrono Trigger for the 5th time! Still a masterpiece. Any recommendations for similar RPGs?', '2h ago', 12, 4),
          const SizedBox(height: 12),
          _buildPostCard('PokemonMaster', 'Does anyone know how to get the Mystery Gift to work in Crystal version on this emulator?', '5h ago', 4, 1),
          const SizedBox(height: 12),
          _buildPostCard('SpeedRunGuy', 'New personal best on Super Mario Bros 3: 11m 42s! So close to WR!', '1d ago', 45, 8),
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
                  backgroundColor: const Color(0xFF7C3AED).withOpacity(0.3),
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
                      Colors.black.withOpacity(0.05),
                      Colors.black.withOpacity(0.35),
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
                            'PLAY NOW',
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
                title: 'Most\nDownloaded',
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
              'Trending ROMs',
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
    final rand = math.Random(item.id.hashCode);
    final rating = (4.0 + rand.nextDouble() * 0.9).toStringAsFixed(1);
    final fps = rand.nextBool() ? '60 FPS' : '30 FPS';

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
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3A3939)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: item.thumbUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: const Color(0xFF2A2A2A)),
                    errorWidget: (_, _, _) => Container(color: const Color(0xFF2A2A2A)),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF73DB9A)),
                      ),
                      child: Text(
                        item.category.toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFF73DB9A),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          fps,
                          style: GoogleFonts.jetBrainsMono(
                            color: const Color(0xFFCCC3D8),
                            fontSize: 10,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star_outline, color: Color(0xFFF97316), size: 12),
                            const SizedBox(width: 4),
                            Text(
                              rating,
                              style: GoogleFonts.jetBrainsMono(
                                color: const Color(0xFFCCC3D8),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
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
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final downloadUrl = widget.item.fullUrl;
      final lowerUrl = downloadUrl.toLowerCase();
      final isImage = lowerUrl.endsWith('.jpg') || lowerUrl.endsWith('.jpeg') || lowerUrl.endsWith('.png') || lowerUrl.endsWith('.webp');
      
      final ext = downloadUrl.contains('.') ? '.${downloadUrl.split('.').last}' : (isImage ? '.jpg' : '.zip');
      
      final temp = await getTemporaryDirectory();
      final file = File('${temp.path}/${widget.item.id}$ext');

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
        await Gal.putImageBytes(
          bytes,
          name: widget.item.id,
          album: 'Retro Hub',
        );
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
    final displayProgress = _isDownloading ? _downloadProgress : widget.progress;
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
                            : '${(widget.progress * 100).round()}%\nCOMPATIBLE',
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
                    '${widget.item.category.toUpperCase()}  -  ${widget.item.fullUrl.toLowerCase().endsWith('.zip') ? 'ROM' : '8MB'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFFCCC3D8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: displayProgress,
                      minHeight: 4,
                      backgroundColor: const Color(0xFF353534),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        displayProgress >= 1
                            ? const Color(0xFF73DB9A)
                            : progressColor,
                      ),
                    ),
                  ),
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

class _HashTag extends StatelessWidget {
  const _HashTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4A4455)),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          color: color,
          fontSize: 10,
          height: 1.5,
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
                color: const Color(0xFF73DB9A).withOpacity(0.08),
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
          child: Text('No ROMs found.', style: TextStyle(color: Colors.white54)),
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

