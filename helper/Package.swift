// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "saft-helper",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "saft-helper",
            path: "Sources/saft-helper"
        )
    ]
)
