// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Harold",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Harold", targets: ["Harold"])],
    targets: [.executableTarget(name: "Harold", resources: [.copy("Resources/Readability.js"), .copy("Resources/Readability-LICENSE.md")])]
)
