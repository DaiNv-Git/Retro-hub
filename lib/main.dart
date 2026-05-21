import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter/webview_flutter.dart' hide X509Certificate;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(
    AdService.instance.loadRemoteConfig().then((_) {
      return AdService.instance.initialize();
    }),
  );
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
      title: 'GBAGame: GBA Homebrew',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0914),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF9D4EDD),
          surface: Color(0xFF151026),
        ),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ==========================================
// ADS
// ==========================================

class AdConfig {
  // Replace these test IDs with your real AdMob IDs before publishing ads.
  static const androidAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const iosAppId = 'ca-app-pub-3940256099942544~1458002511';
  static const androidBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const iosBannerId = 'ca-app-pub-3940256099942544/2934735716';
  static const androidInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const iosInterstitialId = 'ca-app-pub-3940256099942544/4411468910';
  static const androidRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  static const iosRewardedId = 'ca-app-pub-3940256099942544/1712485313';
  static const androidAppOpenId = 'ca-app-pub-3940256099942544/9257395921';
  static const iosAppOpenId = 'ca-app-pub-3940256099942544/5575463023';

  static bool get supportsAds => true;

  static String get bannerId {
    if (Platform.isIOS) return iosBannerId;
    return androidBannerId;
  }

  static String get interstitialId {
    if (Platform.isIOS) return iosInterstitialId;
    return androidInterstitialId;
  }

  static String get rewardedId {
    if (Platform.isIOS) return iosRewardedId;
    return androidRewardedId;
  }

  static String get appOpenId {
    if (Platform.isIOS) return iosAppOpenId;
    return androidAppOpenId;
  }
}

class RemoteAdConfig {
  final bool adsEnabled;
  final bool bannerEnabled;
  final bool inlineBannerEnabled;
  final bool interstitialEnabled;
  final bool rewardedEnabled;
  final bool appOpenEnabled;
  final bool actionInterstitialEnabled;
  final bool discoverActionInterstitialEnabled;
  final bool savedGamePlayInterstitialEnabled;
  final bool importedGamePlayInterstitialEnabled;
  final bool consoleActionInterstitialEnabled;
  final bool downloadCompleteInterstitialEnabled;
  final bool playExitInterstitialEnabled;
  final bool fastDownloadRewardedEnabled;
  final bool featuredPicksRewardedEnabled;
  final bool skinRewardedEnabled;
  final int inlineBannerEvery;
  final int downloadInterstitialCooldownSeconds;
  final int playExitInterstitialCooldownSeconds;
  final int actionInterstitialCooldownSeconds;
  final int appOpenColdStartCooldownMinutes;
  final int appOpenForegroundCooldownMinutes;
  final int appOpenBackgroundThresholdSeconds;
  final int appOpenLaunchThreshold;
  final int featuredUnlockMinutes;

  const RemoteAdConfig({
    required this.adsEnabled,
    required this.bannerEnabled,
    required this.inlineBannerEnabled,
    required this.interstitialEnabled,
    required this.rewardedEnabled,
    required this.appOpenEnabled,
    required this.actionInterstitialEnabled,
    required this.discoverActionInterstitialEnabled,
    required this.savedGamePlayInterstitialEnabled,
    required this.importedGamePlayInterstitialEnabled,
    required this.consoleActionInterstitialEnabled,
    required this.downloadCompleteInterstitialEnabled,
    required this.playExitInterstitialEnabled,
    required this.fastDownloadRewardedEnabled,
    required this.featuredPicksRewardedEnabled,
    required this.skinRewardedEnabled,
    required this.inlineBannerEvery,
    required this.downloadInterstitialCooldownSeconds,
    required this.playExitInterstitialCooldownSeconds,
    required this.actionInterstitialCooldownSeconds,
    required this.appOpenColdStartCooldownMinutes,
    required this.appOpenForegroundCooldownMinutes,
    required this.appOpenBackgroundThresholdSeconds,
    required this.appOpenLaunchThreshold,
    required this.featuredUnlockMinutes,
  });

  static const defaults = RemoteAdConfig(
    adsEnabled: true,
    bannerEnabled: true,
    inlineBannerEnabled: true,
    interstitialEnabled: true,
    rewardedEnabled: true,
    appOpenEnabled: true,
    actionInterstitialEnabled: true,
    discoverActionInterstitialEnabled: true,
    savedGamePlayInterstitialEnabled: true,
    importedGamePlayInterstitialEnabled: true,
    consoleActionInterstitialEnabled: true,
    downloadCompleteInterstitialEnabled: true,
    playExitInterstitialEnabled: true,
    fastDownloadRewardedEnabled: true,
    featuredPicksRewardedEnabled: true,
    skinRewardedEnabled: true,
    inlineBannerEvery: 2,
    downloadInterstitialCooldownSeconds: 45,
    playExitInterstitialCooldownSeconds: 60,
    actionInterstitialCooldownSeconds: 60,
    appOpenColdStartCooldownMinutes: 10,
    appOpenForegroundCooldownMinutes: 5,
    appOpenBackgroundThresholdSeconds: 90,
    appOpenLaunchThreshold: 2,
    featuredUnlockMinutes: 30,
  );

  factory RemoteAdConfig.fromJson(Map<String, dynamic> json) {
    final config = json['config'] is Map<String, dynamic>
        ? json['config'] as Map<String, dynamic>
        : json;
    return RemoteAdConfig(
      adsEnabled: config['adsEnabled'] as bool? ?? defaults.adsEnabled,
      bannerEnabled: config['bannerEnabled'] as bool? ?? defaults.bannerEnabled,
      inlineBannerEnabled:
          config['inlineBannerEnabled'] as bool? ??
          defaults.inlineBannerEnabled,
      interstitialEnabled:
          config['interstitialEnabled'] as bool? ??
          defaults.interstitialEnabled,
      rewardedEnabled:
          config['rewardedEnabled'] as bool? ?? defaults.rewardedEnabled,
      appOpenEnabled:
          config['appOpenEnabled'] as bool? ?? defaults.appOpenEnabled,
      actionInterstitialEnabled:
          config['actionInterstitialEnabled'] as bool? ??
          defaults.actionInterstitialEnabled,
      discoverActionInterstitialEnabled:
          config['discoverActionInterstitialEnabled'] as bool? ??
          defaults.discoverActionInterstitialEnabled,
      savedGamePlayInterstitialEnabled:
          config['savedGamePlayInterstitialEnabled'] as bool? ??
          defaults.savedGamePlayInterstitialEnabled,
      importedGamePlayInterstitialEnabled:
          config['importedGamePlayInterstitialEnabled'] as bool? ??
          defaults.importedGamePlayInterstitialEnabled,
      consoleActionInterstitialEnabled:
          config['consoleActionInterstitialEnabled'] as bool? ??
          defaults.consoleActionInterstitialEnabled,
      downloadCompleteInterstitialEnabled:
          config['downloadCompleteInterstitialEnabled'] as bool? ??
          defaults.downloadCompleteInterstitialEnabled,
      playExitInterstitialEnabled:
          config['playExitInterstitialEnabled'] as bool? ??
          defaults.playExitInterstitialEnabled,
      fastDownloadRewardedEnabled:
          config['fastDownloadRewardedEnabled'] as bool? ??
          defaults.fastDownloadRewardedEnabled,
      featuredPicksRewardedEnabled:
          config['featuredPicksRewardedEnabled'] as bool? ??
          defaults.featuredPicksRewardedEnabled,
      skinRewardedEnabled:
          config['skinRewardedEnabled'] as bool? ??
          defaults.skinRewardedEnabled,
      inlineBannerEvery:
          (config['inlineBannerEvery'] as num?)?.round() ??
          defaults.inlineBannerEvery,
      downloadInterstitialCooldownSeconds:
          (config['downloadInterstitialCooldownSeconds'] as num?)?.round() ??
          defaults.downloadInterstitialCooldownSeconds,
      playExitInterstitialCooldownSeconds:
          (config['playExitInterstitialCooldownSeconds'] as num?)?.round() ??
          defaults.playExitInterstitialCooldownSeconds,
      actionInterstitialCooldownSeconds:
          (config['actionInterstitialCooldownSeconds'] as num?)?.round() ??
          defaults.actionInterstitialCooldownSeconds,
      appOpenColdStartCooldownMinutes:
          (config['appOpenColdStartCooldownMinutes'] as num?)?.round() ??
          defaults.appOpenColdStartCooldownMinutes,
      appOpenForegroundCooldownMinutes:
          (config['appOpenForegroundCooldownMinutes'] as num?)?.round() ??
          defaults.appOpenForegroundCooldownMinutes,
      appOpenBackgroundThresholdSeconds:
          (config['appOpenBackgroundThresholdSeconds'] as num?)?.round() ??
          defaults.appOpenBackgroundThresholdSeconds,
      appOpenLaunchThreshold:
          (config['appOpenLaunchThreshold'] as num?)?.round() ??
          defaults.appOpenLaunchThreshold,
      featuredUnlockMinutes:
          (config['featuredUnlockMinutes'] as num?)?.round() ??
          defaults.featuredUnlockMinutes,
    );
  }
}

class AdService {
  AdService._();

  static final AdService instance = AdService._();

  bool _initialized = false;
  bool _isLoadingInterstitial = false;
  bool _isLoadingRewarded = false;
  bool _isLoadingAppOpen = false;
  bool _isShowingInterstitial = false;
  bool _isShowingRewarded = false;
  bool _isShowingAppOpen = false;
  bool _isGameplayActive = false;
  bool _appOpenListenerStarted = false;
  bool _coldStartAppOpenAllowed = false;
  DateTime? _lastInterstitialShownAt;
  DateTime? _lastAppOpenShownAt;
  DateTime? _lastBackgroundedAt;
  DateTime? _appOpenLoadTime;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  AppOpenAd? _appOpenAd;
  RemoteAdConfig _remoteConfig = RemoteAdConfig.defaults;
  final ValueNotifier<bool> bannerPaused = ValueNotifier<bool>(false);
  final ValueNotifier<int> configVersion = ValueNotifier<int>(0);

  RemoteAdConfig get config => _remoteConfig;
  bool get _adsEnabled => AdConfig.supportsAds && _remoteConfig.adsEnabled;

  Future<void> initialize() async {
    if (_initialized || !_adsEnabled) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      _loadInterstitial();
      _loadRewarded();
      _loadAppOpen();
      _startAppOpenListener();
    } catch (_) {
      // Ads should never block the app from opening.
    }
  }

  Future<void> loadRemoteConfig() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(
        Uri.parse('$_apiBaseUrl/api/app/ad-config'),
      );
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) return;

      final payload = jsonDecode(body) as Map<String, dynamic>;
      _remoteConfig = RemoteAdConfig.fromJson(payload);
      configVersion.value++;
      if (!_adsEnabled) {
        _interstitialAd?.dispose();
        _rewardedAd?.dispose();
        _appOpenAd?.dispose();
        _interstitialAd = null;
        _rewardedAd = null;
        _appOpenAd = null;
        return;
      }

      if (_initialized) {
        _loadInterstitial();
        _loadRewarded();
        _loadAppOpen();
      }
    } catch (_) {
      // Keep bundled defaults when remote config is unavailable.
    }
  }

  void _loadInterstitial() {
    if (!_adsEnabled || !_remoteConfig.interstitialEnabled) return;
    if (!_initialized || _isLoadingInterstitial || _interstitialAd != null) {
      return;
    }

    _isLoadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AdConfig.interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoadingInterstitial = false;
          _interstitialAd = ad;
          _interstitialAd?.fullScreenContentCallback =
              FullScreenContentCallback(
                onAdDismissedFullScreenContent: (ad) {
                  ad.dispose();
                  _isShowingInterstitial = false;
                  _interstitialAd = null;
                  _loadInterstitial();
                },
                onAdFailedToShowFullScreenContent: (ad, error) {
                  ad.dispose();
                  _isShowingInterstitial = false;
                  _interstitialAd = null;
                  _loadInterstitial();
                },
              );
        },
        onAdFailedToLoad: (_) {
          _isLoadingInterstitial = false;
          _interstitialAd = null;
        },
      ),
    );
  }

  void _loadAppOpen() {
    if (!_adsEnabled || !_remoteConfig.appOpenEnabled) return;
    if (!_initialized || _isLoadingAppOpen || _appOpenAd != null) return;

    _isLoadingAppOpen = true;
    AppOpenAd.load(
      adUnitId: AdConfig.appOpenId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoadingAppOpen = false;
          _appOpenLoadTime = DateTime.now();
          _appOpenAd = ad;
        },
        onAdFailedToLoad: (_) {
          _isLoadingAppOpen = false;
          _appOpenAd = null;
          _appOpenLoadTime = null;
        },
      ),
    );
  }

  void _startAppOpenListener() {
    if (_appOpenListenerStarted || !_adsEnabled) return;
    _appOpenListenerStarted = true;
    unawaited(AppStateEventNotifier.startListening());
    AppStateEventNotifier.appStateStream.listen((state) {
      if (state == AppState.background) {
        _lastBackgroundedAt = DateTime.now();
        return;
      }

      final backgroundedAt = _lastBackgroundedAt;
      final awayDuration = backgroundedAt == null
          ? Duration.zero
          : DateTime.now().difference(backgroundedAt);
      if (awayDuration >=
          Duration(seconds: _remoteConfig.appOpenBackgroundThresholdSeconds)) {
        unawaited(
          showAppOpenIfAvailable(
            minInterval: Duration(
              minutes: _remoteConfig.appOpenForegroundCooldownMinutes,
            ),
          ),
        );
      }
    });
  }

  Future<void> prepareAppOpenForLaunch() async {
    if (!_adsEnabled || !_remoteConfig.appOpenEnabled) return;
    if (!_initialized) {
      await initialize();
    }

    final prefs = await SharedPreferences.getInstance();
    final launches = (prefs.getInt('app_open_launch_count') ?? 0) + 1;
    await prefs.setInt('app_open_launch_count', launches);
    _coldStartAppOpenAllowed = launches >= _remoteConfig.appOpenLaunchThreshold;
    _loadAppOpen();
  }

  void _loadRewarded() {
    if (!_adsEnabled || !_remoteConfig.rewardedEnabled) return;
    if (!_initialized || _isLoadingRewarded || _rewardedAd != null) {
      return;
    }

    _isLoadingRewarded = true;
    RewardedAd.load(
      adUnitId: AdConfig.rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoadingRewarded = false;
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (_) {
          _isLoadingRewarded = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  void markDownloadCompleted() {
    if (!_remoteConfig.downloadCompleteInterstitialEnabled) return;
    showInterstitialWhenReady(
      minInterval: Duration(
        seconds: _remoteConfig.downloadInterstitialCooldownSeconds,
      ),
    );
  }

  void preloadInterstitial() {
    if (!_adsEnabled) return;
    if (!_initialized) {
      unawaited(initialize());
      return;
    }
    _loadInterstitial();
    _loadRewarded();
    _loadAppOpen();
  }

  Future<void> showAppOpenIfAvailable({
    Duration minInterval = const Duration(minutes: 10),
    bool coldStart = false,
  }) async {
    if (!_adsEnabled || !_remoteConfig.appOpenEnabled) return;
    if (coldStart && !_coldStartAppOpenAllowed) return;
    if (_isGameplayActive ||
        _isShowingAppOpen ||
        _isShowingInterstitial ||
        _isShowingRewarded) {
      return;
    }
    if (!_initialized) {
      await initialize();
    }

    final lastShownAt = _lastAppOpenShownAt;
    if (lastShownAt != null &&
        DateTime.now().difference(lastShownAt) < minInterval) {
      _loadAppOpen();
      return;
    }

    final loadedAt = _appOpenLoadTime;
    if (loadedAt != null &&
        DateTime.now().difference(loadedAt) > const Duration(hours: 4)) {
      _appOpenAd?.dispose();
      _appOpenAd = null;
      _appOpenLoadTime = null;
      _loadAppOpen();
      return;
    }

    final ad = _appOpenAd;
    if (ad == null) {
      _loadAppOpen();
      return;
    }

    final completer = Completer<void>();
    void finish() {
      if (completer.isCompleted) return;
      _isShowingAppOpen = false;
      resumeBanner();
      _loadAppOpen();
      completer.complete();
    }

    _appOpenAd = null;
    _appOpenLoadTime = null;
    _isShowingAppOpen = true;
    _lastAppOpenShownAt = DateTime.now();
    _lastInterstitialShownAt = DateTime.now();
    await pauseBannerForExternalUi();

    ad.fullScreenContentCallback = FullScreenContentCallback<AppOpenAd>(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        finish();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        finish();
      },
    );

    try {
      await ad.show();
    } catch (_) {
      ad.dispose();
      finish();
    }

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        finish();
      },
    );
  }

  void setGameplayActive(bool isActive) {
    _isGameplayActive = isActive;
  }

  Future<bool> showRewardedAd({
    required BuildContext context,
    String unavailableMessage = 'Rewarded ad is loading. Try again soon.',
  }) async {
    if (!_adsEnabled || !_remoteConfig.rewardedEnabled) return true;
    if (_isShowingRewarded) return false;
    if (!_initialized) {
      await initialize();
    }

    final ad = _rewardedAd;
    if (ad == null) {
      _loadRewarded();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(unavailableMessage),
            backgroundColor: const Color(0xFF9D4EDD),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return false;
    }

    final completer = Completer<bool>();
    var rewardEarned = false;

    void finish(bool value) {
      if (completer.isCompleted) return;
      _isShowingRewarded = false;
      resumeBanner();
      _loadRewarded();
      completer.complete(value);
    }

    _rewardedAd = null;
    _isShowingRewarded = true;
    _lastInterstitialShownAt = DateTime.now();
    await pauseBannerForExternalUi();

    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        finish(rewardEarned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        finish(false);
      },
    );

    try {
      ad.setImmersiveMode(true);
      await ad.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          rewardEarned = true;
        },
      );
    } catch (_) {
      ad.dispose();
      finish(false);
    }

    return completer.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        finish(rewardEarned);
        return rewardEarned;
      },
    );
  }

  void showInterstitialWhenReady({
    Duration minInterval = const Duration(seconds: 15),
  }) {
    if (!_adsEnabled ||
        !_remoteConfig.interstitialEnabled ||
        _isShowingInterstitial) {
      return;
    }
    if (!_initialized) {
      unawaited(initialize());
      return;
    }

    final lastShownAt = _lastInterstitialShownAt;
    if (lastShownAt != null &&
        DateTime.now().difference(lastShownAt) < minInterval) {
      _loadInterstitial();
      return;
    }

    if (_interstitialAd == null) {
      _loadInterstitial();
      return;
    }

    showInterstitialIfReady();
  }

  void showInterstitialIfReady() {
    if (_isShowingInterstitial) return;
    final ad = _interstitialAd;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    _interstitialAd = null;
    _isShowingInterstitial = true;
    _lastInterstitialShownAt = DateTime.now();
    ad.show();
  }

  Future<void> pauseBannerForExternalUi() async {
    bannerPaused.value = true;
    await WidgetsBinding.instance.endOfFrame;
  }

  void resumeBanner() {
    bannerPaused.value = false;
  }

  void showActionInterstitial({bool placementEnabled = true}) {
    if (!_remoteConfig.actionInterstitialEnabled || !placementEnabled) return;
    showInterstitialWhenReady(
      minInterval: Duration(
        seconds: _remoteConfig.actionInterstitialCooldownSeconds,
      ),
    );
  }
}

class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    if (!AdConfig.supportsAds) return;
    _bannerAd = BannerAd(
      adUnitId: AdConfig.bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() => _isLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) {
            setState(() => _isLoaded = false);
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AdService.instance.configVersion,
      builder: (context, version, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: AdService.instance.bannerPaused,
          builder: (context, isPaused, child) {
            final bannerAd = _bannerAd;
            final config = AdService.instance.config;
            if (!config.adsEnabled ||
                !config.bannerEnabled ||
                isPaused ||
                !_isLoaded ||
                bannerAd == null) {
              return const SizedBox.shrink();
            }

            return Container(
              width: double.infinity,
              height: bannerAd.size.height.toDouble(),
              alignment: Alignment.center,
              color: const Color(0xFF0B0914),
              child: SizedBox(
                width: bannerAd.size.width.toDouble(),
                height: bannerAd.size.height.toDouble(),
                child: AdWidget(ad: bannerAd),
              ),
            );
          },
        );
      },
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

class GamepadSkin {
  final String id;
  final String name;
  final Color panel;
  final Color surface;
  final Color pressedSurface;
  final Color border;
  final Color accent;
  final Color text;

  const GamepadSkin({
    required this.id,
    required this.name,
    required this.panel,
    required this.surface,
    required this.pressedSurface,
    required this.border,
    required this.accent,
    required this.text,
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

const List<GamepadSkin> availableGamepadSkins = [
  GamepadSkin(
    id: 'neon',
    name: 'Neon',
    panel: Color(0xFF241331),
    surface: Color(0xFF34234A),
    pressedSurface: Color(0xFF6941A2),
    border: Color(0xFFB977FF),
    accent: Color(0xFFC77DFF),
    text: Colors.white,
  ),
  GamepadSkin(
    id: 'mint',
    name: 'Mint',
    panel: Color(0xFF122821),
    surface: Color(0xFF1D3A31),
    pressedSurface: Color(0xFF2F8F6F),
    border: Color(0xFF73DB9A),
    accent: Color(0xFF73DB9A),
    text: Colors.white,
  ),
  GamepadSkin(
    id: 'amber',
    name: 'Amber',
    panel: Color(0xFF302312),
    surface: Color(0xFF44321A),
    pressedSurface: Color(0xFFB5761F),
    border: Color(0xFFFFCF5A),
    accent: Color(0xFFFFCF5A),
    text: Colors.white,
  ),
  GamepadSkin(
    id: 'arcade',
    name: 'Arcade',
    panel: Color(0xFF111B2A),
    surface: Color(0xFF1D2B40),
    pressedSurface: Color(0xFF215D92),
    border: Color(0xFF5FA8D3),
    accent: Color(0xFF5FA8D3),
    text: Colors.white,
  ),
];

class HomebrewGame {
  final String title;
  final String developer;
  final String description;
  final String coverUrl;
  final String downloadUrl;
  final String fileName;
  final String officialPageUrl;
  final String category;
  final String fileSize;
  final double rating;

  const HomebrewGame({
    required this.title,
    required this.developer,
    required this.description,
    required this.coverUrl,
    required this.downloadUrl,
    required this.fileName,
    required this.officialPageUrl,
    required this.category,
    required this.fileSize,
    required this.rating,
  });

  factory HomebrewGame.fromApiJson(Map<String, dynamic> json) {
    final title = _decodeHtml(json['title'] as String? ?? 'GBA Game');
    final platform = _decodeHtml(
      json['platform'] as String? ?? 'Game Boy Advance',
    );
    final region = _decodeHtml(json['region'] as String? ?? 'Unknown region');
    final version = _decodeHtml(json['version'] as String? ?? '1.0');
    final downloadUrl = json['downloadUrl'] as String? ?? '';
    final fileName =
        json['fileName'] as String? ??
        Uri.tryParse(downloadUrl)?.pathSegments.last ??
        '';

    return HomebrewGame(
      title: title,
      developer: '$region • v$version',
      description: '$platform game available from the GBA Game Top library.',
      coverUrl: json['thumbnail'] as String? ?? '',
      downloadUrl: downloadUrl,
      fileName: fileName,
      officialPageUrl: json['sourceUrl'] as String? ?? downloadUrl,
      category: platform.replaceFirst('Game Boy Advance', 'GBA'),
      fileSize: fileName.toLowerCase().endsWith('.zip') ? 'ZIP ROM' : 'ROM',
      rating: 4.8,
    );
  }

  bool get hasDirectDownload => downloadUrl.isNotEmpty;
  bool get isZipDownload => fileName.toLowerCase().endsWith('.zip');
  String get playableFileName {
    if (!isZipDownload) return fileName;
    final safeTitle = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return '$safeTitle.gba';
  }
}

class ImportedGame {
  final String id;
  final String title;
  final String path;
  final String fileName;
  final int fileSize;
  final String importedAt;

  const ImportedGame({
    required this.id,
    required this.title,
    required this.path,
    required this.fileName,
    required this.fileSize,
    required this.importedAt,
  });

  factory ImportedGame.fromJson(Map<String, dynamic> json) {
    return ImportedGame(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Imported game',
      path: json['path'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      fileSize: json['fileSize'] as int? ?? 0,
      importedAt: json['importedAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'path': path,
      'fileName': fileName,
      'fileSize': fileSize,
      'importedAt': importedAt,
    };
  }
}

class ImportGameOptions {
  final String title;
  final bool saveToLibrary;

  const ImportGameOptions({required this.title, required this.saveToLibrary});
}

const String _importedGamesPrefsKey = 'imported_games';
const String _remoteGamesPrefsKey = 'remote_homebrew_games_v1';
const String _downloadedGamesFilter = 'Downloaded';
const String _apiBaseUrl = 'https://gbagametop.shop';

String _decodeHtml(String value) {
  return value
      .replaceAll('&#8211;', '-')
      .replaceAll('&#8217;', "'")
      .replaceAll('&#038;', '&')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
}

String _cleanGameTitle(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  final rawTitle = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
  final spaced = rawTitle.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
  if (spaced.isEmpty) return 'Imported game';
  return spaced
      .split(RegExp(r'\s+'))
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.length > 1 ? word.substring(1) : ''}',
      )
      .join(' ');
}

String _safeFileName(String fileName) {
  final fallback = 'imported_game.gba';
  final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  return safe.isEmpty ? fallback : safe;
}

String _formatFileSize(int bytes) {
  if (bytes <= 0) return 'Unknown size';
  const kb = 1024;
  const mb = kb * 1024;
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
  return '$bytes B';
}

// Fallback games used only when the remote API cannot be reached.
final List<HomebrewGame> fallbackGames = [
  const HomebrewGame(
    title: 'Anguna: Warriors of Virtue',
    developer: 'Bite the Chili Productions',
    description:
        'A top-down fantasy action-RPG featuring multiple dungeons, hidden items, and boss fights. Completely free and open-source.',
    coverUrl: 'https://www.tolberts.net/anguna/shot1.png',
    downloadUrl: 'https://www.tolberts.net/anguna/anguna.zip',
    fileName: 'anguna.zip',
    officialPageUrl: 'https://www.tolberts.net/anguna/',
    category: 'Adventure',
    fileSize: '714 KB',
    rating: 4.8,
  ),
  const HomebrewGame(
    title: 'Apotris',
    developer: 'akouzoukos',
    description:
        'A highly polished block puzzle game designed specifically for the GBA. Fast-paced and fully featured.',
    coverUrl: 'https://akouzoukos.com/preview.gif',
    downloadUrl:
        'https://apotrisstorage.blob.core.windows.net/binaries/Apotris-v4.1.0GBA.zip',
    fileName: 'Apotris-v4.1.0GBA.zip',
    officialPageUrl: 'https://akouzoukos.com/apotris/downloads',
    category: 'Puzzle',
    fileSize: '13.8 MB',
    rating: 4.9,
  ),
  const HomebrewGame(
    title: 'Celeste Classic GBA',
    developer: 'JeffRuLz',
    description:
        'A faithful port of the original Pico-8 Celeste mountain climbing game to the Game Boy Advance.',
    coverUrl:
        'https://raw.githubusercontent.com/JeffRuLz/Celeste-Classic-GBA/master/screen1.png',
    downloadUrl:
        'https://github.com/JeffRuLz/Celeste-Classic-GBA/releases/download/v1.2/Celeste.Classic.v1.2.Homebrew.gba',
    fileName: 'Celeste.Classic.v1.2.Homebrew.gba',
    officialPageUrl: 'https://github.com/JeffRuLz/Celeste-Classic-GBA',
    category: 'Platformer',
    fileSize: '5.3 MB',
    rating: 4.9,
  ),
  const HomebrewGame(
    title: 'Goodboy Galaxy Demo',
    developer: 'Goodboy Galaxy / exelotl',
    description:
        'The official free Chapter Zero demo for Game Boy Advance, published by the developers.',
    coverUrl: 'https://www.goodboygalaxy.com/screenshots2/ss0_en.png',
    downloadUrl: '',
    fileName: '',
    officialPageUrl: 'https://goodboygalaxy.itch.io/goodboy-galaxy-demo',
    category: 'Platformer',
    fileSize: 'Free demo',
    rating: 4.8,
  ),
];

// Global state for theme selection
EmulatorTheme _globalSelectedTheme = availableThemes.first;
GamepadSkin _globalSelectedGamepadSkin = availableGamepadSkins.first;

Route<void> _buildEmulatorRoute(String romPath, {String? coverUrl}) {
  return PageRouteBuilder<void>(
    settings: const RouteSettings(name: '/emulator'),
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) => EmulatorScreen(
      romPath: romPath,
      theme: _globalSelectedTheme,
      coverUrl: coverUrl,
    ),
  );
}

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
  int _importedGamesVersion = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HomebrewLibraryScreen(),
      ImportedGamesScreen(key: ValueKey(_importedGamesVersion)),
      ConsoleConfigScreen(
        onGameImported: () {
          setState(() {
            _importedGamesVersion++;
          });
        },
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AdBanner(),
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  if (index == 1) {
                    _importedGamesVersion++;
                  }
                  _currentIndex = index;
                });
              },
              backgroundColor: const Color(0xFF0B0914),
              selectedItemColor: const Color(0xFF9D4EDD),
              unselectedItemColor: Colors.white38,
              selectedLabelStyle: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              unselectedLabelStyle: GoogleFonts.outfit(
                fontWeight: FontWeight.normal,
                fontSize: 12,
              ),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.grid_view_rounded),
                  label: 'Discover',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.save_rounded),
                  label: 'Saved',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_input_component_rounded),
                  label: 'My Console',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// LIBRARY SCREEN (TAB 0)
// ==========================================

class HomebrewLibraryScreen extends StatefulWidget {
  const HomebrewLibraryScreen({super.key});

  @override
  State<HomebrewLibraryScreen> createState() => _HomebrewLibraryScreenState();
}

class _HomebrewLibraryScreenState extends State<HomebrewLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  List<HomebrewGame> _games = fallbackGames;
  final Map<String, double> _downloadProgress = {};
  final Set<String> _downloadedGames = {};
  final Set<String> _boostedDownloads = {};
  bool _isLoadingSaved = true;
  bool _isLoadingGames = true;
  bool _fastDownloadInProgress = false;
  bool _featuredUnlockInProgress = false;
  DateTime? _featuredUnlockedUntil;
  String? _gamesError;
  RemoteAdConfig get _adConfig => AdService.instance.config;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _loadFeaturedUnlock();
    await _loadCachedRemoteGames();
    await _loadDownloadedGames();
    unawaited(_loadRemoteGames());
  }

  bool get _hasFeaturedUnlock {
    final unlockedUntil = _featuredUnlockedUntil;
    return unlockedUntil != null && DateTime.now().isBefore(unlockedUntil);
  }

  Future<void> _loadFeaturedUnlock() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMillis = prefs.getInt('featured_picks_unlocked_until');
    if (savedMillis == null) return;

    final unlockedUntil = DateTime.fromMillisecondsSinceEpoch(savedMillis);
    if (DateTime.now().isAfter(unlockedUntil)) {
      await prefs.remove('featured_picks_unlocked_until');
      return;
    }

    _featuredUnlockedUntil = unlockedUntil;
  }

  Future<void> _loadCachedRemoteGames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedPayload = prefs.getString(_remoteGamesPrefsKey);
      if (cachedPayload == null || cachedPayload.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoadingGames = false;
        });
        return;
      }

      final rawItems = jsonDecode(cachedPayload) as List<dynamic>;
      final cachedGames = rawItems
          .whereType<Map<String, dynamic>>()
          .map(HomebrewGame.fromApiJson)
          .toList();
      if (cachedGames.isEmpty) return;

      if (!mounted) return;
      setState(() {
        _games = cachedGames;
        _gamesError = null;
        _isLoadingGames = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingGames = false;
      });
    }
  }

  Future<void> _loadRemoteGames() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(
        Uri.parse('$_apiBaseUrl/api/app/home'),
      );
      request.headers.set(HttpHeaders.cacheControlHeader, 'max-age=300');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception('Server returned code ${response.statusCode}');
      }

      final payload = jsonDecode(body) as Map<String, dynamic>;
      final rawItems = <dynamic>[
        ...((payload['featured'] as List<dynamic>?) ?? const []),
        ...((payload['games'] as List<dynamic>?) ?? const []),
      ];
      final seenTitles = <String>{};
      final remoteGames = rawItems
          .whereType<Map<String, dynamic>>()
          .map(HomebrewGame.fromApiJson)
          .where((game) => seenTitles.add(game.title))
          .toList();

      if (remoteGames.isEmpty) {
        throw Exception('No games returned from API');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_remoteGamesPrefsKey, jsonEncode(rawItems));

      if (!mounted) return;
      setState(() {
        _games = remoteGames;
        _gamesError = null;
        _isLoadingGames = false;
      });
    } catch (e) {
      if (!mounted) return;
      final hasVisibleGames = _games.isNotEmpty;
      setState(() {
        if (!hasVisibleGames) {
          _games = fallbackGames;
        }
        _gamesError = hasVisibleGames ? null : 'Using offline game list';
        _isLoadingGames = false;
      });
    }
  }

  Future<void> _loadDownloadedGames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedList = prefs.getStringList('downloaded_roms') ?? [];
      final docDir = await getApplicationDocumentsDirectory();

      // Verify files actually exist on disk
      final Set<String> verifiedList = {};
      for (final title in savedList) {
        final game = _games.firstWhere(
          (g) => g.title == title,
          orElse: () => const HomebrewGame(
            title: '',
            developer: '',
            description: '',
            coverUrl: '',
            downloadUrl: '',
            fileName: '',
            officialPageUrl: '',
            category: '',
            fileSize: '',
            rating: 0,
          ),
        );
        if (game.title.isNotEmpty && game.fileName.isNotEmpty) {
          final localPath = '${docDir.path}/${game.playableFileName}';
          if (await File(localPath).exists()) {
            verifiedList.add(title);
          }
        }
      }

      // Save back verified list to prefs
      await prefs.setStringList('downloaded_roms', verifiedList.toList());

      if (!mounted) return;
      setState(() {
        _downloadedGames.addAll(verifiedList);
        _isLoadingSaved = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingSaved = false;
      });
    }
  }

  HomebrewGame? _bestFastDownloadTarget() {
    final candidates =
        _games
            .where(
              (game) =>
                  game.hasDirectDownload &&
                  !_downloadedGames.contains(game.title) &&
                  !_downloadProgress.containsKey(game.title),
            )
            .toList()
          ..sort((a, b) => b.rating.compareTo(a.rating));

    if (candidates.isEmpty) return null;
    if (_selectedCategory == 'All' ||
        _selectedCategory == _downloadedGamesFilter) {
      return candidates.first;
    }
    return candidates.firstWhere(
      (game) => game.category == _selectedCategory,
      orElse: () => candidates.first,
    );
  }

  Future<void> _startBestBoostedDownload() async {
    final game = _bestFastDownloadTarget();
    if (game == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No downloadable games available now.')),
      );
      return;
    }
    await _startBoostedDownload(game);
  }

  Future<void> _startBoostedDownload(HomebrewGame game) async {
    if (_fastDownloadInProgress || _downloadProgress.containsKey(game.title)) {
      return;
    }
    if (_downloadedGames.contains(game.title) || !game.hasDirectDownload) {
      await _downloadAndPlay(game);
      return;
    }

    setState(() => _fastDownloadInProgress = true);
    try {
      final earned = _adConfig.fastDownloadRewardedEnabled
          ? await AdService.instance.showRewardedAd(
              context: context,
              unavailableMessage:
                  'Fast download ad is loading. Try again soon.',
            )
          : true;
      if (!mounted || !earned) return;

      setState(() {
        _boostedDownloads.add(game.title);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fast download unlocked for "${game.title}".'),
          backgroundColor: const Color(0xFFFFCF5A),
          duration: const Duration(seconds: 2),
        ),
      );
      await _downloadAndPlay(game, boosted: true);
    } finally {
      if (mounted) {
        setState(() => _fastDownloadInProgress = false);
      }
    }
  }

  List<HomebrewGame> _featuredSuggestions() {
    final candidates =
        _games
            .where(
              (game) =>
                  game.hasDirectDownload &&
                  !_downloadedGames.contains(game.title) &&
                  !_downloadProgress.containsKey(game.title),
            )
            .toList()
          ..sort((a, b) => b.rating.compareTo(a.rating));

    if (_selectedCategory == 'All' ||
        _selectedCategory == _downloadedGamesFilter) {
      return candidates.take(4).toList();
    }

    final categoryMatches = candidates
        .where((game) => game.category == _selectedCategory)
        .toList();
    final otherMatches = candidates
        .where((game) => game.category != _selectedCategory)
        .toList();
    return [...categoryMatches, ...otherMatches].take(4).toList();
  }

  Future<void> _showRewardedFeaturedSuggestions() async {
    if (_featuredUnlockInProgress) return;
    setState(() => _featuredUnlockInProgress = true);

    try {
      if (!_hasFeaturedUnlock) {
        final earned = _adConfig.featuredPicksRewardedEnabled
            ? await AdService.instance.showRewardedAd(
                context: context,
                unavailableMessage:
                    'Featured picks ad is loading. Try again soon.',
              )
            : true;
        if (!mounted || !earned) return;

        final unlockedUntil = DateTime.now().add(
          Duration(minutes: AdService.instance.config.featuredUnlockMinutes),
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          'featured_picks_unlocked_until',
          unlockedUntil.millisecondsSinceEpoch,
        );
        if (!mounted) return;
        setState(() {
          _featuredUnlockedUntil = unlockedUntil;
        });
      }

      final suggestions = _featuredSuggestions();
      if (suggestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No featured suggestions available now.'),
          ),
        );
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (sheetContext) {
          return _buildFeaturedSuggestionSheet(sheetContext, suggestions);
        },
      );
    } finally {
      if (mounted) {
        setState(() => _featuredUnlockInProgress = false);
      }
    }
  }

  Future<void> _downloadAndPlay(
    HomebrewGame game, {
    bool boosted = false,
  }) async {
    if (!game.hasDirectDownload) {
      await _openOfficialPage(game);
      return;
    }

    final title = game.title;
    final docDir = await getApplicationDocumentsDirectory();
    final localPath = '${docDir.path}/${game.playableFileName}';

    if (_downloadedGames.contains(title)) {
      if (await File(localPath).exists()) {
        // Direct play
        await _playGame(localPath, coverUrl: game.coverUrl);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final savedList = prefs.getStringList('downloaded_roms') ?? [];
      savedList.remove(title);
      await prefs.setStringList('downloaded_roms', savedList);
      if (!mounted) return;
      setState(() {
        _downloadedGames.remove(title);
      });
    }

    if (_downloadProgress.containsKey(title)) return; // Already downloading

    if (!mounted) return;
    setState(() {
      _downloadProgress[title] = 0.0;
      if (boosted) {
        _boostedDownloads.add(title);
      }
    });

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(game.downloadUrl));
      final response = await request.close();

      if (response.statusCode == 200) {
        final file = File(localPath);
        final total = response.contentLength;
        int received = 0;

        void updateProgress(List<int> chunk) {
          received += chunk.length;
          if (!mounted) return;
          setState(() {
            _downloadProgress[title] = total > 0 ? (received / total) : 0.5;
          });
        }

        if (boosted && !game.isZipDownload) {
          final sink = file.openWrite();
          try {
            await for (final chunk in response) {
              sink.add(chunk);
              updateProgress(chunk);
            }
          } finally {
            await sink.close();
          }
        } else {
          final bytes = <int>[];
          await for (final chunk in response) {
            bytes.addAll(chunk);
            updateProgress(chunk);
          }

          if (game.isZipDownload) {
            final gbaBytes = _extractGbaFromZip(bytes);
            await file.writeAsBytes(gbaBytes);
          } else {
            await file.writeAsBytes(bytes);
          }
        }

        final prefs = await SharedPreferences.getInstance();
        final savedList = prefs.getStringList('downloaded_roms') ?? [];
        if (!savedList.contains(title)) {
          savedList.add(title);
          await prefs.setStringList('downloaded_roms', savedList);
        }

        if (!mounted) return;
        setState(() {
          _downloadProgress.remove(title);
          _downloadedGames.add(title);
          _boostedDownloads.remove(title);
        });
        AdService.instance.markDownloadCompleted();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${game.title}" downloaded and added to console!'),
            backgroundColor: const Color(0xFF73DB9A),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Server returned code ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadProgress.remove(title);
          _boostedDownloads.remove(title);
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: const Color(0xFFFF5252),
        ),
      );
    }
  }

  List<int> _extractGbaFromZip(List<int> zipBytes) {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final gbaFile = archive.files.cast<ArchiveFile?>().firstWhere(
      (file) =>
          file != null &&
          file.isFile &&
          file.name.toLowerCase().endsWith('.gba'),
      orElse: () => null,
    );

    if (gbaFile == null) {
      throw Exception('No .gba file found in downloaded ZIP');
    }

    return gbaFile.readBytes()!;
  }

  Future<void> _playGame(String romPath, {String? coverUrl}) async {
    AdService.instance.showActionInterstitial(
      placementEnabled: _adConfig.discoverActionInterstitialEnabled,
    );
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push(_buildEmulatorRoute(romPath, coverUrl: coverUrl));
    if (_adConfig.playExitInterstitialEnabled) {
      AdService.instance.showInterstitialWhenReady(
        minInterval: Duration(
          seconds: _adConfig.playExitInterstitialCooldownSeconds,
        ),
      );
    }
  }

  Future<void> _openOfficialPage(HomebrewGame game) async {
    final url = Uri.parse(game.officialPageUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open official page for ${game.title}'),
          backgroundColor: const Color(0xFFFF5252),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Categories List
    final List<String> categories = [
      'All',
      _downloadedGamesFilter,
      ..._games.map((game) => game.category).toSet(),
    ];
    final isDownloadedTab = _selectedCategory == _downloadedGamesFilter;

    // Filter games
    final filteredGames = _games.where((game) {
      final matchesSearch =
          game.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          game.developer.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          game.description.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == 'All' ||
          (isDownloadedTab && _downloadedGames.contains(game.title)) ||
          game.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    // Featured game: Celeste or Anguna (first one that matches selected category, or default first)
    final hasSearch = _searchQuery.trim().isNotEmpty;
    final HomebrewGame? featuredGame =
        !hasSearch && !isDownloadedTab && filteredGames.isNotEmpty
        ? filteredGames.first
        : null;
    final remainingGames = featuredGame == null
        ? filteredGames
        : filteredGames.skip(1).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0914),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GBAGAME',
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'GBA Homebrew Emulator',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: const Color(0xFF73DB9A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Animated Console Icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9D4EDD).withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF9D4EDD).withOpacity(0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.sports_esports_rounded,
                      color: Color(0xFF9D4EDD),
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Glassmorphic Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white38,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              color: Colors.white60,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    hintText: 'Search homebrew games...',
                    hintStyle: GoogleFonts.outfit(
                      color: Colors.white38,
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Category filters
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = cat == _selectedCategory;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF9D4EDD)
                              : Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFC77DFF)
                                : Colors.white.withOpacity(0.08),
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF9D4EDD,
                                    ).withOpacity(0.3),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          cat,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              if (!isDownloadedTab) ...[
                _buildRewardedActionRow(),
                const SizedBox(height: 20),
              ] else
                const SizedBox(height: 8),

              // Game lists
              Expanded(
                child: _isLoadingSaved || _isLoadingGames
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF9D4EDD),
                        ),
                      )
                    : filteredGames.isEmpty
                    ? _buildEmptyState(
                        isDownloadedTab
                            ? 'No downloaded games yet'
                            : 'No games found',
                        isDownloadedTab
                            ? 'Download a game from Discover to see it here.'
                            : 'Try adjusting your search query or filters',
                      )
                    : ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          if (_gamesError != null) ...[
                            _buildWarningBanner(_gamesError!),
                            const SizedBox(height: 16),
                          ],
                          // Featured Game section
                          if (featuredGame != null) ...[
                            _buildFeaturedCard(featuredGame),
                            const SizedBox(height: 24),
                            Text(
                              'MORE GAMES',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white38,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Remaining list
                          ..._buildGameFeed(remainingGames),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRewardedActionRow() {
    return Row(
      children: [
        Expanded(
          child: _buildRewardedShortcutButton(
            label: 'Fast Download',
            icon: _fastDownloadInProgress
                ? Icons.hourglass_top_rounded
                : Icons.bolt_rounded,
            color: const Color(0xFFFFCF5A),
            onTap: _fastDownloadInProgress ? null : _startBestBoostedDownload,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildRewardedShortcutButton(
            label: _hasFeaturedUnlock ? 'Picks Unlocked' : 'Featured Picks',
            icon: _featuredUnlockInProgress
                ? Icons.hourglass_top_rounded
                : Icons.auto_awesome_rounded,
            color: const Color(0xFF73DB9A),
            onTap: _featuredUnlockInProgress
                ? null
                : _showRewardedFeaturedSuggestions,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildGameFeed(List<HomebrewGame> games) {
    final widgets = <Widget>[];
    final adConfig = AdService.instance.config;
    final inlineBannerEvery =
        adConfig.adsEnabled &&
            adConfig.bannerEnabled &&
            adConfig.inlineBannerEnabled
        ? adConfig.inlineBannerEvery
        : 0;
    for (var index = 0; index < games.length; index++) {
      widgets.add(_buildGameListCard(games[index]));
      final shouldInsertAd =
          inlineBannerEvery > 0 &&
          (index + 1) % inlineBannerEvery == 0 &&
          index != games.length - 1;
      if (shouldInsertAd) {
        widgets
          ..add(_buildInlineAdSlot())
          ..add(const SizedBox(height: 16));
      }
    }
    return widgets;
  }

  Widget _buildInlineAdSlot() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: const AdBanner(),
    );
  }

  Widget _buildRewardedShortcutButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: onTap == null ? 0.62 : 1,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedSuggestionSheet(
    BuildContext sheetContext,
    List<HomebrewGame> suggestions,
  ) {
    final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.72;
    final maxUnlockMinutes = AdService.instance.config.featuredUnlockMinutes;
    final unlockMinutes = _featuredUnlockedUntil
        ?.difference(DateTime.now())
        .inMinutes
        .clamp(1, maxUnlockMinutes);
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF151026),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFF73DB9A),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Featured Picks',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white60,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (unlockMinutes != null) ...[
                  Text(
                    'Unlocked for $unlockMinutes min',
                    style: GoogleFonts.jetBrainsMono(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: suggestions.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _buildFeaturedSuggestionTile(
                        sheetContext,
                        suggestions[index],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedSuggestionTile(
    BuildContext sheetContext,
    HomebrewGame game,
  ) {
    final isDownloading = _downloadProgress.containsKey(game.title);
    final progress = _downloadProgress[game.title] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 54,
              height: 54,
              child: CachedNetworkImage(
                imageUrl: game.coverUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: const Color(0xFF0B0914)),
                errorWidget: (context, url, error) => Container(
                  color: const Color(0xFF0B0914),
                  child: const Icon(
                    Icons.sports_esports_rounded,
                    color: Colors.white38,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${game.category} • ${game.fileSize} • ${game.rating}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: isDownloading
                ? null
                : () {
                    Navigator.of(sheetContext).pop();
                    AdService.instance.showActionInterstitial(
                      placementEnabled:
                          _adConfig.discoverActionInterstitialEnabled,
                    );
                    unawaited(
                      _downloadAndPlay(game, boosted: _hasFeaturedUnlock),
                    );
                  },
            icon: Icon(
              isDownloading
                  ? Icons.downloading_rounded
                  : Icons.cloud_download_rounded,
              size: 16,
            ),
            label: Text(isDownloading ? '${(progress * 100).toInt()}%' : 'Get'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF73DB9A),
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.white12,
              disabledForegroundColor: Colors.white54,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              textStyle: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFCF5A).withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCF5A).withOpacity(0.24)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFFFCF5A),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.outfit(
                color: const Color(0xFFFFCF5A),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.sports_esports_outlined,
            color: Colors.white24,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.outfit(fontSize: 14, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCard(HomebrewGame game) {
    final title = game.title;
    final isDownloaded = _downloadedGames.contains(title);
    final isDownloading = _downloadProgress.containsKey(title);
    final progress = _downloadProgress[title] ?? 0.0;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9D4EDD).withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background cover image
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: game.coverUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: const Color(0xFF1E1E1E)),
              errorWidget: (_, __, ___) =>
                  Container(color: const Color(0xFF1E1E1E)),
            ),
          ),
          // Dark Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.85),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          // Featured Tag
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF9D4EDD),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9D4EDD).withOpacity(0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                'FEATURED',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // Content
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            game.category,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: const Color(0xFF73DB9A),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '•',
                            style: TextStyle(color: Colors.white38),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            game.fileSize,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '•',
                            style: TextStyle(color: Colors.white38),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 14,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            game.rating.toString(),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Direct play or download
                _buildActionButton(
                  game,
                  isDownloaded,
                  isDownloading,
                  progress,
                  isFeatured: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameListCard(HomebrewGame game) {
    final title = game.title;
    final isDownloaded = _downloadedGames.contains(title);
    final isDownloading = _downloadProgress.containsKey(title);
    final progress = _downloadProgress[title] ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover Image
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.white.withOpacity(0.04)),
                ),
              ),
              child: CachedNetworkImage(
                imageUrl: game.coverUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: const Color(0xFF1E1E1E)),
                errorWidget: (_, __, ___) =>
                    Container(color: const Color(0xFF1E1E1E)),
              ),
            ),

            // Text info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'By ${game.developer}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFF9D4EDD),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      game.description,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.white54,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    const SizedBox(height: 8),
                    // Metadata & Action row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF73DB9A,
                                    ).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    game.category.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF73DB9A),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  game.fileSize,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: Colors.white38,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Download/Play button
                        _buildActionButton(
                          game,
                          isDownloaded,
                          isDownloading,
                          progress,
                          isFeatured: false,
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

  Widget _buildActionButton(
    HomebrewGame game,
    bool isDownloaded,
    bool isDownloading,
    double progress, {
    required bool isFeatured,
  }) {
    final isBoosted = _boostedDownloads.contains(game.title);
    if (isDownloading) {
      return Container(
        width: isFeatured ? 80 : 70,
        height: 36,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 2,
                color: isBoosted
                    ? const Color(0xFFFFCF5A)
                    : (isFeatured ? Colors.white : const Color(0xFF9D4EDD)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress * 100).toInt()}%',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                color: isBoosted
                    ? const Color(0xFFFFCF5A)
                    : (isFeatured ? Colors.white70 : const Color(0xFF9D4EDD)),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final bool opensOfficialPage = !game.hasDirectDownload && !isDownloaded;
    final Color buttonColor = isDownloaded
        ? const Color(0xFF73DB9A)
        : (isFeatured ? Colors.white : const Color(0xFF9D4EDD));
    final Color textColor = isDownloaded
        ? Colors.black
        : (isFeatured ? Colors.black : Colors.white);
    final String label = isDownloaded
        ? 'PLAY'
        : (opensOfficialPage ? 'OPEN' : 'GET');
    final IconData icon = isDownloaded
        ? Icons.play_arrow_rounded
        : (opensOfficialPage
              ? Icons.open_in_new_rounded
              : Icons.cloud_download_rounded);

    final primaryButton = GestureDetector(
      onTap: () {
        AdService.instance.showActionInterstitial(
          placementEnabled: _adConfig.discoverActionInterstitialEnabled,
        );
        unawaited(_downloadAndPlay(game));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isFeatured ? 16 : 12,
          vertical: isFeatured ? 8 : 6,
        ),
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isFeatured
              ? [
                  BoxShadow(
                    color: buttonColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor, size: isFeatured ? 16 : 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: isFeatured ? 13 : 11,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );

    final canBoost = game.hasDirectDownload && !isDownloaded;
    if (!canBoost) return primaryButton;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        primaryButton,
        SizedBox(width: isFeatured ? 8 : 6),
        _buildBoostDownloadButton(game, isFeatured: isFeatured),
      ],
    );
  }

  Widget _buildBoostDownloadButton(
    HomebrewGame game, {
    required bool isFeatured,
  }) {
    final isBusy =
        _fastDownloadInProgress || _downloadProgress.containsKey(game.title);
    return Tooltip(
      message: 'Watch ad for fast download',
      child: GestureDetector(
        onTap: isBusy ? null : () => _startBoostedDownload(game),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: isBusy ? 0.55 : 1,
          child: Container(
            width: isFeatured ? 38 : 34,
            height: isFeatured ? 38 : 34,
            decoration: BoxDecoration(
              color: const Color(0xFFFFCF5A),
              shape: BoxShape.circle,
              boxShadow: isFeatured
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFFCF5A).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              isBusy ? Icons.hourglass_top_rounded : Icons.bolt_rounded,
              color: Colors.black,
              size: isFeatured ? 19 : 17,
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// IMPORTED GAMES SCREEN (TAB 1)
// ==========================================

class ImportedGamesScreen extends StatefulWidget {
  const ImportedGamesScreen({super.key});

  @override
  State<ImportedGamesScreen> createState() => _ImportedGamesScreenState();
}

class _ImportedGamesScreenState extends State<ImportedGamesScreen> {
  List<ImportedGame> _games = [];
  bool _isLoading = true;
  RemoteAdConfig get _adConfig => AdService.instance.config;

  @override
  void initState() {
    super.initState();
    _loadImportedGames();
  }

  Future<void> _loadImportedGames() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_importedGamesPrefsKey) ?? [];
    final verifiedGames = <ImportedGame>[];

    for (final item in saved) {
      try {
        final game = ImportedGame.fromJson(
          jsonDecode(item) as Map<String, dynamic>,
        );
        if (game.path.isNotEmpty && await File(game.path).exists()) {
          verifiedGames.add(game);
        }
      } catch (_) {
        // Skip stale entries from older builds or interrupted writes.
      }
    }

    if (verifiedGames.length != saved.length) {
      await prefs.setStringList(
        _importedGamesPrefsKey,
        verifiedGames.map((game) => jsonEncode(game.toJson())).toList(),
      );
    }

    if (!mounted) return;
    setState(() {
      _games = verifiedGames;
      _isLoading = false;
    });
  }

  Future<void> _playGame(ImportedGame game) async {
    AdService.instance.showActionInterstitial(
      placementEnabled: _adConfig.savedGamePlayInterstitialEnabled,
    );
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push(_buildEmulatorRoute(game.path));
    if (_adConfig.playExitInterstitialEnabled) {
      AdService.instance.showInterstitialWhenReady(
        minInterval: Duration(
          seconds: _adConfig.playExitInterstitialCooldownSeconds,
        ),
      );
    }
  }

  Future<void> _removeGame(ImportedGame game) async {
    final prefs = await SharedPreferences.getInstance();
    final updatedGames = _games
        .where((savedGame) => savedGame.id != game.id)
        .toList();
    await prefs.setStringList(
      _importedGamesPrefsKey,
      updatedGames.map((savedGame) => jsonEncode(savedGame.toJson())).toList(),
    );

    try {
      final file = File(game.path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // The entry is removed even if the local copy was already unavailable.
    }

    if (!mounted) return;
    setState(() {
      _games = updatedGames;
    });
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
              'SAVED GAMES',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Imported games stay here for quick replay.',
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.white54),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF9D4EDD),
                      ),
                    )
                  : _games.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      itemCount: _games.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        return _buildImportedGameCard(_games[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.save_rounded,
              color: Colors.white38,
              size: 38,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No saved games yet',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Import a ROM from My Console to add it here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildImportedGameCard(ImportedGame game) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151026),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF73DB9A).withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.sports_esports_rounded,
              color: Color(0xFF73DB9A),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${game.fileName} • ${_formatFileSize(game.fileSize)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Remove',
            onPressed: () => _removeGame(game),
            icon: const Icon(Icons.delete_outline_rounded),
            color: Colors.white38,
          ),
          FilledButton.icon(
            onPressed: () => _playGame(game),
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Play'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF9D4EDD),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// CONSOLE CONFIG SCREEN (TAB 2)
// ==========================================

class ConsoleConfigScreen extends StatefulWidget {
  const ConsoleConfigScreen({super.key, required this.onGameImported});

  final VoidCallback onGameImported;

  @override
  State<ConsoleConfigScreen> createState() => _ConsoleConfigScreenState();
}

class _ConsoleConfigScreenState extends State<ConsoleConfigScreen> {
  RemoteAdConfig get _adConfig => AdService.instance.config;

  Future<void> _joinDiscord() async {
    Uri url;
    try {
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('$_apiBaseUrl/api/discord'),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception('Server returned code ${response.statusCode}');
      }

      final payload = jsonDecode(body) as Map<String, dynamic>;
      url = Uri.parse(
        payload['discordUrl'] as String? ?? 'https://discord.gg/vSh2kmcR',
      );
    } catch (_) {
      url = Uri.parse('https://discord.gg/vSh2kmcR');
    }

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Discord link')),
      );
    }
  }

  Future<void> _importGame() async {
    try {
      await AdService.instance.pauseBannerForExternalUi();
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gba', 'zip'],
      );
      AdService.instance.resumeBanner();
      if (result != null && result.files.single.path != null) {
        final pickedFile = result.files.single;
        final sourcePath = pickedFile.path!;
        final options = await _showImportOptionsDialog(pickedFile.name);
        if (options == null) return;

        var playablePath = sourcePath;
        ImportedGame? importedGame;

        if (options.saveToLibrary) {
          final sourceFile = File(sourcePath);
          final fileName = _safeFileName(pickedFile.name);
          final docsDir = await getApplicationDocumentsDirectory();
          final importedDir = Directory('${docsDir.path}/imported_roms');
          if (!await importedDir.exists()) {
            await importedDir.create(recursive: true);
          }

          final id = DateTime.now().millisecondsSinceEpoch.toString();
          final savedPath = '${importedDir.path}/${id}_$fileName';
          final savedFile = await sourceFile.copy(savedPath);
          importedGame = ImportedGame(
            id: id,
            title: options.title,
            path: savedFile.path,
            fileName: pickedFile.name,
            fileSize: await savedFile.length(),
            importedAt: DateTime.now().toIso8601String(),
          );

          final prefs = await SharedPreferences.getInstance();
          final savedGames = prefs.getStringList(_importedGamesPrefsKey) ?? [];
          savedGames.insert(0, jsonEncode(importedGame.toJson()));
          await prefs.setStringList(_importedGamesPrefsKey, savedGames);
          playablePath = importedGame.path;
        }

        if (!mounted) return;
        final targetPath = playablePath;
        final savedGame = importedGame;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(_openImportedGame(targetPath, savedGame));
        });
      }
    } catch (e) {
      AdService.instance.resumeBanner();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error selecting file: $e')));
    }
  }

  Future<void> _openImportedGame(
    String playablePath,
    ImportedGame? importedGame,
  ) async {
    AdService.instance.showActionInterstitial(
      placementEnabled: _adConfig.importedGamePlayInterstitialEnabled,
    );
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push(_buildEmulatorRoute(playablePath));
    if (_adConfig.playExitInterstitialEnabled) {
      AdService.instance.showInterstitialWhenReady(
        minInterval: Duration(
          seconds: _adConfig.playExitInterstitialCooldownSeconds,
        ),
      );
    }

    if (!mounted || importedGame == null) return;
    widget.onGameImported();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${importedGame.title}" saved to your library.'),
        backgroundColor: const Color(0xFF73DB9A),
      ),
    );
  }

  Future<ImportGameOptions?> _showImportOptionsDialog(String fileName) async {
    final controller = TextEditingController(text: _cleanGameTitle(fileName));
    var saveToLibrary = true;

    final result = await showDialog<ImportGameOptions>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF151026),
              title: Text(
                'Import Game',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    enabled: saveToLibrary,
                    autofocus: false,
                    style: GoogleFonts.outfit(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Game name',
                      labelStyle: GoogleFonts.outfit(color: Colors.white60),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF9D4EDD)),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    value: saveToLibrary,
                    onChanged: (value) {
                      setDialogState(() {
                        saveToLibrary = value ?? true;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF9D4EDD),
                    checkColor: Colors.white,
                    title: Text(
                      'Save to Saved Games',
                      style: GoogleFonts.outfit(color: Colors.white),
                    ),
                    subtitle: Text(
                      saveToLibrary
                          ? 'Keep a local copy for one-tap replay later.'
                          : 'Play once without adding it to Saved.',
                      style: GoogleFonts.outfit(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(color: Colors.white60),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    final title = controller.text.trim();
                    Navigator.of(context).pop(
                      ImportGameOptions(
                        title: title.isEmpty
                            ? _cleanGameTitle(fileName)
                            : title,
                        saveToLibrary: saveToLibrary,
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Play'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF9D4EDD),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
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
              subtitle: 'Get updates and legal homebrew recommendations.',
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
            const SizedBox(height: 16),
            _buildActionCard(
              title: 'Reset Tutorial',
              subtitle:
                  'Show the onboarding slides next time you open the app.',
              icon: Icons.refresh_rounded,
              color: const Color(0xFFFF5252),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('show_onboarding', true);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tutorial reset! Please restart the app.'),
                    backgroundColor: Color(0xFFFF5252),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        AdService.instance.showActionInterstitial(
          placementEnabled:
              AdService.instance.config.consoleActionInterstitialEnabled,
        );
        onTap();
      },
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
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: color.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// EMULATOR SCREEN
// ==========================================

// ==========================================
// EMULATOR SCREEN
// ==========================================

class EmulatorScreen extends StatefulWidget {
  const EmulatorScreen({
    super.key,
    required this.romPath,
    required this.theme,
    this.coverUrl,
  });

  final String romPath;
  final EmulatorTheme theme;
  final String? coverUrl;

  @override
  State<EmulatorScreen> createState() => _EmulatorScreenState();
}

class _EmulatorScreenState extends State<EmulatorScreen> {
  late final WebViewController _controller;
  HttpServer? _romServer;
  bool _loading = true;
  late GamepadSkin _gamepadSkin;
  bool _skinUnlockInProgress = false;

  static const int _inputB = 0;
  static const int _inputSelect = 2;
  static const int _inputStart = 3;
  static const int _inputUp = 4;
  static const int _inputDown = 5;
  static const int _inputLeft = 6;
  static const int _inputRight = 7;
  static const int _inputA = 8;
  static const int _inputL = 10;
  static const int _inputR = 11;
  static const int _inputQuickSave = 24;
  static const int _inputQuickLoad = 25;

  @override
  void initState() {
    super.initState();
    AdService.instance.setGameplayActive(true);
    _gamepadSkin = _globalSelectedGamepadSkin;
    final file = File(widget.romPath);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterSaveStateChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _saveDataToFile(message.message, widget.romPath + '.state');
        },
      )
      ..addJavaScriptChannel(
        'FlutterSaveUpdateChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _saveDataToFile(message.message, widget.romPath + '.sav');
        },
      );
    _controller.setOnConsoleMessage((message) {
      debugPrint('EmulatorJS: ${message.level.name}: ${message.message}');
    });

    if (!Platform.isMacOS) {
      _controller.setBackgroundColor(Colors.black);
    }

    _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onSslAuthError: (SslAuthError error) {
          error.cancel();
        },
      ),
    );

    unawaited(_configureAndLoadEmulator(file));
  }

  @override
  void dispose() {
    AdService.instance.setGameplayActive(false);
    unawaited(_romServer?.close(force: true));
    super.dispose();
  }

  Future<void> _configureAndLoadEmulator(File romFile) async {
    final platformController = _controller.platform;
    if (platformController is AndroidWebViewController) {
      await platformController.setAllowFileAccess(true);
      await platformController.setAllowContentAccess(true);
      await platformController.setMixedContentMode(
        MixedContentMode.alwaysAllow,
      );
      await platformController.setMediaPlaybackRequiresUserGesture(false);
    }

    final server = await _startRomServer(romFile);
    final baseUrl = 'http://127.0.0.1:${server.port}/';
    final romUrl = '${baseUrl}rom.gba';

    final saveFile = File(romFile.path + '.sav');
    final stateFile = File(romFile.path + '.state');
    final hasSave = await saveFile.exists();
    final hasState = await stateFile.exists();

    await _controller.loadHtmlString(
      _emulatorHtml(romUrl, baseUrl, hasSave: hasSave, hasState: hasState),
      baseUrl: baseUrl,
    );
  }

  Future<HttpServer> _startRomServer(File romFile) async {
    await _romServer?.close(force: true);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _romServer = server;

    unawaited(
      server.forEach((request) async {
        try {
          final response = request.response;
          response.headers
            ..set(HttpHeaders.accessControlAllowOriginHeader, '*')
            ..set(HttpHeaders.acceptRangesHeader, 'bytes')
            ..set(HttpHeaders.cacheControlHeader, 'no-store');

          if (request.method == 'OPTIONS') {
            response.statusCode = HttpStatus.noContent;
            await response.close();
            return;
          }

          if (request.uri.path == '/rom.gba') {
            if (!await romFile.exists()) {
              response.statusCode = HttpStatus.notFound;
              await response.close();
              return;
            }

            final fileLength = await romFile.length();
            response.headers.contentType = ContentType.binary;
            response.headers.contentLength = fileLength;

            if (request.method != 'HEAD') {
              await response.addStream(romFile.openRead());
            }
            await response.close();
          } else if (request.uri.path == '/save.sav') {
            final saveFile = File(romFile.path + '.sav');
            if (!await saveFile.exists()) {
              response.statusCode = HttpStatus.notFound;
              await response.close();
              return;
            }

            final fileLength = await saveFile.length();
            response.headers.contentType = ContentType.binary;
            response.headers.contentLength = fileLength;

            if (request.method != 'HEAD') {
              await response.addStream(saveFile.openRead());
            }
            await response.close();
          } else if (request.uri.path == '/state.state') {
            final stateFile = File(romFile.path + '.state');
            if (!await stateFile.exists()) {
              response.statusCode = HttpStatus.notFound;
              await response.close();
              return;
            }

            final fileLength = await stateFile.length();
            response.headers.contentType = ContentType.binary;
            response.headers.contentLength = fileLength;

            if (request.method != 'HEAD') {
              await response.addStream(stateFile.openRead());
            }
            await response.close();
          } else if (request.uri.path.startsWith('/emulatorjs/')) {
            final relativePath = request.uri.path.replaceFirst(
              '/emulatorjs/',
              '',
            );
            debugPrint('EmulatorJS asset request: $relativePath');

            try {
              final assetData = await rootBundle.load(
                'assets/emulatorjs/$relativePath',
              );
              final bytes = assetData.buffer.asUint8List(
                assetData.offsetInBytes,
                assetData.lengthInBytes,
              );

              if (relativePath.endsWith('.js')) {
                response.headers.contentType = ContentType(
                  'application',
                  'javascript',
                  charset: 'utf-8',
                );
              } else if (relativePath.endsWith('.css')) {
                response.headers.contentType = ContentType(
                  'text',
                  'css',
                  charset: 'utf-8',
                );
              } else if (relativePath.endsWith('.json')) {
                response.headers.contentType = ContentType(
                  'application',
                  'json',
                  charset: 'utf-8',
                );
              } else if (relativePath.endsWith('.wasm')) {
                response.headers.contentType = ContentType(
                  'application',
                  'wasm',
                );
              } else {
                response.headers.contentType = ContentType.binary;
              }

              response.headers.contentLength = bytes.length;
              if (request.method != 'HEAD') {
                response.add(bytes);
              }
              await response.close();
            } catch (e) {
              debugPrint(
                'Asset not found or failed to load: assets/emulatorjs/$relativePath ($e)',
              );
              response.statusCode = HttpStatus.notFound;
              await response.close();
            }
          } else {
            response.statusCode = HttpStatus.notFound;
            await response.close();
          }
        } catch (_) {
          try {
            request.response.statusCode = HttpStatus.internalServerError;
            await request.response.close();
          } catch (_) {}
        }
      }),
    );

    return server;
  }

  void _sendInput(int inputValue, bool isPressed) {
    final value = isPressed ? 1 : 0;
    _controller.runJavaScript('''
      (function() {
        var emulator = window.EJS_emulator;
        if (!emulator || !emulator.gameManager) return;
        emulator.gameManager.simulateInput(0, $inputValue, $value);
      })();
    ''');
  }

  void _tapInput(int inputValue) {
    _sendInput(inputValue, true);
    Future.delayed(const Duration(milliseconds: 60), () {
      if (mounted) _sendInput(inputValue, false);
    });
  }

  Future<void> _saveDataToFile(String base64Data, String filePath) async {
    try {
      final bytes = base64.decode(base64Data);
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      debugPrint('Successfully saved game data to $filePath');
    } catch (e) {
      debugPrint('Error saving game data to $filePath: $e');
    }
  }

  void _triggerSave() {
    _tapInput(_inputQuickSave);
  }

  void _triggerLoad() {
    _tapInput(_inputQuickLoad);
  }

  void _triggerMenu() {
    _controller.runJavaScript('''
      (function() {
        var emulator = window.EJS_emulator;
        if (emulator && emulator.menu) emulator.menu.toggle();
      })();
    ''');
  }

  Future<void> _unlockNextGamepadSkin() async {
    if (_skinUnlockInProgress) return;
    setState(() => _skinUnlockInProgress = true);

    try {
      final earned = AdService.instance.config.skinRewardedEnabled
          ? await AdService.instance.showRewardedAd(
              context: context,
              unavailableMessage: 'Skin ad is loading. Try again soon.',
            )
          : true;
      if (!mounted || !earned) return;

      final currentIndex = availableGamepadSkins.indexWhere(
        (skin) => skin.id == _gamepadSkin.id,
      );
      final nextIndex = (currentIndex + 1) % availableGamepadSkins.length;
      final nextSkin = availableGamepadSkins[nextIndex];

      setState(() {
        _gamepadSkin = nextSkin;
        _globalSelectedGamepadSkin = nextSkin;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${nextSkin.name} controller skin applied.'),
          backgroundColor: nextSkin.accent,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _skinUnlockInProgress = false);
      }
    }
  }

  String _emulatorHtml(
    String romUrl,
    String baseUrl, {
    required bool hasSave,
    required bool hasState,
  }) {
    final title = widget.romPath.split('/').last;
    final dataPath = 'emulatorjs/';

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
    #game { width: 100vw; height: 100vh; box-shadow: 0 0 30px ${widget.theme.glowColor}; }
    #status {
      position: absolute; inset: 0; z-index: 20; display: flex; align-items: center; justify-content: center;
      color: #73DB9A; text-align: center; padding: 20px; background: rgba(0,0,0,0.2); font-size: 13px;
    }
    .crt-overlay {
      position: absolute; top: 0; left: 0; right: 0; bottom: 0; pointer-events: none; z-index: 999;
      ${widget.theme.overlayCss}
    }
    .ejs_virtualGamepad_parent,
    .ejs_virtualGamepad_parent *,
    .ejs_virtualGamepad_open {
      display: none !important;
      opacity: 0 !important;
      pointer-events: none !important;
    }
  </style>
</head>
<body>
  <div id="game-container">
    <div id="game"></div>
    <div id="status">Loading emulator...</div>
    <div class="crt-overlay"></div>
  </div>
  <script>
    var statusEl;
    function setStatus(message, isError) {
      statusEl = statusEl || document.getElementById('status');
      if (!statusEl) return;
      statusEl.textContent = message;
      statusEl.style.color = isError ? '#FF5252' : '#73DB9A';
      statusEl.style.display = 'flex';
    }
    window.addEventListener('error', function(event) {
      setStatus('Emulator error: ' + (event.message || 'failed to load asset'), true);
    });
    window.addEventListener('unhandledrejection', function(event) {
      setStatus('Emulator error: ' + (event.reason && event.reason.message ? event.reason.message : event.reason), true);
    });

    window.EJS_player = '#game';
    window.EJS_core = 'mgba';
    window.EJS_gameName = ${jsonEncode(title)};
    window.EJS_gameUrl = ${jsonEncode(romUrl)};
    window.EJS_pathtodata = ${jsonEncode(dataPath)};
    window.EJS_startOnLoaded = true;
    window.EJS_theme = 'dark';
    window.EJS_color = '${widget.theme.glowColor == 'transparent' ? '#000000' : widget.theme.glowColor}';
    window.EJS_Buttons = {};
    window.EJS_defaultOptions = {
      'virtual-gamepad': 'disabled',
      'menu-bar-button': 'hidden'
    };
    window.EJS_DEBUG_XX = true; // Load bundled src files instead of missing minified assets.
    window.EJS_language = "en-US";
    window.EJS_disableAutoLang = false;
    ${hasSave ? "window.EJS_loadSaveURL = '${baseUrl}save.sav';" : ""}
    ${hasState ? "window.EJS_loadStateURL = '${baseUrl}state.state';" : ""}
    window.EJS_onSaveState = function(args) {
      var saveState = args[1];
      if (!saveState) return;
      var binary = '';
      var bytes = new Uint8Array(saveState);
      var len = bytes.byteLength;
      for (var i = 0; i < len; i++) {
        binary += String.fromCharCode(bytes[i]);
      }
      var base64 = window.btoa(binary);
      if (window.FlutterSaveStateChannel) {
        window.FlutterSaveStateChannel.postMessage(base64);
      }
    };
    window.EJS_onSaveUpdate = function(data) {
      var save = data.save;
      if (!save) return;
      var binary = '';
      var bytes = new Uint8Array(save);
      var len = bytes.byteLength;
      for (var i = 0; i < len; i++) {
        binary += String.fromCharCode(bytes[i]);
      }
      var base64 = window.btoa(binary);
      if (window.FlutterSaveUpdateChannel) {
        window.FlutterSaveUpdateChannel.postMessage(base64);
      }
    };
    window.EJS_onGameStart = function() {
      statusEl = statusEl || document.getElementById('status');
      if (statusEl) statusEl.style.display = 'none';
    };
  </script>
  <script src="${dataPath}loader.js"></script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0914),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Top header with Back button & Game title
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _cleanGameTitle(widget.romPath.split('/').last),
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Aspect Ratio 3:2 Game screen WebView
                Container(
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(
                        color: Colors.white.withOpacity(0.05),
                        width: 1,
                      ),
                    ),
                  ),
                  child: AspectRatio(
                    aspectRatio: 3 / 2,
                    child: WebViewWidget(controller: _controller),
                  ),
                ),

                // Gamepad area taking the remaining space
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Align(
                        alignment: const Alignment(
                          0,
                          -0.2,
                        ), // Align slightly upwards
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: 380,
                            height: 290,
                            decoration: BoxDecoration(
                              color: _gamepadSkin.panel.withValues(alpha: 0.62),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: _gamepadSkin.border.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _gamepadSkin.accent.withValues(
                                    alpha: 0.14,
                                  ),
                                  blurRadius: 24,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                                vertical: 8.0,
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Row 1: Save, Load, Menu action buttons
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      GamepadActionButton(
                                        icon: Icons.save_outlined,
                                        label: 'Save',
                                        onTap: _triggerSave,
                                        skin: _gamepadSkin,
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          GamepadActionButton(
                                            icon: Icons.unarchive_outlined,
                                            label: 'Load',
                                            onTap: _triggerLoad,
                                            skin: _gamepadSkin,
                                          ),
                                          const SizedBox(width: 10),
                                          GamepadActionButton(
                                            icon: _skinUnlockInProgress
                                                ? Icons.hourglass_top_rounded
                                                : Icons.palette_outlined,
                                            label: 'Skin',
                                            onTap: _skinUnlockInProgress
                                                ? () {}
                                                : _unlockNextGamepadSkin,
                                            skin: _gamepadSkin,
                                          ),
                                          const SizedBox(width: 10),
                                          GamepadActionButton(
                                            icon: Icons.more_vert_rounded,
                                            onTap: _triggerMenu,
                                            skin: _gamepadSkin,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  // Row 2: L, SELECT, START, R shoulder & command buttons
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      RectGamepadButton(
                                        label: 'L',
                                        inputValue: _inputL,
                                        onInput: _sendInput,
                                        width: 55,
                                        skin: _gamepadSkin,
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          RectGamepadButton(
                                            label: 'SELECT',
                                            inputValue: _inputSelect,
                                            onInput: _sendInput,
                                            width: 80,
                                            skin: _gamepadSkin,
                                          ),
                                          const SizedBox(width: 12),
                                          RectGamepadButton(
                                            label: 'START',
                                            inputValue: _inputStart,
                                            onInput: _sendInput,
                                            width: 80,
                                            skin: _gamepadSkin,
                                          ),
                                        ],
                                      ),
                                      RectGamepadButton(
                                        label: 'R',
                                        inputValue: _inputR,
                                        onInput: _sendInput,
                                        width: 55,
                                        skin: _gamepadSkin,
                                      ),
                                    ],
                                  ),

                                  // Row 3: D-pad (left) & A/B Buttons (right)
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // D-Pad
                                      DPadWidget(
                                        upInput: _inputUp,
                                        downInput: _inputDown,
                                        leftInput: _inputLeft,
                                        rightInput: _inputRight,
                                        onInput: _sendInput,
                                        skin: _gamepadSkin,
                                      ),

                                      // A/B Action Buttons Stacked in diagonal layout
                                      SizedBox(
                                        width: 160,
                                        height: 160,
                                        child: Stack(
                                          children: [
                                            // Button B (Lower Left)
                                            Positioned(
                                              bottom: 12,
                                              left: 8,
                                              child: GamepadButton(
                                                label: 'B',
                                                inputValue: _inputB,
                                                onInput: _sendInput,
                                                skin: _gamepadSkin,
                                              ),
                                            ),
                                            // Button A (Upper Right)
                                            Positioned(
                                              top: 12,
                                              right: 8,
                                              child: GamepadButton(
                                                label: 'A',
                                                inputValue: _inputA,
                                                onInput: _sendInput,
                                                skin: _gamepadSkin,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const AdBanner(),
              ],
            ),
          ),

          // Initial Loading Indicator Screen
          if (_loading)
            Positioned.fill(
              child: Container(
                color: const Color(0xFF0B0914),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Blurred game cover as background
                    if (widget.coverUrl != null &&
                        widget.coverUrl!.isNotEmpty) ...[
                      Opacity(
                        opacity: 0.25,
                        child: Image.network(
                          widget.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox(),
                        ),
                      ),
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(color: Colors.black.withOpacity(0.35)),
                      ),
                    ],

                    // Centered Content
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Small Game Poster Card in Center
                          if (widget.coverUrl != null &&
                              widget.coverUrl!.isNotEmpty) ...[
                            Container(
                              height: 180,
                              width: 130,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF9D4EDD,
                                    ).withOpacity(0.4),
                                    blurRadius: 25,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  widget.coverUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: const Color(0xFF151026),
                                        child: const Icon(
                                          Icons.sports_esports_rounded,
                                          color: Color(0xFFD2BBFF),
                                          size: 40,
                                        ),
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ] else ...[
                            // Default glowing console icon if no cover image
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF9D4EDD).withOpacity(0.1),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF9D4EDD,
                                    ).withOpacity(0.3),
                                    blurRadius: 30,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.sports_esports_rounded,
                                color: Color(0xFFD2BBFF),
                                size: 48,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // BOOTING ROM Text
                          Text(
                            'BOOTING ROM...',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFD2BBFF),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              shadows: [
                                const Shadow(
                                  color: Colors.black54,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Progress Loading Bar
                          SizedBox(
                            width: 220,
                            child: Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: const LinearProgressIndicator(
                                    color: Color(0xFF00E676),
                                    backgroundColor: Colors.white12,
                                    minHeight: 6,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Initializing emulator...',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==========================================
// GAMEPAD CUSTOM WIDGETS
// ==========================================

class DPadWidget extends StatefulWidget {
  final int upInput;
  final int downInput;
  final int leftInput;
  final int rightInput;
  final void Function(int inputValue, bool isPressed) onInput;
  final GamepadSkin skin;

  const DPadWidget({
    super.key,
    required this.upInput,
    required this.downInput,
    required this.leftInput,
    required this.rightInput,
    required this.onInput,
    required this.skin,
  });

  @override
  State<DPadWidget> createState() => _DPadWidgetState();
}

class _DPadWidgetState extends State<DPadWidget> {
  String? _activeDirection;
  static const double _pi = 3.1415926535897932;

  void _updateTouch(Offset localPosition, double size) {
    final center = Offset(size / 2, size / 2);
    final direction = localPosition - center;

    if (direction.distance > size / 2 || direction.distance < size * 0.15) {
      _releaseActive();
      return;
    }

    final angle = direction.direction;
    String newDirection;
    if (angle >= -_pi / 4 && angle < _pi / 4) {
      newDirection = 'right';
    } else if (angle >= _pi / 4 && angle < 3 * _pi / 4) {
      newDirection = 'down';
    } else if (angle >= -3 * _pi / 4 && angle < -_pi / 4) {
      newDirection = 'up';
    } else {
      newDirection = 'left';
    }

    _setActiveDirection(newDirection);
  }

  void _releaseActive() {
    _setActiveDirection(null);
  }

  void _setActiveDirection(String? newDirection) {
    if (newDirection == _activeDirection) return;

    final previousDirection = _activeDirection;
    if (previousDirection != null) {
      widget.onInput(_inputForDirection(previousDirection), false);
    }

    setState(() => _activeDirection = newDirection);

    if (newDirection != null) {
      widget.onInput(_inputForDirection(newDirection), true);
    }
  }

  int _inputForDirection(String direction) {
    switch (direction) {
      case 'up':
        return widget.upInput;
      case 'down':
        return widget.downInput;
      case 'left':
        return widget.leftInput;
      case 'right':
        return widget.rightInput;
      default:
        return widget.upInput;
    }
  }

  @override
  Widget build(BuildContext context) {
    const size = 160.0;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) => _updateTouch(event.localPosition, size),
      onPointerMove: (event) => _updateTouch(event.localPosition, size),
      onPointerUp: (_) => _releaseActive(),
      onPointerCancel: (_) => _releaseActive(),
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _DPadPainter(
            activeDirection: _activeDirection,
            skin: widget.skin,
          ),
        ),
      ),
    );
  }
}

class _DPadPainter extends CustomPainter {
  final String? activeDirection;
  final GamepadSkin skin;

  _DPadPainter({this.activeDirection, required this.skin});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bgPaint = Paint()
      ..color = skin.surface.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    final borderPaint = Paint()
      ..color = skin.border.withValues(alpha: 0.58)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, borderPaint);

    final crossWidth = radius * 0.45;
    final crossLength = radius * 0.85;

    final crossPath = Path();
    crossPath.moveTo(center.dx - crossWidth / 2, center.dy - crossLength);
    crossPath.lineTo(center.dx + crossWidth / 2, center.dy - crossLength);
    crossPath.lineTo(center.dx + crossWidth / 2, center.dy - crossWidth / 2);
    crossPath.lineTo(center.dx + crossLength, center.dy - crossWidth / 2);
    crossPath.lineTo(center.dx + crossLength, center.dy + crossWidth / 2);
    crossPath.lineTo(center.dx + crossWidth / 2, center.dy + crossWidth / 2);
    crossPath.lineTo(center.dx + crossWidth / 2, center.dy + crossLength);
    crossPath.lineTo(center.dx - crossWidth / 2, center.dy + crossLength);
    crossPath.lineTo(center.dx - crossWidth / 2, center.dy + crossWidth / 2);
    crossPath.lineTo(center.dx - crossLength, center.dy + crossWidth / 2);
    crossPath.lineTo(center.dx - crossLength, center.dy - crossWidth / 2);
    crossPath.lineTo(center.dx - crossWidth / 2, center.dy - crossWidth / 2);
    crossPath.close();

    if (activeDirection != null) {
      final activePaint = Paint()
        ..color = skin.pressedSurface.withValues(alpha: 0.62)
        ..style = PaintingStyle.fill;

      final activePath = Path();
      if (activeDirection == 'up') {
        activePath.moveTo(center.dx - crossWidth / 2, center.dy - crossLength);
        activePath.lineTo(center.dx + crossWidth / 2, center.dy - crossLength);
        activePath.lineTo(center.dx + crossWidth / 2, center.dy);
        activePath.lineTo(center.dx - crossWidth / 2, center.dy);
      } else if (activeDirection == 'down') {
        activePath.moveTo(center.dx - crossWidth / 2, center.dy);
        activePath.lineTo(center.dx + crossWidth / 2, center.dy);
        activePath.lineTo(center.dx + crossWidth / 2, center.dy + crossLength);
        activePath.lineTo(center.dx - crossWidth / 2, center.dy + crossLength);
      } else if (activeDirection == 'left') {
        activePath.moveTo(center.dx - crossLength, center.dy - crossWidth / 2);
        activePath.lineTo(center.dx, center.dy - crossWidth / 2);
        activePath.lineTo(center.dx, center.dy + crossWidth / 2);
        activePath.lineTo(center.dx - crossLength, center.dy + crossWidth / 2);
      } else if (activeDirection == 'right') {
        activePath.moveTo(center.dx, center.dy - crossWidth / 2);
        activePath.lineTo(center.dx + crossLength, center.dy - crossWidth / 2);
        activePath.lineTo(center.dx + crossLength, center.dy + crossWidth / 2);
        activePath.lineTo(center.dx, center.dy + crossWidth / 2);
      }
      activePath.close();
      canvas.drawPath(activePath, activePaint);
    }

    canvas.drawPath(crossPath, borderPaint);

    final arrowPaint = Paint()
      ..color = skin.text.withValues(alpha: 0.44)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final upArrow = Path()
      ..moveTo(center.dx - 6, center.dy - radius + 15)
      ..lineTo(center.dx, center.dy - radius + 9)
      ..lineTo(center.dx + 6, center.dy - radius + 15)
      ..close();
    canvas.drawPath(upArrow, arrowPaint);

    final downArrow = Path()
      ..moveTo(center.dx - 6, center.dy + radius - 15)
      ..lineTo(center.dx, center.dy + radius - 9)
      ..lineTo(center.dx + 6, center.dy + radius - 15)
      ..close();
    canvas.drawPath(downArrow, arrowPaint);

    final leftArrow = Path()
      ..moveTo(center.dx - radius + 15, center.dy - 6)
      ..lineTo(center.dx - radius + 9, center.dy)
      ..lineTo(center.dx - radius + 15, center.dy + 6)
      ..close();
    canvas.drawPath(leftArrow, arrowPaint);

    final rightArrow = Path()
      ..moveTo(center.dx + radius - 15, center.dy - 6)
      ..lineTo(center.dx + radius - 9, center.dy)
      ..lineTo(center.dx + radius - 15, center.dy + 6)
      ..close();
    canvas.drawPath(rightArrow, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant _DPadPainter oldDelegate) =>
      oldDelegate.activeDirection != activeDirection ||
      oldDelegate.skin != skin;
}

class GamepadButton extends StatefulWidget {
  final String label;
  final int inputValue;
  final void Function(int inputValue, bool isPressed) onInput;
  final double size;
  final GamepadSkin skin;

  const GamepadButton({
    super.key,
    required this.label,
    required this.inputValue,
    required this.onInput,
    required this.skin,
    this.size = 64.0,
  });

  @override
  State<GamepadButton> createState() => _GamepadButtonState();
}

class _GamepadButtonState extends State<GamepadButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        setState(() => _isPressed = true);
        widget.onInput(widget.inputValue, true);
      },
      onPointerUp: (_) {
        setState(() => _isPressed = false);
        widget.onInput(widget.inputValue, false);
      },
      onPointerCancel: (_) {
        setState(() => _isPressed = false);
        widget.onInput(widget.inputValue, false);
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: _isPressed
              ? widget.skin.pressedSurface.withValues(alpha: 0.86)
              : widget.skin.surface.withValues(alpha: 0.82),
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.skin.border.withValues(alpha: 0.72),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.skin.accent.withValues(
                alpha: _isPressed ? 0.32 : 0.16,
              ),
              blurRadius: _isPressed ? 16 : 10,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: widget.skin.text.withValues(alpha: 0.92),
          ),
        ),
      ),
    );
  }
}

class RectGamepadButton extends StatefulWidget {
  final String label;
  final int inputValue;
  final void Function(int inputValue, bool isPressed) onInput;
  final double width;
  final double height;
  final GamepadSkin skin;

  const RectGamepadButton({
    super.key,
    required this.label,
    required this.inputValue,
    required this.onInput,
    required this.skin,
    this.width = 80,
    this.height = 40,
  });

  @override
  State<RectGamepadButton> createState() => _RectGamepadButtonState();
}

class _RectGamepadButtonState extends State<RectGamepadButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        setState(() => _isPressed = true);
        widget.onInput(widget.inputValue, true);
      },
      onPointerUp: (_) {
        setState(() => _isPressed = false);
        widget.onInput(widget.inputValue, false);
      },
      onPointerCancel: (_) {
        setState(() => _isPressed = false);
        widget.onInput(widget.inputValue, false);
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: _isPressed
              ? widget.skin.pressedSurface.withValues(alpha: 0.86)
              : widget.skin.surface.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: widget.skin.border.withValues(alpha: 0.68),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: GoogleFonts.outfit(
            fontSize: widget.label.length > 2 ? 11 : 14,
            fontWeight: FontWeight.bold,
            color: widget.skin.text.withValues(alpha: 0.92),
          ),
        ),
      ),
    );
  }
}

class GamepadActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  final GamepadSkin? skin;

  const GamepadActionButton({
    super.key,
    required this.icon,
    this.label,
    required this.onTap,
    this.skin,
  });

  @override
  Widget build(BuildContext context) {
    final activeSkin = skin ?? availableGamepadSkins.first;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: activeSkin.surface.withValues(alpha: 0.68),
              shape: BoxShape.circle,
              border: Border.all(
                color: activeSkin.border.withValues(alpha: 0.58),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: activeSkin.text.withValues(alpha: 0.9),
              size: 20,
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 2),
            Text(
              label!,
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: activeSkin.text.withValues(alpha: 0.76),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ==========================================
// SPLASH SCREEN
// ==========================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0.0;
  bool _showOnboarding = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    unawaited(_prepareAppAndNavigate());
  }

  Future<void> _prepareAppAndNavigate() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    await _runStartupStep(0.12, () async {
      await precacheImage(const AssetImage('assets/splash.png'), context);
    });

    await _runStartupStep(0.36, () async {
      final prefs = await SharedPreferences.getInstance();
      _showOnboarding = prefs.getBool('show_onboarding') ?? true;
    });

    await _runStartupStep(0.56, () async {
      await AdService.instance.loadRemoteConfig();
      AdService.instance.preloadInterstitial();
      await AdService.instance.prepareAppOpenForLaunch();
    });

    await _runStartupStep(0.78, _warmHomeData);

    await _runStartupStep(1.0, () async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await AdService.instance.showAppOpenIfAvailable(
        coldStart: true,
        minInterval: Duration(
          minutes: AdService.instance.config.appOpenColdStartCooldownMinutes,
        ),
      );
    });

    await _navigateToNextScreen();
  }

  Future<void> _runStartupStep(
    double targetProgress,
    FutureOr<void> Function() action,
  ) async {
    try {
      await Future<void>.sync(
        action,
      ).timeout(const Duration(seconds: 5), onTimeout: () {});
    } catch (_) {
      // Startup should continue with cached/fallback data if a warmup step fails.
    }

    if (!mounted) return;
    setState(() {
      _progress = targetProgress.clamp(_progress, 1.0);
    });
  }

  Future<void> _warmHomeData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedPayload = prefs.getString(_remoteGamesPrefsKey);
    if (cachedPayload != null && cachedPayload.isNotEmpty) return;

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);
    try {
      final request = await client.getUrl(
        Uri.parse('$_apiBaseUrl/api/app/home'),
      );
      request.headers.set(HttpHeaders.cacheControlHeader, 'max-age=300');
      final response = await request.close();
      if (response.statusCode != 200) return;

      final body = await response.transform(utf8.decoder).join();
      final payload = jsonDecode(body) as Map<String, dynamic>;
      final rawItems = <dynamic>[
        ...((payload['featured'] as List<dynamic>?) ?? const []),
        ...((payload['games'] as List<dynamic>?) ?? const []),
      ];
      if (rawItems.isNotEmpty) {
        await prefs.setString(_remoteGamesPrefsKey, jsonEncode(rawItems));
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _navigateToNextScreen() async {
    if (!mounted) return;

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            _showOnboarding ? const OnboardingScreen() : const MainTabScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0914),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/splash.png',
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),

          // Subtle dark gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.05),
                    Colors.black.withOpacity(0.12),
                    Colors.black.withOpacity(0.45),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Bottom progress indicator
          Positioned(
            bottom: 54,
            left: 28,
            right: 28,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.34),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: _progress,
                      color: const Color(0xFF73DB9A),
                      backgroundColor: Colors.white.withOpacity(0.18),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'LOADING GBAGAME... ${(_progress * 100).toInt()}%',
                  style: GoogleFonts.outfit(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    shadows: [
                      const Shadow(
                        color: Colors.black54,
                        blurRadius: 6,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// ONBOARDING SCREEN
// ==========================================

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_onboarding', false);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const MainTabScreen()));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0914),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_currentPage > 0) {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        color: _currentPage > 0 ? Colors.white : Colors.white30,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'GBAGame: GBA Homebrew',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page View Content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [_buildStep1(), _buildStep2(), _buildStep3()],
              ),
            ),

            // Bottom Navigation Area
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 24.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Indicators
                  Row(
                    children: List.generate(3, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? Colors.white : Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  // Next / Get Started Button
                  if (_currentPage < 2)
                    GestureDetector(
                      onTap: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E676).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          'Next',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: _completeOnboarding,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF3D00), Color(0xFFFF9100)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF3D00).withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          'Get Started',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const AdBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              'Step 1',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                color: const Color(0xFF00E676),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search "GBAGame: GBA Homebrew", "GBAGame", or "GBA Emulator" on Google Play to find this free app again, get updates, and share it with friends.',
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // Visual simulation
            Center(
              child: SizedBox(
                height: 240,
                width: 320,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Highlighted Join Community Card
                    const Positioned(
                      top: 10,
                      left: 10,
                      right: 10,
                      child: OnboardingCardSim(
                        title: 'Join Community',
                        subtitle:
                            'Free updates, support, and legal game recommendations.',
                        icon: Icons.discord,
                        color: Color(0xFF5865F2),
                        isHighlighted: true,
                      ),
                    ),
                    // Faded Import & Play Card
                    const Positioned(
                      top: 110,
                      left: 10,
                      right: 10,
                      child: OnboardingCardSim(
                        title: 'Import & Play',
                        subtitle:
                            'Load your legally obtained .gba or .zip ROMs.',
                        icon: Icons.sports_esports_rounded,
                        color: Color(0xFF73DB9A),
                        isFaded: true,
                      ),
                    ),
                    // Pointing hand pointing at the Join Community card
                    Positioned(
                      top: 55,
                      right: 25,
                      child: AnimatedPointer(
                        child: Transform.rotate(
                          angle: -0.2,
                          child: const PointingHand(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              'Step 2',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                color: const Color(0xFF00E676),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Discover free GBA homebrew and official demos from the app library. Download only games that are allowed for public distribution.',
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // Game cartridges stacked & download button
            Center(
              child: SizedBox(
                height: 280,
                width: 320,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Zelda Cartridge (Left)
                    Positioned(
                      left: 20,
                      top: 10,
                      child: Transform.rotate(
                        angle: -0.25,
                        child: RetroCartridge(
                          title: 'ZELDA',
                          consoleText: 'GAME BOY ADVANCE',
                          gradientColors: const [
                            Color(0xFF004D40),
                            Color(0xFF00C853),
                          ],
                          child: Icon(
                            Icons.shield_rounded,
                            color: Colors.yellow.shade700,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                    // Tekken Cartridge (Right)
                    Positioned(
                      right: 20,
                      top: 15,
                      child: Transform.rotate(
                        angle: 0.22,
                        child: const RetroCartridge(
                          title: 'FIGHTERS',
                          consoleText: 'GAME BOY ADVANCE',
                          gradientColors: [
                            Color(0xFFB71C1C),
                            Color(0xFFE53935),
                          ],
                          child: Icon(
                            Icons.flash_on_rounded,
                            color: Colors.amber,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                    // Pokemon Cartridge (Center)
                    Positioned(
                      top: 5,
                      child: Transform.rotate(
                        angle: -0.05,
                        child: RetroCartridge(
                          title: 'MONSTERS',
                          consoleText: 'GAME BOY ADVANCE',
                          gradientColors: const [
                            Color(0xFFFF6D00),
                            Color(0xFFFFD600),
                          ],
                          child: Icon(
                            Icons.bolt_rounded,
                            color: Colors.blue.shade900,
                            size: 40,
                          ),
                        ),
                      ),
                    ),

                    // Download button simulating the website action
                    Positioned(
                      bottom: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF007AFF).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Download Games',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.download_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Pointing hand pointing at the Download Games button
                    Positioned(
                      bottom: 0,
                      right: 40,
                      child: AnimatedPointer(
                        child: Transform.rotate(
                          angle: -0.1,
                          child: const PointingHand(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              'Step 3',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                color: const Color(0xFF00E676),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use "Import & Play" to load your own legally obtained .gba or .zip files and turn your phone into a free portable GBA emulator.',
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // Simulator visualization
            Center(
              child: SizedBox(
                height: 240,
                width: 320,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Faded Join Community Card
                    const Positioned(
                      top: 10,
                      left: 10,
                      right: 10,
                      child: OnboardingCardSim(
                        title: 'Join Community',
                        subtitle:
                            'Free updates, support, and legal game recommendations.',
                        icon: Icons.discord,
                        color: Color(0xFF5865F2),
                        isFaded: true,
                      ),
                    ),
                    // Highlighted Import & Play Card
                    const Positioned(
                      top: 110,
                      left: 10,
                      right: 10,
                      child: OnboardingCardSim(
                        title: 'Import & Play',
                        subtitle:
                            'Load your legally obtained .gba or .zip ROMs.',
                        icon: Icons.sports_esports_rounded,
                        color: Color(0xFF73DB9A),
                        isHighlighted: true,
                      ),
                    ),
                    // Pointing hand pointing at the Import & Play card
                    Positioned(
                      top: 155,
                      right: 25,
                      child: AnimatedPointer(
                        child: Transform.rotate(
                          angle: -0.2,
                          child: const PointingHand(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// ONBOARDING HELPERS / CUSTOM PAINTERS
// ==========================================

class PointingHand extends StatelessWidget {
  const PointingHand({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 56,
      child: CustomPaint(painter: _PointingHandPainter()),
    );
  }
}

class _PointingHandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFF1E1035)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final cuffPaint = Paint()
      ..color =
          const Color(0xFF007AFF) // blue cuff
      ..style = PaintingStyle.fill;

    // Draw blue sleeve/cuff at the bottom
    final cuffRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.2,
        size.height * 0.7,
        size.width * 0.6,
        size.height * 0.25,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(cuffRect, cuffPaint);
    canvas.drawRRect(cuffRect, borderPaint);

    // Draw white hand body and pointing finger
    final handPath = Path();
    handPath.moveTo(
      size.width * 0.35,
      size.height * 0.7,
    ); // connection to cuff left
    handPath.lineTo(size.width * 0.25, size.height * 0.45); // palm side left
    handPath.quadraticBezierTo(
      size.width * 0.23,
      size.height * 0.4,
      size.width * 0.28,
      size.height * 0.38,
    ); // tip of folded thumb
    handPath.lineTo(size.width * 0.35, size.height * 0.42); // thumb fold

    // Index finger (pointing)
    handPath.lineTo(size.width * 0.35, size.height * 0.1);
    handPath.quadraticBezierTo(
      size.width * 0.38,
      size.height * 0.03,
      size.width * 0.46,
      size.height * 0.1,
    ); // tip of index finger
    handPath.lineTo(size.width * 0.5, size.height * 0.4); // knuckle side

    // Other fingers (folded)
    // Middle
    handPath.quadraticBezierTo(
      size.width * 0.53,
      size.height * 0.38,
      size.width * 0.56,
      size.height * 0.42,
    );
    handPath.quadraticBezierTo(
      size.width * 0.62,
      size.height * 0.44,
      size.width * 0.58,
      size.height * 0.52,
    );
    // Ring
    handPath.quadraticBezierTo(
      size.width * 0.63,
      size.height * 0.5,
      size.width * 0.66,
      size.height * 0.54,
    );
    handPath.quadraticBezierTo(
      size.width * 0.7,
      size.height * 0.56,
      size.width * 0.63,
      size.height * 0.63,
    );
    // Pinky
    handPath.quadraticBezierTo(
      size.width * 0.67,
      size.height * 0.61,
      size.width * 0.68,
      size.height * 0.65,
    );
    handPath.quadraticBezierTo(
      size.width * 0.7,
      size.height * 0.68,
      size.width * 0.6,
      size.height * 0.7,
    ); // bottom palm right

    handPath.close();

    // Draw shadow
    canvas.drawPath(
      handPath.shift(const Offset(2, 2)),
      Paint()
        ..color = Colors.black.withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Draw hand
    canvas.drawPath(handPath, paint);
    canvas.drawPath(handPath, borderPaint);

    // Draw some subtle line separation for folded fingers
    final fingerLine1 = Path();
    fingerLine1.moveTo(size.width * 0.46, size.height * 0.44);
    fingerLine1.lineTo(size.width * 0.56, size.height * 0.46);
    canvas.drawPath(fingerLine1, borderPaint);

    final fingerLine2 = Path();
    fingerLine2.moveTo(size.width * 0.48, size.height * 0.53);
    fingerLine2.lineTo(size.width * 0.6, size.height * 0.55);
    canvas.drawPath(fingerLine2, borderPaint);

    final fingerLine3 = Path();
    fingerLine3.moveTo(size.width * 0.48, size.height * 0.62);
    fingerLine3.lineTo(size.width * 0.62, size.height * 0.64);
    canvas.drawPath(fingerLine3, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AnimatedPointer extends StatefulWidget {
  final Widget child;
  const AnimatedPointer({super.key, required this.child});

  @override
  State<AnimatedPointer> createState() => _AnimatedPointerState();
}

class _AnimatedPointerState extends State<AnimatedPointer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.15, -0.15), // bounce up-left
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(position: _offsetAnimation, child: widget.child);
  }
}

class RetroCartridge extends StatelessWidget {
  final String title;
  final String consoleText;
  final List<Color> gradientColors;
  final Widget child;

  const RetroCartridge({
    super.key,
    required this.title,
    required this.consoleText,
    required this.gradientColors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 105,
      height: 135,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(2, 4),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // GBA cartridge top indent
          Container(
            height: 14,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
            child: Text(
              consoleText,
              style: GoogleFonts.outfit(
                fontSize: 6,
                color: Colors.white30,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Cartridge body / Sticker area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: FittedBox(fit: BoxFit.scaleDown, child: child),
                      ),
                    ),
                    Container(
                      color: Colors.black.withOpacity(0.6),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 8,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Cartridge bottom slot (just visual detail)
          Container(height: 6, color: const Color(0xFF121212)),
        ],
      ),
    );
  }
}

class OnboardingCardSim extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isHighlighted;
  final bool isFaded;

  const OnboardingCardSim({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.isHighlighted = false,
    this.isFaded = false,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = isFaded ? 0.35 : 1.0;
    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(isHighlighted ? 0.22 : 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isHighlighted
                ? const Color(0xFF00E676)
                : color.withOpacity(0.3),
            width: isHighlighted ? 2 : 1,
          ),
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: const Color(0xFF00E676).withOpacity(0.2),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : null,
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
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: isHighlighted
                  ? const Color(0xFF00E676)
                  : color.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
