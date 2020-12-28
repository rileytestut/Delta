import ProjectDescription

let project = Project(name: "DeltaCore",
                      packages: [
                        .remote(url: "https://github.com/rileytestut/ZIPFoundation", requirement: .branch("development")),
                      ],
                      targets: [
                        Target(name: "DeltaCore",
                               platform: .iOS,
                               product: .framework,
                               bundleId: "com.rileytestut.DeltaCore",
                               deploymentTarget: .iOS(targetVersion: "12.0", devices: [.iphone, .ipad]),
                               infoPlist: .extendingDefault(with: [:]),
                               sources: ["Sources/**"],
                               resources: ["Resources/**"],
                               headers: Headers(public: ["Sources/DeltaCore.h", "Sources/DeltaTypes.h", "Sources/Emulator Core/Audio/DLTAMuteSwitchMonitor.h"]),
                               dependencies: [
                                .package(product: "ZIPFoundation"),
                               ]),
                      ])
