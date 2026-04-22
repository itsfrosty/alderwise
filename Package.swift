// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Alderwise",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(name: "AlderwiseApp", targets: ["AlderwiseApp"]),
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Application", targets: ["Application"]),
        .library(name: "Persistence", targets: ["Persistence"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "AlderwiseApp",
            dependencies: [
                "Application",
                "Domain",
                "Persistence",
            ],
            path: "Sources/AlderwiseApp"
        ),
        .target(
            name: "Domain",
            path: "Sources/Domain"
        ),
        .target(
            name: "Application",
            dependencies: [
                "Domain",
                "Persistence",
            ],
            path: "Sources/Application"
        ),
        .target(
            name: "Persistence",
            dependencies: [
                "Domain",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/Persistence"
        ),
        .testTarget(
            name: "DomainTests",
            dependencies: ["Domain"],
            path: "Tests/DomainTests"
        ),
        .testTarget(
            name: "ApplicationTests",
            dependencies: ["Application", "Domain", "Persistence"],
            path: "Tests/ApplicationTests"
        ),
        .testTarget(
            name: "AlderwiseAppTests",
            dependencies: ["AlderwiseApp", "Application", "Domain"],
            path: "Tests/AlderwiseAppTests"
        ),
        .testTarget(
            name: "PersistenceTests",
            dependencies: [
                "Persistence",
                "Domain",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Tests/PersistenceTests"
        ),
    ]
)
