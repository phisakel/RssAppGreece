# RssReader Greece

Requires Xcode 16 or newer and iOS 18.0 or newer. Open `RssReader.xcodeproj` (the workspace also opens the same project). Xcode resolves Swift Package Manager dependencies automatically; CocoaPods and Ruby are no longer required.

Website: `https://${FIREBASE_PROJECT_ID}.web.app`

## Dependencies

- SDWebImage 5.21.5 and Google Mobile Ads 13.11.0 use their official SPM packages. `Package.resolved` pins the resolved versions, including Google's User Messaging Platform dependency.
- `Packages/LegacyReaderUI` packages the existing REMenu 1.10, SWRevealViewController 2.3.0, and MWFeedParser 1.0.1 HTML string helpers locally, with their licenses. These legacy sources do not provide official SPM manifests. The local menu targets enable ARC and explicitly import UIKit instead of relying on CocoaPods prefix headers.
- AFNetworking is replaced by URLSession. The unused MRProgress and UIActivityIndicator-for-SDWebImage dependencies are removed. The app already implements its own feed parser.
- The unused Realm binary, obsolete iAd framework, Pod configuration files, libraries, and build phases are removed from the project.

## Google Mobile Ads

The AdMob app is **RSS Greece** (iOS). `Info.plist` receives the app ID from `RSS_ADMOB_APP_ID` at build time and contains Google's SKAdNetwork buyer identifiers. `Info.plist` disables all banners with `BannerAdsEnabled = false`. Set it to `true` to allow the home and article banner switches in `ReaderConf.plist`. The production banner unit (**RSS Greece Adaptive Banner**) comes from `RSS_ADMOB_BANNER_UNIT_ID`. Debug builds always substitute Google's test banner unit, including on physical devices; Release builds use the configured production unit.

`AdMobManager` gathers UMP consent once per app launch from a visible screen, waits for permission to request ads, then initializes the SDK once. Consent errors leave the reader usable; ads remain blocked unless UMP permits requests using existing consent. The **RSS Greece — European consent** message is published in **AdMob → Privacy & messaging** for RSS Greece only, with Greek as the default, English as an additional language, an explicit rejection option in all consent regions, and EEA/UK/Switzerland targeting. Its privacy-policy URL is `https://${FIREBASE_PROJECT_ID}.web.app/privacy`. AdMob notes that message publication can take up to an hour to propagate. Google's [UMP guide](https://developers.google.com/admob/ios/privacy) describes the account and consent setup.

When UMP requires a privacy entry point, **Απόρρητο διαφημίσεων** appears in the feed/excerpt table footer on iPhone and iPad. It reopens Google's privacy form and discards old banners after a choice. Adaptive banners resize for the current safe-area width, avoid duplicate requests on unchanged layouts, and preserve the reader's scroll position on refresh. The web article banner respects the bottom safe area and reserves matching scroll space.

RSS Greece was added to AdMob as an unpublished app because App Store lookup for `6821728687` currently returns no listing. Once the app is public, link its App Store listing and complete app verification/readiness review in AdMob before expecting unrestricted production serving. See the [AdMob app](https://admob.google.com/v2/apps/8724559947/overview).

## Privacy-policy website

The Greek/English policy is published at **https://${FIREBASE_PROJECT_ID}.web.app/privacy**, with **philipsoft@icloud.com** as the support/privacy contact. Firebase project **RSS Greece** (selected by `FIREBASE_PROJECT_ID`) contains the registered web app **RSS Greece Privacy**. The static page uses Firebase Hosting, without Firebase client SDKs or website analytics. Source is in `web/privacy.html`; `firebase.json` configures Hosting. The deployment script supplies the project explicitly from the environment. The root URL serves the Greek app website; `/en` serves its English version. Source is in `web/index.html`, `web/en.html`, and `web/site.css`. The Greek/English copyright page is at **https://${FIREBASE_PROJECT_ID}.web.app/copyright**, with source in `web/copyright.html`. Both homepage galleries include a fourth screenshot showing a full publisher article in the iPhone Duo web view, sourced from `screenshots/duo/raw/en-US/04-reading.png` and exported as `web/assets/reading-duo.jpg`. The gallery uses four columns on desktop and two on mobile.

Copy `Config/firebase.env.example` to ignored `Config/firebase.env` and set
`FIREBASE_PROJECT_ID`, or export `FIREBASE_PROJECT_ID` in your shell/CI environment.
An exported value takes precedence over the local file. No default project ID is
stored in `.firebaserc`.

Build the website and App Store metadata with resolved URLs:

```sh
python3 scripts/firebase.py build
```

Output is written to ignored `build/firebase/web` and `build/firebase/metadata`.
The checked-in HTML and metadata JSON are templates; their
`${FIREBASE_PROJECT_ID}` placeholders are replaced during the build.
To regenerate and deploy Hosting after editing the source:

```sh
python3 scripts/firebase.py deploy
```

For local Hosting emulation, run `python3 scripts/firebase.py emulate`.
Both commands build first and pass the configured project explicitly to Firebase.
The Firebase CLI requires your normal authenticated session for deployment.

The live page was checked for HTTP 200, expected headers, contact information, and exact agreement with the deployed source. Update the policy when app data practices or providers change.

## Persistence

`ArticleStore` manages a local SwiftData container on the main actor. `StoredArticle` stores article content, feed identity/order, read timestamps, and favorite state. Network refreshes update content without overwriting local reader state. Failed downloads return the last successful snapshot for that feed when available. Opening an article saves its read timestamp.

The supplied source contains no Realm models, reads, writes, or schema. Consequently there is no existing Realm data migration to run; the SwiftData cache is populated on successful feed loads. UIKit screens and storyboards are retained. A UIKit scene delegate selects the existing iPhone or iPad storyboard. `NSUserActivity` remembers the selected feed's title and URL for scene restoration, with a `UserDefaults` fallback across fresh launches. Returning to the app opens that feed's article list, without restoring an open post.

## Build and test

Production AdMob identifiers are supplied outside Git. For Xcode builds, copy
`Config/Secrets.xcconfig.example` to `Config/Secrets.xcconfig` and fill in your
production identifiers. This local file is ignored by Git. Release builds fail
if any identifier is missing, malformed, or uses Google's sample publisher.
Debug builds use Google's sample app and test ad units without local configuration.

For CI, export `RSS_ADMOB_APP_ID`, `RSS_ADMOB_BANNER_UNIT_ID`, and
`RSS_ADMOB_INTERSTITIAL_UNIT_ID` from the CI environment, then run `./build.sh`.
Exported values override local configuration. For other build commands, including
the App Store workflow, use the same wrapper:

```sh
./scripts/with-admob-env.sh asc workflow run publish-appstore-connect
```

The wrapper passes these variables to Xcode using a temporary xcconfig and removes
it when the command finishes. It does not load `.env` files automatically.
Identifiers are embedded in the app at build time so installed apps do not depend
on runtime environment variables. AdMob identifiers remain visible in the built
app; this configuration keeps production values out of tracked source files.

```sh
./build.sh build
./build.sh test 'platform=iOS Simulator,name=iPhone 18 Pro Max'
./build.sh archive
```

Choose an installed simulator for tests. Archives require your normal signing configuration. The script builds locally and does not upload or distribute releases. Tests cover RSS subscription validation, duplicate rejection, subscription persistence, article-store schema migration, menu button hit testing, malformed HTML image extraction, SwiftData disk persistence, refresh deduplication, feed isolation/order, read/favorite preservation, RSS parsing, and offline cache behavior.

Available legacy dependency artifacts are preserved under `MigrationBackup` for reference. These archives are partial and are not a complete project backup or part of the build.

Validated with Xcode 27: seventeen tests passed on the iOS 27 simulator; the unsigned iOS Release build succeeded; both iPhone and iPad storyboards launched and loaded live feeds. The app and test deployment targets are iOS 18.0. An iOS 18 simulator runtime was not installed. Existing UIKit and vendored-library deprecation warnings remain.

## Adding feeds

Tap **+** in the top toolbar, paste an HTTP/HTTPS RSS or Atom URL, and optionally enter a name. The app checks the feed, rejects duplicates, saves the subscription in SwiftData, and opens it. Added feeds remain in **Οι ροές μου** after relaunch. The toolbar uses an opaque system background and default system fonts. The iPad navigation bar also provides an add-feed button.

On iOS 27, the top toolbar hides when scrolling down and returns when scrolling up or reaching the top. Feed changes restore it. Reduce Motion disables the slide animation.

## App Store Connect

The app record is RSS Greece (`6821728687`), bundle ID `gr.phisakel.RssAppGreece`, with Greek as its primary language. Signing uses team `5T7UHW36CL`.

Use the checked-in asc workflow to archive, export an App Store IPA, upload it, wait for processing, and attach it to the version:

```sh
asc workflow validate
asc workflow run --dry-run publish-appstore-connect
asc workflow run publish-appstore-connect
```

The workflow chooses the next remote-safe build number. Archives, IPAs, and run state are ignored by Git. For subsequent runs, supply fresh artifact paths (existing artifacts are preserved):

```sh
asc workflow run publish-appstore-connect ARCHIVE_PATH:.asc/artifacts/RssReader-next.xcarchive IPA_PATH:.asc/artifacts/RssReader-next.ipa
```

A failed run with completed checkpoints can be resumed using its run ID. This workflow uploads and stages the build in App Store Connect; review submission is a separate step after completing store metadata, privacy details, and screenshots.

## Interface languages

The app supports English (`en`) and Greek (`el`), selected by iOS from the user's preferred languages or the app's language setting in Settings. English is the fallback. `RssReader/en.lproj` and `RssReader/el.lproj` contain `Localizable.strings` for Swift/UIKit/SwiftUI text and storyboard `.strings` for static controls, including **Continue reading / Συνεχίστε την ανάγνωση**. Add translations to both languages when adding interface text.

App-owned category headings are translated at display time; their configuration keys stay unchanged. Publisher names, user-created feed names, and article content remain in their source language. The RSS Greece brand name is the same in both languages. System and Google consent dialogs use the localization provided by their frameworks.

## Continue reading interstitial

AdMob unit **RSS Greece Continue Reading Interstitial** is configured through `RSS_ADMOB_INTERSTITIAL_UNIT_ID` and embedded in the built app’s `Info.plist`. `InterstitialAdsEnabled` controls this placement independently of banners. Debug builds use Google's iOS interstitial test unit (`ca-app-pub-3940256099942544/4411468910`); Release builds use the configured production unit.

Every fifth accepted **Continue reading** tap is eligible for an interstitial. The counter is shared across articles and stored in `UserDefaults`, so closing an article or restarting the app does not reset it. Ads preload after the existing UMP consent and SDK initialization flow; cached ads are discarded before expiry and whenever privacy options reopen. A ready ad presents before the article and navigation resumes once on dismissal or presentation failure. When consent is unavailable, the ad is not loaded, or presentation is unsafe, the article opens immediately; skipped ads are not deferred to another tap. Rapid repeated taps while an ad is onscreen are ignored.

The next excerpt appearance loads the next single-use ad. Implementation follows [Google's iOS interstitial guide](https://developers.google.com/admob/ios/interstitial). A new production unit may take up to an hour to begin serving, and the app's existing AdMob readiness requirements still apply.

Banner visibility is controlled globally by the Boolean **BannerAdsEnabled** in `RssReader/Info.plist` (currently `false`; a missing key also disables banners). Setting it to `true` restores the placements enabled by `HomeScreenAdsEnabled` and `DetailViewAdsEnabled` in `ReaderConf.plist`. Disabled banners make no ad requests and reserve no banner space. This switch does not disable Continue reading interstitials or their consent/privacy-options flow.

## App Store metadata

Plain English and Greek App Store copy is stored in `metadata/app-info` and `metadata/version/1.7`. It includes subtitles, descriptions, keywords, and support/privacy URL templates. Run `python3 scripts/firebase.py build`, then use the resolved files under `build/firebase/metadata` for App Store metadata validation and upload; do not upload the source templates directly. The metadata was validated and uploaded to RSS Greece version 1.7 with `asc metadata`; a follow-up dry run confirmed no differences from App Store Connect.
