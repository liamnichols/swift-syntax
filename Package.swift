// swift-tools-version:5.3

import PackageDescription
import Foundation

let package = Package(
  name: "SwiftSyntax",
  targets: [
    .target(name: "_CSwiftSyntax"),
    .testTarget(name: "SwiftSyntaxTest", dependencies: ["SwiftSyntax"], exclude: ["Inputs"]),
    .target(name: "SwiftSyntaxBuilder", dependencies: ["SwiftSyntax"]),
    .testTarget(name: "SwiftSyntaxBuilderTest", dependencies: ["SwiftSyntaxBuilder"]),
    .target(name: "lit-test-helper", dependencies: ["SwiftSyntax"]),
    .testTarget(name: "PerformanceTest", dependencies: ["SwiftSyntax"])
    // Also see targets added below
  ]
)

// Include the parser library as a binary dependency if both the host and the target are macOS.
//  - We need to require that the host is macOS (checked by `#if os(macOS)`) because package resolve will download and unzip the referenced framework, which requires `unzip` to be installed. Only macOS guarantees that `unzip` is installed, the Swift Docker images don’t have unzip installed, so package resolve would fail.
//  - We need to require that the target is macOS (checked by `.when`) because binary dependencies are only supported by SwiftPM on macOS.
#if os(macOS)
let parserLibraryTargets: [Target] = [.binaryTarget(
  name: "lib_InternalSwiftSyntaxParser",
  url: "https://github.com/keith/StaticInternalSwiftSyntaxParser/releases/download/5.5.2/lib_InternalSwiftSyntaxParser.xcframework.zip",
  checksum: "96bbc9ab4679953eac9ee46778b498cb559b8a7d9ecc658e54d6679acfbb34b8"
)]
let parserLibraryDependency: [Target.Dependency] = [.target(name: "lib_InternalSwiftSyntaxParser", condition: .when(platforms: [.macOS]))]
#else
let parserLibraryTargets: [Target] = []
let parserLibraryDependency: [Target.Dependency] = []
#endif

let swiftSyntaxTarget: PackageDescription.Target

/// If we are in a controlled CI environment, we can use internal compiler flags
/// to speed up the build or improve it.
if ProcessInfo.processInfo.environment["SWIFT_BUILD_SCRIPT_ENVIRONMENT"] != nil {
  let groupFile = URL(fileURLWithPath: #file)
    .deletingLastPathComponent()
    .appendingPathComponent("utils")
    .appendingPathComponent("group.json")

  var swiftSyntaxUnsafeFlags = ["-Xfrontend", "-group-info-path",
                                "-Xfrontend", groupFile.path]
  // Enforcing exclusivity increases compile time of release builds by 2 minutes.
  // Disable it when we're in a controlled CI environment.
  swiftSyntaxUnsafeFlags += ["-enforce-exclusivity=unchecked"]

  swiftSyntaxTarget = .target(name: "SwiftSyntax", dependencies: ["_CSwiftSyntax"] + parserLibraryDependency,
                              swiftSettings: [.unsafeFlags(swiftSyntaxUnsafeFlags)]
  )
} else {
  swiftSyntaxTarget = .target(name: "SwiftSyntax", dependencies: ["_CSwiftSyntax"] + parserLibraryDependency)
}

package.targets.append(contentsOf: parserLibraryTargets)
package.targets.append(swiftSyntaxTarget)

let libraryType: Product.Library.LibraryType

/// When we're in a build-script environment, we want to build a dylib instead
/// of a static library since we install the dylib into the toolchain.
if ProcessInfo.processInfo.environment["SWIFT_BUILD_SCRIPT_ENVIRONMENT"] != nil {
  libraryType = .dynamic
} else {
  libraryType = .static
}

package.products.append(.library(name: "SwiftSyntax", type: libraryType, targets: ["SwiftSyntax"]))
package.products.append(.library(name: "SwiftSyntaxBuilder", type: libraryType, targets: ["SwiftSyntaxBuilder"]))
