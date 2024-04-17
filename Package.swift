// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MiseboxFirebase_pkg",
    platforms: [
       .iOS(.v16)  // Set this to at least iOS 16
    ],
    products: [
        .library(
            name: "MiseboxFirebase_pkg",
            targets: ["MiseboxFirebase_pkg"]),
    ],
    dependencies: [
        // Firebase SDK
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.23.1"),
        // Google Sign-In SDK
        .package(url: "https://github.com/google/GoogleSignIn-iOS.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "MiseboxFirebase_pkg",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                .product(name: "GoogleSignInSwift", package: "GoogleSignIn-iOS"),
            ]),
        .testTarget(
            name: "MiseboxFirebase_pkgTests",
            dependencies: ["MiseboxFirebase_pkg"]),
    ]
)
