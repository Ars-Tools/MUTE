// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription
let package = Package(
    name: "MUTE",
	platforms: [
        .iOS(.v26),
		.tvOS(.v26),
		.macCatalyst(.v26),
		.macOS(.v26)
	],
    products: [
        .library(
            name: "MUTE.ASP",
            targets: ["ASP"]
		),.library(
            name: "MUTE.BSP",
            targets: ["BSP"]
        ),
        .library(
            name: "MUTE.DSP",
            targets: ["DSP"]
        ),
        .library(
            name: "MUTE.FSP",
            targets: ["FSP"]
        ),
        .library(
            name: "MUTE.GSP",
            targets: ["GSP"]
        )
    ],
	dependencies: [
		.package(url: "https://github.com/ars-tools/muce", branch: "release"),
        .package(url: "https://github.com/ars-tools/muse", branch: "release"),
        .package(url: "https://github.com/ars-tools/muge", branch: "release"),
	],
    targets: [
        .executableTarget(
            name: "ASPStage",
            dependencies: [
                "ASP",
                "PSP",
                "NSP",
            ],
            path: "ASP/Stage",
            cSettings: [
                .define("ACCELERATE_NEW_LAPACK"),
                .define("ACCELERATE_LAPACK_ILP64"),
            ]
        ),
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
            dependencies: ["ASP", "BSP", "FSP"],
			path: "ASP/Tests",
            cSettings: [
                .define("ACCELERATE_NEW_LAPACK"),
                .define("ACCELERATE_LAPACK_ILP64")
            ]
		),
        .target(
            name: "BSP",
            dependencies: ["DSP"],
            path: "BSP/Sources",
            cSettings: [
                .define("ACCELERATE_NEW_LAPACK"),
                .define("ACCELERATE_LAPACK_ILP64")
            ]
        ),
        .testTarget(
            name: "BSPTests",
            dependencies: ["BSP"],
            path: "BSP/Tests",
            cSettings: [
                .define("ACCELERATE_NEW_LAPACK"),
                .define("ACCELERATE_LAPACK_ILP64")
            ]
        ),
		.target(
			name: "DSP",
			dependencies: [
				"NSP",
				.product(name: "MUSE.Primitives", package: "MUSE"),
				.product(name: "MUSE.Essentials", package: "MUSE"),
				.product(name: "MUCE.Auxiliary", package: "MUCE"),
				.product(name: "MUCE.Chrono", package: "MUCE"),
			],
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
            path: "DSP/Tests",
            cSettings: [
                .define("ACCELERATE_NEW_LAPACK"),
                .define("ACCELERATE_LAPACK_ILP64")
            ]
        ),
        .target(
            name: "ESP",
            dependencies: [
                .product(name: "MUSE.Primitives", package: "MUSE"),
                .product(name: "MUSE.Essentials", package: "MUSE"),
                "NSP",
            ],
            path: "ESP/Sources",
            cSettings: [
                .define("ACCELERATE_NEW_LAPACK"),
                .define("ACCELERATE_LAPACK_ILP64")
            ]
        ),
        .testTarget(
            name: "ESPTests",
            dependencies: ["ESP"],
            path: "ESP/Tests",
            cSettings: [
                .define("ACCELERATE_NEW_LAPACK"),
                .define("ACCELERATE_LAPACK_ILP64")
            ]
        ),
		.target(
			name: "NSP",
            dependencies: [
                .product(name: "MUSE.Essentials", package: "MUSE"),
            ],
			path: "NSP/Sources",
			publicHeadersPath: ".",
			cSettings: [
				.define("ACCELERATE_NEW_LAPACK"),
				.define("ACCELERATE_LAPACK_ILP64")
			]
		),
		.testTarget(
			name: "NSPTests",
			dependencies: [
				"NSP",
				.product(name: "MUSE.Primitives", package: "MUSE"),
			],
			path: "NSP/Tests",
            cSettings: [
                .define("ACCELERATE_NEW_LAPACK"),
                .define("ACCELERATE_LAPACK_ILP64")
            ],
		),
		.target(
			name: "FSP",
			dependencies: [
                "DSP", 
                "ESP",
                .product(name: "MUSE.Algorithms", package: "MUSE"),
            ],
			path: "FSP/Sources",
			cSettings: [
				.define("ACCELERATE_NEW_LAPACK"),
				.define("ACCELERATE_LAPACK_ILP64")
			]
		),
		.testTarget(
			name: "FSPTests",
			dependencies: [
				"FSP",
				.product(name: "MUSE.Primitives", package: "MUSE"),
				.product(name: "MUCE.Auxiliary", package: "MUCE"),
			],
			path: "FSP/Tests",
            cSettings: [
                .define("ACCELERATE_NEW_LAPACK"),
                .define("ACCELERATE_LAPACK_ILP64")
            ]
		),
        .executableTarget(
            name: "GSPPreview",
            dependencies: [
                "GSP",
                .product(name: "MUGE.Artwork", package: "MUGE")
            ],
            path: "GSP/Preview",
            cSettings: [
                .define("ACCELERATE_NEW_LAPACK"),
                .define("ACCELERATE_LAPACK_ILP64")
            ]
        ),
        .target(
            name: "GSP",
            dependencies: ["DSP", .product(name: "MUGE.Artwork", package: "MUGE")],
            path: "GSP/Sources",
            cSettings: [
                .define("ACCELERATE_NEW_LAPACK"),
                .define("ACCELERATE_LAPACK_ILP64")
            ]
        ),
        .testTarget(
            name: "GSPTests",
            dependencies: [
                "GSP",
            ],
            path: "GSP/Tests",
            cSettings: [
                .define("ACCELERATE_NEW_LAPACK"),
                .define("ACCELERATE_LAPACK_ILP64")
            ]
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
			path: "MIDI/Tests",
            cSettings: [
                .define("ACCELERATE_NEW_LAPACK"),
                .define("ACCELERATE_LAPACK_ILP64")
            ]
		),
        //
        .target(
            name: "PSP",
            dependencies: [
                "DSP",
                "NSP",
                .product(name: "MUSE.Essentials", package: "MUSE"),
                .product(name: "MUCE.Auxiliary", package: "MUCE"),
            ],
            path: "PSP/Sources",
            cSettings: [
                .define("ACCELERATE_NEW_LAPACK"),
                .define("ACCELERATE_LAPACK_ILP64")
            ]
        ),
        .testTarget(
            name: "PSPTests",
            dependencies: ["PSP"],
            path: "PSP/Tests",
            cSettings: [
                .define("ACCELERATE_NEW_LAPACK"),
                .define("ACCELERATE_LAPACK_ILP64")
            ]
        )
    ]
)

