// swift-tools-version: 5.10

import PackageDescription

// Build-verification manifest for this source-folder delivery. It uses only
// the bundled dependency sources; it does not change the public integration
// contract, which remains an independent framework target in Xcode.
let package = Package(
    name: "GMarkdownDelivery",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "GMarkdown", targets: ["GMarkdown"]),
    ],
    dependencies: [
        .package(path: "Dependencies/swift-cmark"),
        .package(path: "Dependencies/MPITextKit"),
        .package(path: "Dependencies/SwiftMath"),
        .package(path: "Dependencies/MathJaxSwift"),
    ],
    targets: [
        .target(
            name: "GMarkdown",
            dependencies: [
                "Markdown",
                .product(name: "MPITextKit", package: "MPITextKit"),
                .product(name: "SwiftMath", package: "SwiftMath"),
                .product(name: "MathJaxSwift", package: "MathJaxSwift"),
            ],
            path: "Sources",
            resources: [
                .copy("Assets/Highlighter/highlight.min.js"),
                .copy("Assets/styles"),
            ]
        ),
        .target(
            name: "Markdown",
            dependencies: [
                "CAtomic",
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark"),
            ],
            path: "Dependencies/swift-markdown/Sources/Markdown"
        ),
        .target(
            name: "CAtomic",
            path: "Dependencies/swift-markdown/Sources/CAtomic"
        ),
    ]
)
