// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacScope",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MacScope", targets: ["MacScope"])
    ],
    targets: [
        .executableTarget(
            name: "MacScope",
            path: "MacScope"
        ),
        .testTarget(
            name: "MacScopeTests",
            dependencies: ["MacScope"],
            path: "MacScopeTests"
        )
    ]
)
