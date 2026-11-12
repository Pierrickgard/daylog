// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Daylog",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Daylog", path: "Sources/Daylog")
    ]
)
