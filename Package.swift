// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let dependencies: [Package.Dependency]

let env = Context.environment["USER"]
let isDevelop = env == "K-o-D-e-N"
if isDevelop {
    dependencies = [
        .package(name: "DocumentUI", path: "../DocumentUI"),
    ]
} else {
    dependencies = [
        .package(url: "https://github.com/Everything-as-UI/DocumentUI.git", branch: "main")
    ]
}

let package = Package(
    name: "AttributedTextUI",
    platforms: [.macOS(.v12), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
    products: [
        .library(name: "AttributedTextUI", targets: ["AttributedTextUI"])
    ],
    dependencies: dependencies,
    targets: [
        .target(name: "AttributedTextUI", dependencies: ["DocumentUI"], exclude: ["AttributedTextBuilders.swift.gyb.swift"])
    ]
)