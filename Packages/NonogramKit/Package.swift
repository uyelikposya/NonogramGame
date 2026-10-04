// swift-tools-version: 5.9
import PackageDescription

// Oyun motoru UI'dan bağımsız tutulur: yalnızca Foundation kullanır,
// böylece `swift test` ile Xcode/simülatör açmadan test edilebilir.
// Xcode 15.2 (Swift 5.9) ve macOS Ventura ile uyumlu tutulur.
let package = Package(
    name: "NonogramKit",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "NonogramKit", targets: ["NonogramKit"]),
    ],
    targets: [
        .target(name: "NonogramKit"),
        .testTarget(name: "NonogramKitTests", dependencies: ["NonogramKit"]),
    ]
)
