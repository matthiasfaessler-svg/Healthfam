// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HealthFamCore",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "HealthFamCore", targets: ["HealthFamCore"])
    ],
    targets: [
        .target(name: "HealthFamCore"),
        .testTarget(name: "HealthFamCoreTests", dependencies: ["HealthFamCore"])
    ]
)
