// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "opencv2",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(
            name: "opencv2",
            targets: ["opencv2"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "opencv2",
            path: "./opencv2.xcframework"
        ),
    ]
)
