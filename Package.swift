// swift-tools-version:5.9
import PackageDescription

// This package exists so the editor's pure, Foundation-only logic
// (HTMLEditor/HTMLEditor/Core) can be unit-tested from the command line with
// `swift test`, independent of the macOS app target. The library target points
// directly at the same source files the Xcode app compiles, so there is a
// single source of truth and no duplication.
let package = Package(
    name: "HTMLEditorCore",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "HTMLEditorCore", targets: ["HTMLEditorCore"])
    ],
    targets: [
        .target(
            name: "HTMLEditorCore",
            path: "HTMLEditor/HTMLEditor/Core"
        ),
        .testTarget(
            name: "HTMLEditorCoreTests",
            dependencies: ["HTMLEditorCore"],
            path: "Tests/HTMLEditorCoreTests"
        )
    ]
)
