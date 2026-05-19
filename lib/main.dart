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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('My Library'),
        centerTitle: true,
      ),
      body: favoritesList.isEmpty
          ? const Center(
              child: Text(
                'No ROMs saved yet.\nExplore the Home tab and add some!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: favoritesList.length,
              itemBuilder: (context, index) {
                return _buildItemCard(favoritesList[index], index);
              },
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
            GestureDetector(
              onTap: () {
                _selectCategory(_all);
                setState(() => _visibleCount = _allItems.length);
              },
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
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
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: item.thumbUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: const Color(0xFF1E1E1E)),
                errorWidget: (_, _, _) => Container(
                  color: const Color(0xFF1E1E1E),
                  child: const Icon(Icons.videogame_asset_outlined, color: Colors.grey),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                    ),
                  ),
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
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.category.toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(
                          color: item.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
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

class _TrendingRomRow extends StatelessWidget {
  const _TrendingRomRow({required this.item, required this.progress});

  final Wallpaper item;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
                imageUrl: item.thumbUrl,
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
                          item.title,
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
                        '${(progress * 100).round()}%\nCOMPATIBLE',
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFF73DB9A),
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
                    '${item.category.toUpperCase()}  -  ${item.fullUrl.toLowerCase().endsWith('.zip') ? 'ROM' : '8MB'}',
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
                      value: progress,
                      minHeight: 4,
                      backgroundColor: const Color(0xFF353534),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 1
                            ? const Color(0xFF73DB9A)
                            : const Color(0xFFD2BBFF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4A4455)),
              ),
              child: const Icon(
                Icons.download_rounded,
                color: Color(0xFFD2BBFF),
                size: 18,
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
  bool _downloading = false;
  double _progress = 0.0;
  late bool _isFav;

  @override
  void initState() {
    super.initState();
    _isFav = widget.isFavorite;
  }

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _progress = 0.0;
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
              _progress = received / total;
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
          name: widget.wallpaper.id,
          album: 'Retro Hub',
        );
      }

      InterstitialAdService.instance.recordAction();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !isImage ? 'Ready to save/share!' : 'Saved to Gallery! 🎉',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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
      if (mounted) setState(() {
        _downloading = false;
        _progress = 0.0;
      });
    }
  }

  Future<void> _share() async {
    try {
      final isZip = widget.wallpaper.fullUrl.toLowerCase().endsWith('.zip');
      final downloadUrl = widget.wallpaper.fullUrl;
      final temp = await getTemporaryDirectory();
      final ext = isZip ? '.zip' : '.jpg';
      final file = File('${temp.path}/${widget.wallpaper.id}$ext');
      final response = await Dio().download(downloadUrl, file.path);
      if (response.statusCode == 200) {
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Check out this classic game: ${widget.wallpaper.title}');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Share failed.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Hero(
              tag: 'image_${widget.wallpaper.id}',
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: CachedNetworkImage(
                  imageUrl: widget
                      .wallpaper
                      .thumbUrl, // Display thumbnail to avoid crash if fullUrl is a ZIP
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(
                    color: widget.wallpaper.accent.withOpacity(0.1),
                  ),
                  errorWidget: (_, _, _) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                  stops: const [0.0, 0.2, 0.6, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: Colors.black.withOpacity(0.2),
                      child: IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            left: 20,
            right: 20,
            bottom: MediaQuery.paddingOf(context).bottom + 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: widget.wallpaper.accent.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.wallpaper.category.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.wallpaper.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                    letterSpacing: -0.5,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _downloading ? null : _download,
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _downloading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Downloading ${(_progress * 100).toInt()}%',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.download_rounded),
                                  SizedBox(width: 8),
                                  Text(
                                    'Download ROM',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          color: Colors.white.withOpacity(0.1),
                          child: IconButton(
                            padding: const EdgeInsets.all(16),
                            icon: Icon(
                              _isFav ? Icons.favorite : Icons.favorite_border,
                              color: _isFav
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.white,
                            ),
                            onPressed: () {
                              setState(() => _isFav = !_isFav);
                              widget.onFavorite();
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          color: Colors.white.withOpacity(0.1),
                          child: IconButton(
                            padding: const EdgeInsets.all(16),
                            icon: const Icon(
                              Icons.ios_share_rounded,
                              color: Colors.white,
                            ),
                            onPressed: _share,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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

