import ProjectDescription

let project = Project(name: "DeSmuMEDeltaCore",
                      packages: [],
                      targets: [
                        Target(name: "DeSmuMEDeltaCore",
                               platform: .iOS,
                               product: .framework,
                               bundleId: "com.rileytestut.desmumeDeltaCore",
                               deploymentTarget: .iOS(targetVersion: "12.2", devices: [.iphone, .ipad]),
                               infoPlist: .extendingDefault(with: [:]),
                               sources: ["Sources/**/*.swift", "Sources/Bridge/DeSmuMEEmulatorBridge.{h,mm}"],
                               resources: ["Resources/**/*.{deltamapping,deltaskin}"],
                               headers: Headers(public: ["Sources/DeSmuMEDeltaCore.h", "Sources/Bridge/DeSmuMEEmulatorBridge.h"], project: "Sources/Types/DeSmuMETypes.h"),
                               dependencies: [
                                .project(target: "DeltaCore", path: "../DeltaCore"),
                                .target(name: "libDeSMuME"),
                                .sdk(name: "libz.tbd"),
                               ],
                               settings: Settings(base: [
                                "HEADER_SEARCH_PATHS": "\"$(SRCROOT)/desmume/desmume/src/libretro-common/include\"",
                                "OTHER_CFLAGS": "-DHOST_DARWIN -DDESMUME_COCOA -DHAVE_OPENGL -DHAVE_LIBZ -DANDROID -fexceptions -ftree-vectorize -DCOMPRESS_MT -DIOS -DOBJ_C -marm -fvisibility=hidden"
                               ])),
                        Target(name: "libDeSMuME",
                               platform: .iOS,
                               product: .staticLibrary,
                               bundleId: "com.rileytestut.libDeSMuME",
                               deploymentTarget: .iOS(targetVersion: "12.2", devices: [.iphone, .ipad]),
                               infoPlist: .extendingDefault(with: [:]),
                               sources: [
                                SourceFileGlob("desmume/desmume/src/**/*.{c,cpp}", excluding: [
                                    "desmume/desmume/src/OGLRender*.{c,cpp}",
                                    "desmume/desmume/src/lua-engine.{c,cpp}",
                                    "desmume/desmume/src/frontend/**/*.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/algorithms/**/*.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/compat/**/*.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/conversion/**/*.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/crt/**/*.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/dynamic/**/*.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/file/nbio/**/*.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/file/archive_*.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/file/config_file.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/file/config_file.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/formats/**/*.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/gfx/**/*.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/glsm/**/*.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/glsym/**/*.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/hash/**/*.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/include/**/*.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/libco/**/*.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/lists/**/*.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/memmap/**/*.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/net/**/*.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/queues/**/*.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/rthreads/async_job.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/rthreads/rsemaphore.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/rthreads/xenon_sdl_threads.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/streams/**/*.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/string/**/*.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/utils/**/*.{c,cpp}",
                                    "desmume/desmume/src/libretro-common/vulkan/**/*.{c,cpp}",
                                    "desmume/desmume/src/metaspu/SoundTouch/*_win.{c,cpp}",
                                    "desmume/desmume/src/metaspu/win32/**/*.{c,cpp}",
                                    "desmume/desmume/src/utils/arm_arm/**/*.{c,cpp}",
                                    "desmume/desmume/src/utils/AsmJit/**/*.{c,cpp}",
                                    "desmume/desmume/src/utils/colorspacehandler/*_*.{c,cpp}"
                                ])
                               ],
                               headers: Headers(
                                project: [
                                    "desmume/desmume/src/*.{h,hpp}",
                                    "desmume/desmume/src/libretro-common/include/*.{h,hpp}",
                                    "desmume/desmume/src/libretro-common/include/math/*.{h,hpp}",
                                    "desmume/desmume/src/metaspu/**/*.{h,hpp}",
                                    "libDeSmuME/*.{h,hpp}"
                                ]
                               ),
                               settings: Settings(base: [
                                "OTHER_LDFLAGS": "-ObjC",
                                "CLANG_CXX_LANGUAGE_STANDARD": "compiler-default",
                                "CLANG_CXX_LIBRARY": "compiler-default",
                                "HEADER_SEARCH_PATHS": "\"$(SRCROOT)/desmume/desmume/src/libretro-common/include\"",
                                "OTHER_CFLAGS": "-DHOST_DARWIN -DDESMUME_COCOA -DHAVE_OPENGL -DHAVE_LIBZ -DANDROID -fexceptions -ftree-vectorize -DCOMPRESS_MT -DIOS -DOBJ_C -marm -fvisibility=hidden"
                               ])),
                      ])
