// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Shapeshift",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ConversionCore", targets: ["ConversionCore"]),
        .library(name: "EditCore", targets: ["EditCore"]),
        .executable(name: "Shapeshift", targets: ["Shapeshift"]),
    ],
    targets: [
        .target(name: "ConversionCore"),
        .target(name: "EditCore", dependencies: ["ConversionCore"]),
        .target(name: "ShapeshiftApp", dependencies: ["ConversionCore", "EditCore"]),
        .executableTarget(name: "Shapeshift", dependencies: ["ShapeshiftApp"]),
        .testTarget(name: "ConversionCoreTests", dependencies: ["ConversionCore"]),
        .testTarget(name: "EditCoreTests", dependencies: ["EditCore", "ConversionCore"]),
        .testTarget(name: "ShapeshiftAppTests", dependencies: ["ShapeshiftApp", "ConversionCore", "EditCore"]),
    ],
    swiftLanguageModes: [.v5]
)
