// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DeepamCore",
    platforms: [.iOS(.v17), .macOS(.v14), .watchOS(.v10)],
    products: [
        .library(name: "DeepamCore", targets: ["DeepamCore"]),
        .library(name: "DeepamPurchases", targets: ["DeepamPurchases"]),
        .library(name: "DeepamUI", targets: ["DeepamUI"]),
        .library(name: "DeepamWidgets", targets: ["DeepamWidgets"]),
    ],
    dependencies: [
        // Отдельный SPM-зеркальный репозиторий: основной покупается ещё и через
        // CocoaPods, и в нём лишние цели, которые SPM пытается собрать.
        .package(url: "https://github.com/RevenueCat/purchases-ios-spm.git", from: "5.14.0"),
    ],
    targets: [
        // Движок и данные. Изоляции не навязывает: его линкуют и приложение,
        // и расширения виджета, каждый со своими правилами.
        .target(name: "DeepamCore", resources: [.process("Resources")]),

        // Интерфейс. Главный актор по умолчанию — это UI-модуль, и почти весь
        // его код и так обязан жить на главном потоке.
        .target(
            name: "DeepamUI",
            dependencies: ["DeepamCore"],
            resources: [.process("Resources")],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),

        // Виджеты. Содержимое целиком под `#if os(iOS)`: WidgetKit на маке
        // есть не весь, а тесты гоняются именно там.
        // Зависимость от DeepamUI нужна ради общих фонов: картинки лежат в её
        // ресурсах, и обращаться к ним из чужого бандла нельзя.
        .target(
            name: "DeepamWidgets",
            dependencies: ["DeepamCore", "DeepamUI"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),

        // Покупки живут отдельно от интерфейса намеренно. `DeepamUI` линкует
        // расширение виджета, и RevenueCat уехал бы в него следом — расширению
        // он не нужен ни на грамм, а лимит памяти у виджета жёсткий.
        .target(
            name: "DeepamPurchases",
            dependencies: [
                "DeepamCore",
                .product(name: "RevenueCat", package: "purchases-ios-spm"),
                .product(name: "RevenueCatUI", package: "purchases-ios-spm"),
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),

        .testTarget(name: "DeepamCoreTests", dependencies: ["DeepamCore"]),
        .testTarget(
            name: "DeepamUITests",
            dependencies: ["DeepamUI", "DeepamCore"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ]
)
