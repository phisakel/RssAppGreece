// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LegacyReaderUI",
    platforms: [.iOS("18.0")],
    products: [
        .library(name: "REMenu", targets: ["REMenu"]),
        .library(name: "SWRevealViewController", targets: ["SWRevealViewController"]),
        .library(name: "FeedHTML", targets: ["FeedHTML"])
    ],
    targets: [
        .target(name: "REMenu", publicHeadersPath: "include", cSettings: [.unsafeFlags(["-fobjc-arc"])]),
        .target(name: "SWRevealViewController", publicHeadersPath: "include", cSettings: [.unsafeFlags(["-fobjc-arc"])]),
        .target(name: "FeedHTML", publicHeadersPath: "include")
    ]
)
