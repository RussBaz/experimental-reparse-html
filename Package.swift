// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "experimental-reparse-html",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "reparse", targets: ["reparse"]),
        .library(name: "ReparseRuntime", targets: ["ReparseRuntime"]),
        .plugin(name: "ReparsePlugin", targets: ["ReparsePlugin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.106.0"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "ReparseExample",
            dependencies: [
                .product(name: "Leaf", package: "leaf"),
                .product(name: "Vapor", package: "vapor"),
                .target(name: "ReparseRuntime"),
            ],
            path: "./Sources/Example",
            swiftSettings: swiftSettings
        ),
        .target(name: "ReparseRuntime", path: "./Sources/Runtime", swiftSettings: swiftSettings),
        .target(
            name: "ReparseCore", dependencies: [
                .target(name: "ReparseRuntime"),
            ],
            path: "./Sources/Core",
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "reparse",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .target(name: "ReparseCore"),
            ], path: "./Sources/Tool",
            swiftSettings: swiftSettings
        ),
        .plugin(
            name: "ReparsePlugin",
            capability: .command(
                intent: .custom(verb: "reparse", description: "This command will compile the html templates into the source code."),
                permissions: [
                    .writeToPackageDirectory(reason: "This command (re)compiles the html templates."),
                ]
            ),
            dependencies: [
                .target(name: "reparse"),
            ]
        ),
        .testTarget(
            name: "ExampleTests",
            dependencies: [
                .target(name: "ReparseExample"),
                .product(name: "XCTVapor", package: "vapor"),

                // Workaround for https://github.com/apple/swift-package-manager/issues/6940
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Leaf", package: "leaf"),
            ],
            resources: [
                .copy("Views"),
            ],
            swiftSettings: swiftSettings
        ),
    ]
)

let swiftSettings: [SwiftSetting] = [
    // Flags to enable Swift 6 compatibility
    .enableUpcomingFeature("BareSlashRegexLiterals"),
    .enableUpcomingFeature("ConciseMagicFile"),
    .enableUpcomingFeature("ForwardTrailingClosures"),
    .enableUpcomingFeature("ImportObjcForwardDeclarations"),
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("DeprecateApplicationMain"),
    .enableUpcomingFeature("GlobalConcurrency"),
    .enableUpcomingFeature("IsolatedDefaultValues"),
    .enableExperimentalFeature("StrictConcurrency"),
    // Flags to warn about the type checking getting too slow
    .unsafeFlags(
        [
            "-Xfrontend",
            "-warn-long-function-bodies=100",
            "-Xfrontend",
            "-warn-long-expression-type-checking=100",
        ]
    ),
]
