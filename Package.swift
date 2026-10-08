// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FinderHelper",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FinderHelperCore", targets: ["FinderHelperCore"]),
        .executable(name: "FinderHelper", targets: ["FinderHelper"])
    ],
    targets: [
        .target(name: "FinderHelperCore", path: "Sources/FinderHelperCore"),
        .executableTarget(
            name: "FinderHelper",
            dependencies: ["FinderHelperCore"],
            path: "Sources/FinderHelper",
            linkerSettings: [.linkedFramework("Cocoa"), .linkedFramework("FinderSync")]
        ),
        .testTarget(
            name: "FinderHelperCoreTests",
            dependencies: ["FinderHelperCore"],
            path: "Tests/FinderHelperCoreTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
