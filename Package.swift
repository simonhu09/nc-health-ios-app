// swift-tools-version: 5.9
// SPDX-License-Identifier: AGPL-3.0-or-later
import PackageDescription
let package = Package(name: "HealthJournal", platforms: [.iOS(.v17)], products: [.library(name: "HealthCore", targets: ["HealthCore"])], targets: [.target(name: "HealthCore"), .testTarget(name: "HealthCoreTests", dependencies: ["HealthCore"])])
