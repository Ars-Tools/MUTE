// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription
let package = Package(
    name: "MUTE",
	platforms: [
		.iOS(.v18),
		.tvOS(.v18),
		.macCatalyst(.v18),
		.macOS(.v15)
	],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MUTE-Library",
            targets: ["ASP"]
		),
		.library(
			name: "MUTE-DSP",
			targets: ["DSP"]
		),
		.library(
			name: "MUTE-VSP",
			targets: ["VSP"]
		)
    ],
	dependencies: [
		.package(url: "https://github.com/ars-tools/muse", branch: "release"),
		.package(url: "https://github.com/ars-tools/muce", branch: "release"),
	],
    targets: [
		.target(
			name: "ASP",
			dependencies: ["DSP", "MIDI"],
			path: "ASP/Sources",
			cSettings: [
				.define("ACCELERATE_NEW_LAPACK"),
				.define("ACCELERATE_LAPACK_ILP64")
			]
		),
		.testTarget(
			name: "ASPTests",
			dependencies: ["ASP"],
			path: "ASP/Tests"
		),
		.target(
			name: "DSP",
			dependencies: ["VSP",
						   .product(name: "MUSE.Primitives", package: "MUSE"),
						   .product(name: "MUSE.Essentials", package: "MUSE"),
						   .product(name: "MUCE.Chrono", package: "MUCE")],
			path: "DSP/Sources",
			cSettings: [
				.define("ACCELERATE_NEW_LAPACK"),
				.define("ACCELERATE_LAPACK_ILP64")
			],
			swiftSettings: [
				.unsafeFlags(["-Xfrontend", "-debug-time-function-bodies"]),
			]
		),
		.testTarget(
			name: "DSPTests",
			dependencies: ["DSP"],
			path: "DSP/Tests"
		),
		.target(
			name: "VSP",
			path: "VSP/Sources",
			publicHeadersPath: ".",
			cSettings: [
				.define("ACCELERATE_NEW_LAPACK"),
				.define("ACCELERATE_LAPACK_ILP64")
			]
		),
		.testTarget(
			name: "VSPTests",
			dependencies: ["VSP"],
			path: "VSP/Tests"
		),
		.target(
			name: "FSP",
			dependencies: ["DSP", "VSP"],
			path: "FSP/Sources",
			cSettings: [
				.define("ACCELERATE_NEW_LAPACK"),
				.define("ACCELERATE_LAPACK_ILP64")
			]
		),
		.testTarget(
			name: "FSPTests",
			dependencies: ["FSP"],
			path: "FSP/Tests"
		),
		// Symbolic OPS
		.target(
			name: "MIDI",
			dependencies: [],
			path: "MIDI/Sources"
		),
		.testTarget(
			name: "MIDITests",
			dependencies: ["MIDI"],
			path: "MIDI/Tests"
		),
    ]
)
