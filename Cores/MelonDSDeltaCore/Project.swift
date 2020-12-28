import ProjectDescription

let project = Project(name: "MelonDSDeltaCore",
                      packages: [],
                      targets: [
                        Target(name: "MelonDSDeltaCore",
                               platform: .iOS,
                               product: .framework,
                               bundleId: "com.rileytestut.melonDSDeltaCore",
                               deploymentTarget: .iOS(targetVersion: "12.2", devices: [.iphone, .ipad]),
                               infoPlist: .extendingDefault(with: [:]),
                               sources: ["Sources/**/*.swift", "Sources/Bridge/MelonDSEmulatorBridge.{h,mm}"],
                               resources: ["Resources/**/*.{deltamapping,deltaskin}"],
                               headers: Headers(public: ["Sources/MelonDSDeltaCore.h", "Sources/Bridge/MelonDSEmulatorBridge.h"], project: "Sources/Types/MelonDSTypes.h"),
                               dependencies: [
                                 .project(target: "DeltaCore", path: "../DeltaCore"),
                                .target(name: "libMelonDS")
                               ],
                               settings: Settings(base: [
                                "GCC_PREPROCESSOR_DEFINITIONS": "$(inherited) JIT_ENABLED=1",
                                "USER_HEADER_SEARCH_PATHS": "\"$(SRCROOT)\"",
                               ])),
                        Target(name: "libMelonDS",
                               platform: .iOS,
                               product: .staticLibrary,
                               bundleId: "com.rileytestut.libMelonDS",
                               deploymentTarget: .iOS(targetVersion: "13.4", devices: [.iphone, .ipad]),
                               infoPlist: .extendingDefault(with: [:]),
                               sources: [
                                "melonDS/src/frontend/qt_sdl/PlatformConfig.{h,cpp}",
                                "melonDS/src/tiny-AES-c/*.{h,hpp,c}",
                                "melonDS/src/ARMJIT_A64/*.{h,cpp,s}",
                                "melonDS/src/dolphin/Arm64Emitter.{h,cpp}",
                                "melonDS/src/xxhash/*.{h,c}",
                                SourceFileGlob("melonDS/src/*.{h,hpp,cpp}", excluding: [
                                    "melonDS/src/GPU3D_OpenGL.cpp",
                                    "melonDS/src/OpenGLSupport.cpp",
                                    "melonDS/src/GPU_OpenGL.cpp"
                                ])
                               ],
                               headers: Headers(project: [
                                "melonDS/src/*.h",
                                "melonDS/src/frontend/qt_sdl/PlatformConfig.h",
                                "melonDS/src/tiny-AES-c/*.{h,hpp}",
                                "melonDS/src/ARMJIT_A64/*.h",
                                "melonDS/src/dolphin/Arm64Emitter.h",
                                "melonDS/src/xxhash/*.h"
                               ]),
                               settings: Settings(base: [
                                "GCC_PREPROCESSOR_DEFINITIONS": "$(inherited) JIT_ENABLED=1",
                               ])),
                      ])
