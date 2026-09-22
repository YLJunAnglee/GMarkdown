// swift-tools-version: 5.10

import PackageDescription

// A build-only host that proves the delivery folder can be consumed by a
// clean iOS target without the demo application.
let package = Package(
    name: "GMarkdownMinimalHost",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "GMarkdownMinimalHost", targets: ["GMarkdownMinimalHost"]),
    ],
    dependencies: [
        .package(path: "../../Delivery/GMarkdown-0.1.1"),
    ],
    targets: [
        .target(
            name: "GMarkdownMinimalHost",
            dependencies: [
                .product(name: "GMarkdown", package: "GMarkdown-0.1.1"),
            ],
            path: ".",
            exclude: ["README.md"],
            sources: ["MinimalReaderViewController.swift"]
        ),
    ]
)
