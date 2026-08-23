// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacScope",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MacScope", targets: ["MacScope"]),
        .executable(name: "MacScopeGPUHelper", targets: ["MacScopeGPUHelper"])
    ],
    targets: [
        .executableTarget(
            name: "MacScope",
            dependencies: ["MacScopeHelperShared"],
            path: "MacScope"
        ),
        .target(name: "MacScopeHelperShared", path: "MacScopeHelperShared"),
        .executableTarget(
            name: "MacScopeGPUHelper",
            dependencies: ["MacScopeHelperShared"],
            path: "MacScopeGPUHelper"
        ),
        .testTarget(
            name: "MacScopeTests",
            dependencies: ["MacScope", "MacScopeHelperShared"],
            path: "MacScopeTests"
        )
    ]
)
