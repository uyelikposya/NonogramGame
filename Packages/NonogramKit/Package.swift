// swift-tools-version: 5.10
import PackageDescription

// Oyun motoru UI'dan bağımsız tutulur: yalnızca Foundation kullanır,
// böylece `swift test` ile Xcode/simülatör açmadan test edilebilir.
let package = Package(
    name: "NonogramKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NonogramKit", targets: ["NonogramKit"]),
    ],
    targets: [
        .target(name: "NonogramKit"),
        .testTarget(name: "NonogramKitTests", dependencies: ["NonogramKit"]),
    ]
)
