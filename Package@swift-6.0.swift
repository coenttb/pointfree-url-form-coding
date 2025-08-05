// swift-tools-version:6.0

import PackageDescription

extension String {
    static let urlFormCoding: Self = "PointFreeURLFormCoding"
}

extension Target.Dependency {
    static var urlFormCoding: Self { .target(name: .urlFormCoding) }
}

let package = Package(
    name: "pointfree-url-form-coding",
    products: [
        .library(name: .urlFormCoding, targets: [.urlFormCoding])
    ],
    dependencies: [],
    targets: [
        .target(
            name: .urlFormCoding,
            dependencies: []
        ),
        .testTarget(
            name: .urlFormCoding.tests,
            dependencies: [.urlFormCoding]
        )
    ],
    swiftLanguageModes: [.v6]
)

extension String { var tests: Self { self + " Tests" } }
