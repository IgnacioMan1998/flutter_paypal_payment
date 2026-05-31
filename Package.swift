// swift-tools-version:5.9
// Package.swift — Swift Package Manager manifest for paypal_checkout_flutter.
//
// Supports both CocoaPods (via paypal_checkout_flutter.podspec) and SPM.
// Requires Xcode 16+ and Swift 5.9+.
//
// PayPal iOS SDK SPM: https://github.com/paypal/paypal-ios
import PackageDescription

let package = Package(
    name: "paypal_checkout_flutter",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "paypal-checkout-flutter",
            targets: ["paypal_checkout_flutter"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/paypal/paypal-ios",
            from: "2.0.0"
        ),
    ],
    targets: [
        .target(
            name: "paypal_checkout_flutter",
            dependencies: [
                .product(name: "CorePayments", package: "paypal-ios"),
                .product(name: "CardPayments", package: "paypal-ios"),
                .product(name: "PayPalWebPayments", package: "paypal-ios"),
            ],
            path: "ios/Classes",
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("."),
            ]
        ),
    ]
)
