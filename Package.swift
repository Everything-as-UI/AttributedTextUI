// swift-tools-version: 5.7

import PackageDescription

let dependencies: [Package.Dependency]

if Context.environment["ALLUI_ENV"] == "LOCAL" {
    dependencies = [.package(name: "DocumentUI", path: "../DocumentUI")]
} else {
    dependencies = [
        .package(url: "https://github.com/Everything-as-UI/DocumentUI.git", branch: "main")
    ]
}

let package = Package(
    name: "AttributedTextUI",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
    products: [
        .library(name: "AttributedTextUI", targets: ["AttributedTextUI"])
    ],
    dependencies: dependencies,
    targets: [
        .target(name: "AttributedTextUI",
                dependencies: ["DocumentUI"],
                exclude: ["AttributedTextBuilders.swift.gyb.swift"]),
        .testTarget(name: "AttributedTextUITests", dependencies: ["AttributedTextUI"])
    ]
)
