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

- Banner ad: helper code is available, but it is not mounted by default because
  Android file picker flows can conflict with AdMob platform views.
- Interstitial ad: shown after every 3 successful game downloads.
- No ads are shown inside the emulator play screen.
