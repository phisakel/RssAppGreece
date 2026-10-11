# RssReader Greece

Requires Xcode 16 or newer and iOS 18.0 or newer. Open `RssReader.xcodeproj` (the workspace also opens the same project). Xcode resolves Swift Package Manager dependencies automatically; CocoaPods and Ruby are no longer required.

## Dependencies

- SDWebImage 5.21.5 and Google Mobile Ads 13.11.0 use their official SPM packages. `Package.resolved` pins the resolved versions, including Google's User Messaging Platform dependency.
- `Packages/LegacyReaderUI` packages the existing REMenu 1.10, SWRevealViewController 2.3.0, and MWFeedParser 1.0.1 HTML string helpers locally, with their licenses. These legacy sources do not provide official SPM manifests. The local menu targets enable ARC and explicitly import UIKit instead of relying on CocoaPods prefix headers.
- AFNetworking is replaced by URLSession. The unused MRProgress and UIActivityIndicator-for-SDWebImage dependencies are removed. The app already implements its own feed parser.
- The unused Realm binary, obsolete iAd framework, Pod configuration files, libraries, and build phases are removed from the project.

## Persistence

`ArticleStore` manages a local SwiftData container on the main actor. `StoredArticle` stores article content, feed identity/order, read timestamps, and favorite state. Network refreshes update content without overwriting local reader state. Failed downloads return the last successful snapshot for that feed when available. Opening an article saves its read timestamp.

The supplied source contains no Realm models, reads, writes, or schema. Consequently there is no existing Realm data migration to run; the SwiftData cache is populated on successful feed loads. UIKit screens and storyboards are retained. A UIKit scene delegate selects the existing iPhone or iPad storyboard. `NSUserActivity` remembers the selected feed's title and URL for scene restoration, with a `UserDefaults` fallback across fresh launches. Returning to the app opens that feed's article list, without restoring an open post.

## Build and test

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
