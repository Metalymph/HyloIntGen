// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "HyloIntGen",
  products: [
    .library(
      name: "HyloIntGen",
      targets: ["HyloIntGen"])
  ],
  targets: [
    .target(
      name: "HyloIntGen"),
    .testTarget(
      name: "HyloIntGenTests",
      dependencies: ["HyloIntGen"],
      resources: [
        .copy("Templates")
      ]
    ),
  ]
)
