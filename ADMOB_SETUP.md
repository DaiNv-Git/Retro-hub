# AdMob Setup

The app is wired for Google AdMob with Google test IDs.

Before publishing real ads, replace these values:

## Flutter ad unit IDs

File: `lib/main.dart`

- `AdConfig.androidBannerId`
- `AdConfig.iosBannerId`
- `AdConfig.androidInterstitialId`
- `AdConfig.iosInterstitialId`

## Native AdMob app IDs

Android file: `android/app/src/main/AndroidManifest.xml`

- `com.google.android.gms.ads.APPLICATION_ID`

iOS file: `ios/Runner/Info.plist`

- `GADApplicationIdentifier`

## Current placement

- Banner ad: shown above the bottom navigation on the main app tabs.
- Interstitial ad: shown after every 3 successful game downloads.
- No ads are shown inside the emulator play screen.
