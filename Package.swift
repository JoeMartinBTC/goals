// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Goals",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "GoalsCore", path: "Sources/GoalsCore"),
        .executableTarget(name: "Goals", dependencies: ["GoalsCore"], path: "Sources/Goals"),
        .testTarget(name: "GoalsCoreTests", dependencies: ["GoalsCore"], path: "Tests/GoalsCoreTests"),
    ]
)
