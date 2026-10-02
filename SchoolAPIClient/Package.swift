// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SchoolAPIClient",
    platforms: [.iOS(.v15), .macOS(.v13)],
    products: [
        .library(name: "SchoolAPIClient", targets: ["SchoolAPIClient"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "SchoolAPIClient",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
            ],
            path: "Sources/SchoolAPIClient",
            sources: ["."], // ✅ Важно: включить все файлы, включая Generated/
            resources: []
        ),
        .executableTarget(
            name: "SchoolAPIDemo",
            dependencies: ["SchoolAPIClient"],
            path: "Sources/SchoolAPIDemo"
        ),
    ]
)