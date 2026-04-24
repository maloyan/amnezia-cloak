// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AmneziaCloak",
    platforms: [.macOS(.v11)],
    products: [
        .executable(name: "AmneziaCloak", targets: ["AmneziaCloakApp"]),
        .library(name: "AmneziaCloakCore", targets: ["AmneziaCloakCore"]),
    ],
    targets: [
        .target(name: "AmneziaCloakCore"),
        .executableTarget(
            name: "AmneziaCloakApp",
            dependencies: ["AmneziaCloakCore"]
        ),
        .testTarget(
            name: "AmneziaCloakCoreTests",
            dependencies: ["AmneziaCloakCore"]
        ),
    ]
)
