# Delta for tvOS

The tvOS app uses the same emulator cores as the iOS app. A connected extended gamepad is required for gameplay; the Siri Remote is used only for library navigation, controller mapping, and the pause menu.

## Supported ROM files

| System | Core | Extensions |
| --- | --- | --- |
| NES | Nestopia | `.nes` |
| SNES | Snes9x | `.smc`, `.sfc`, `.fig` |
| Nintendo 64 | Mupen64Plus | `.n64`, `.z64`, `.v64` |
| Game Boy / Game Boy Color | Gambatte | `.gb`, `.gbc` |
| Game Boy Advance | VisualBoyAdvance-M | `.gba` |
| Mega Drive / Genesis | Genesis Plus GX | `.gen`, `.md`, `.smd`, `.bin` |
| Nintendo DS | melonDS | `.ds`, `.nds` |

Open the address displayed in the library in a browser on the same network to upload ROMs. ZIP archives are extracted automatically. Matching PNG or JPEG artwork can also be uploaded. File extensions are matched without regard to case. The browser's file picker and library scanner share the same ROM catalog.

## Controls

Use **Controller Mapping** to change bindings for each system. The editor uses the Siri Remote for navigation; gamepad buttons are captured only for mapping. A detected button is shown immediately and the assignment is saved on release. Enable **Haptic Feedback** for a short confirmation vibration on the controller that supplied the input, when supported. This preference is saved between sessions. The left stick also acts as a D-pad for systems other than Nintendo 64, where it is the analog stick.

Mega Drive defaults provide all six action buttons: A/B/C map to X/A/B, X/Y/Z map to LB/Y/RB, Start maps to Menu, and Mode maps to Options.

DS screens are stacked with their original proportions. Move the lower-screen pointer with the right stick and hold RT/R2 to touch or drag. LT/L2 closes the lid. Touch and lid buttons can be remapped. Pointer movement is controlled by the right stick. melonDS can use its built-in DS BIOS fallback. Microphone input is unavailable on Apple TV. GBA gyroscope input is unavailable on Apple TV; the iOS implementation is preserved.

## Resume and display resolution

Opening a game with an automatic resume point offers **Resume Game**, **Start from Beginning**, or **Cancel**. A resume point is saved when opening the pause menu, returning to the library, or moving the app to the background. Automatic states are stored separately from manual states and keep the ROM extension in their filename. Failed writes preserve the previous automatic state. An existing manual save state is offered if no valid automatic state exists.

The pause menu's **Image Size** setting offers Fit Screen, 75%, 50%, 33%, and Native Pixels. Native Pixels uses the current game image and screen scale to display source pixels without enlargement, and may appear very small on a 4K screen. Size is saved per system.

The separate **Display Resolution** setting offers Automatic, 1080p, 720p, and Core Resolution Limit. This setting is remembered per system. It limits the actual OpenGL/Metal display drawable without shrinking the picture or changing the TV's output mode. Core Resolution Limit uses the core's framebuffer dimensions as an upper bound while preserving the displayed aspect ratio. It does not alter the emulator's internal rendering resolution or CPU workload, so performance improvements depend on the bottleneck.

Battery-backed saves use each core's standard extension (`.sav`, or `.dsv` for DS). The pause menu also provides save states. ROMs and saves currently live in tvOS cache storage, as in the existing port.

## Validation

Run the ROM catalog, input-capture, resume-file, resolution, and DS touch-pointer tests on macOS:

```sh
swift test --package-path Delta-tvOS
```

Build the tvOS application:

```sh
xcodebuild -workspace Delta.xcworkspace \
  -scheme 'Delta-tvOS (Delta Workspace)' \
  -configuration Debug -destination 'generic/platform=tvOS' \
  CODE_SIGNING_ALLOWED=NO build
```

On an Apple TV, verify one game per added core: web upload (including uppercase extensions and a ZIP), library discovery, gamepad input, battery save after exit/relaunch, and save-state round trips. For DS, also test pointer movement, touching all screen edges, dragging, lid input, pausing, and disconnecting the controller while touching. Check that existing NES/SNES/N64 controls and the mapping editor still behave correctly. Exit and relaunch a game to verify the resume prompt, and test background/foreground transitions. On a 4K TV, compare all display-resolution settings while checking that picture size stays constant.
