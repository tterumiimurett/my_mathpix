// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MyMathpix",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "MyMathpix", targets: ["MyMathpix"])
    ],
    targets: [
        .executableTarget(
            name: "MyMathpix",
            resources: [.copy("Resources")]
        )
    ],
    swiftLanguageModes: [.v5]
)
