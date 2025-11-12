// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "pointfree-url-form-coding",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "PointFreeURLFormCoding", targets: ["PointFreeURLFormCoding"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-standards/swift-whatwg-url-encoding", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "PointFreeURLFormCoding",
            dependencies: [
                .product(name: "WHATWG URL Encoding", package: "swift-whatwg-url-encoding")
            ]
        ),
        .testTarget(
            name: "PointFreeURLFormCoding Tests",
            dependencies: ["PointFreeURLFormCoding"]
        )
    ]
)
