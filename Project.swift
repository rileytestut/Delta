import ProjectDescription

let project = Project(name: "Delta",
                      packages: [],
                      targets: [
                        Target(name: "Delta",
                               platform: .iOS,
                               product: .app,
                               bundleId: "com.rileytestut.Delta",
                               infoPlist: "Info.plist",
                               sources: ["Sources/**"],
                               resources: [
                                /* Path to resouces can be defined here */
                                "Resources/**",
                               ],
                               headers: Headers(private: [
                                "Sources/Extensions/NSFetchedResultsController+Conveniences.h",
                                "Sources/Database/Model/Misc/ControllerSkinConfigurations.h"
                               ]),
                               actions: [
                                .post(path: "Phases/fabric.sh", name: "Fabric"),
                               ],
                               dependencies: [
                                /* Target dependencies can be defined here */
                                .sdk(name: "CoreMotion.framework", status: .required),
                                .sdk(name: "libz.tbd"),
                                .cocoapods(path: "."),
                                .project(target: "DeltaCore", path: "Cores/DeltaCore"),
                                .project(target: "MelonDSDeltaCore", path: "Cores/MelonDSDeltaCore"),
                                .project(target: "Mupen64PlusDeltaCore", path: "Cores/Mupen64PlusDeltaCore"),
                                .project(target: "DeSmuMEDeltaCore", path: "Cores/DeSmuMEDeltaCore")
                               ],
                               settings: Settings(base: [
                                "DEVELOPMENT_TEAM": "6XVY5G3U44",
                                "IPHONEOS_DEPLOYMENT_TARGET": "12.2",
                                "OTHER_SWIFT_FLAGS": "$(inherited) -Xfrontend -debug-time-function-bodies",
                                "SWIFT_OBJC_BRIDGING_HEADER": "Sources/Bridging-Header.h",
                                "CODE_SIGN_STYLE": "Automatic",
                               ])),
                      ])
