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
            name: "MUTE.ESP",
            targets: ["ESP"]
        ),
        .library(
            name: "MUTE.FSP",
            targets: ["FSP"]
        ),
        .library(
            name: "MUTE.GSP",
            targets: ["GSP"]
        ),
        .library(
            name: "MUTE.ISP",
            targets: ["ISP"]
        )
    ],
	dependencies: [
		.package(url: "https://github.com/ars-tools/muce", branch: "release"),
        .package(url: "https://github.com/ars-tools/muse", branch: "release"),
        .package(url: "https://github.com/ars-tools/muge", branch: "release"),
    ],
    targets: [
        .executableTarget(
            name: "HSP",
            dependencies: [
                "ASP",
                "BSP",
                "DSP",
                "FSP"
            ],
            path: "HSP/Sources",
            cSettings: [
                .define("ACCELERATE_NEW_LAPACK"),
                .define("ACCELERATE_LAPACK_ILP64")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "\(Context.packageDirectory)/HSP/Info.plist",
                ], .when(platforms: [.macOS])),
            ],
        ),
		.target(
			name: "ASP",
			dependencies: ["DSP", "WSP"],
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
            dependencies: ["DSP", "ESP"],
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
//        .target(
//            name: "CSP",
//            path: "KSP/Sources",
//            publicHeadersPath: ".",
//            cSettings: [
//                .define("ACCELERATE_NEW_LAPACK"),
//                .define("ACCELERATE_LAPACK_ILP64")
//            ]
//        ),
//        .testTarget(
//            name: "CSPTests",
//            dependencies: ["CSP"],
//            path: "KSP/Tests",
//            cSettings: [
//                .define("ACCELERATE_NEW_LAPACK"),
//                .define("ACCELERATE_LAPACK_ILP64")
//            ]
//        ),
		.target(
			name: "DSP",
			dependencies: [
                "KSP",
                "ESP",
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
                .product(name: "MUSE.Algorithms", package: "MUSE"),
                "KSP",
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
			name: "KSP",
            dependencies: [
                .product(name: "MUSE.Essentials", package: "MUSE"),
            ],
			path: "KSP/Sources",
			publicHeadersPath: ".",
			cSettings: [
				.define("ACCELERATE_NEW_LAPACK"),
				.define("ACCELERATE_LAPACK_ILP64")
			]
		),
		.testTarget(
			name: "KSPTests",
			dependencies: [
				"KSP",
				.product(name: "MUSE.Primitives", package: "MUSE"),
			],
			path: "KSP/Tests",
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
        .target(
            name: "GSP",
            dependencies: [
                "DSP",
                .product(name: "MUGE.Artwork", package: "MUGE")
            ],
            path: "GSP/Sources",
            resources: [.process("Visualise.metal")],
            cSettings: [
                .define("ACCELERATE_NEW_LAPACK"),
                .define("ACCELERATE_LAPACK_ILP64")
            ],
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
        .target(
            name: "ISP",
            dependencies: ["DSP", "ESP", "FSP"],
            path: "ISP/Sources",
            cSettings: [
                .define("ACCELERATE_NEW_LAPACK"),
                .define("ACCELERATE_LAPACK_ILP64")
            ]
        ),
        .testTarget(
            name: "ISPTests",
            dependencies: [
                "ISP",
                "ESP",
                "KSP",
            ],
            path: "ISP/Tests",
            cSettings: [
                .define("ACCELERATE_NEW_LAPACK"),
                .define("ACCELERATE_LAPACK_ILP64")
            ]
        ),
		// Symbolic OPS
		.target(
			name: "WSP",
			dependencies: [],
			path: "WSP/Sources"
		),
		.testTarget(
			name: "WSPTests",
			dependencies: ["WSP"],
			path: "WSP/Tests",
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
                "KSP",
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
