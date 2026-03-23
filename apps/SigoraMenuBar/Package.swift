// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SigoraMenuBar",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "SigoraMenuBar", targets: ["SigoraMenuBar"]),
    ],
    targets: [
        .executableTarget(
            name: "SigoraMenuBar",
            path: "SigoraMenuBar"
        ),
    ]
)
