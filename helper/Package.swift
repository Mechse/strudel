// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "strudel-helper",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "strudel-helper",
            path: "Sources/strudel-helper"
        )
    ]
)
