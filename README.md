# Delta

> Delta is an all-in-one classic video game emulator for non-jailbroken iOS devices. 

[![Swift Version](https://img.shields.io/badge/swift-5.0-orange.svg)](https://swift.org/)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)

Delta is an iOS application that allows you to emulate and play video games for several classic video game systems, including Game Boy Advance, Nintendo 64, and Nintendo DS. Delta is the spiritual successor to [GBA4iOS](http://www.gba4iosapp.com) — a Game Boy Advance emulator for iOS devices [Paul Thorsen](https://twitter.com/pau1thor) and I made while in high school together — rebuilt from the ground up with modern iOS features and support for more systems.

<p align="center">
  <img src="https://user-images.githubusercontent.com/705880/115471008-203aa480-a1ec-11eb-8aba-237a46799543.png" width=75%><br/>
  <em>Mario and Pokémon are properties of Nintendo Co., Ltd. and are not associated with Delta or AltStore LLC.</em>
</p>

## Supported Systems
- Nintendo Entertainment System (NES)
- Super Nintendo Entertainment System (SNES)
- Nintendo 64 (N64)
- Game Boy / Game Boy Color (GBC)
- Game Boy Advance (GBA)
- Nintendo DS (DS)
- Sega Genesis / Mega Drive (GEN) **(in progress)**

## Features
- Accurate, full speed emulation thanks to mature underlying emulator cores.
    - NES: [Nestopia](https://github.com/0ldsk00l/nestopia)
    - SNES: [Snes9x](https://github.com/snes9xgit/snes9x)
    - N64: [mupen64plus](https://github.com/mupen64plus/mupen64plus-core)
    - GBC: [Gambatte](https://github.com/sinamas/gambatte)
    - GBA: [visualboyadvance-m](https://github.com/visualboyadvance-m/visualboyadvance-m)
    - DS: [melonDS](https://github.com/Arisotura/melonDS)
    - GEN: [Genesis Plus GX](https://github.com/ekeeke/Genesis-Plus-GX)
- Beautiful, native UI.
    - Browse and play your favorite games with a UI designed from the ground up for iOS.
    - Automatically displays appropriate box art for imported games.
    - Change a game’s artwork to anything you want, or select from the built-in game artwork database.
- Controller Support
    - Supports PS4, PS5, Xbox One S, Xbox Series X, and MFi game controllers.
    - Supports bluetooth (and wired) keyboards, as well as the Apple Smart Keyboard.
    - Completely customize button mappings on a per-system, per-controller basis.
    - Map buttons to special “Quick Save”, “Quick Load,” and “Fast Forward” actions.
- Custom Controller Skins
    - Beautiful built-in controller skins for all systems.
    - Import controller skins made by others, or even make your own to share with the world!
- Save States
    - Save and load save states for any game from the pause menu.
    - Lock save states to prevent them from being accidentally overwritten.
    - Automatically makes backup save states to ensure you never lose your progress.
    - Support for “Quick Saves,” save states that can be quickly saved/loaded with a single button press (requires external controller).
- Fast Forwarding
    - Speed through slower parts of games by running the game much faster than normal.
    - Easily enable or disable from the pause menu, or optionally with a mapped button on an external controller.
- Delta Sync
    - Sync your games, game saves, save states, cheats, controller skins, and controller mappings between devices.
    - View version histories of everything you sync and optionally restore them to earlier versions.
    - Supports both Google Drive and Dropbox.
- Hold Button
    - Choose buttons for Delta to hold down on your behalf, freeing up your thumbs to press other buttons instead.
    - Perfect for games that typically require one button be held down constantly (ex: run button in Mario games, or the A button in Mario Kart).
- 3D/Haptic Touch
    - Use 3D or Haptic Touch to “peek” at games, save states, and cheat codes.
    - App icon shortcuts allow quick access to your most recently played games, or optionally customize the shortcuts to always include certain games.
- Cheat Codes
    - NES
        - Game Genie
    - SNES: 
        - Game Genie
        - Pro Action Replay
    - N64
        - GameShark
    - GBC
        - Game Genie
        - GameShark
    - GBA
        - Action Replay
        - Code Breaker
        - GameShark
    - DS
        - Action Replay
- Gyroscope support  **(WarioWare: Twisted! only)**
- Microphone support **(DS only)**

## Installation

<p align="center">
  <img src="https://user-images.githubusercontent.com/705880/114452847-c1db4980-9b8d-11eb-8f8f-de7998562222.png" width=100px height=100px>
</p>

Delta was originally developed under the impression Apple would allow it into the App Store. Unfortunately Apple later changed their minds, leaving me no choice but to find a new way to distribute Delta. Long story short, this led me to create [AltStore](https://github.com/rileytestut/AltStore), which now serves as the official way to install Delta onto your device.

To install Delta with AltStore:
1. Download AltServer for Mac or PC from https://altstore.io
2. Connect your iOS device to your computer via lightning cable (or USB-C for iPads).
3. [Follow these instructions](https://altstore.io/faq/) to install AltStore onto your device with AltServer.
2. Open AltStore on your device, then navigate to the "Browse" tab.
3. Find Delta, then press the `FREE` button to start installing the app.

Once you've installed Delta with AltStore, **you'll need to refresh it at least once every 7 days to prevent it from expiring** and requiring a re-installation. AltStore will periodically attempt to refresh your apps in the background when on the same WiFi as AltServer, but you can also manually refresh apps by pressing "Refresh All" in AltStore. AltStore will also let you know whenever a new update is released, allowing you to update Delta directly within AltStore.

Alternatively, you are welcome to download the compiled `.ipa`'s from [Releases](https://github.com/rileytestut/Delta/releases) and sideload them using whatever sideloading method you prefer, but you will not receive automatic updates and will have to manually update Delta by re-sideloading each new version.

## Project Overview

Delta was designed from the beginning to be modular, and for that reason each "Delta Core" has its own GitHub repo and is added as a submodule to the main Delta project. Additionally, Delta uses two of my own private frameworks I use to share common functionality between my apps: Roxas and Harmony.

[**Delta**](https://github.com/rileytestut/Delta)  
Delta is just a regular, sandboxed iOS application. The Delta app repo (aka this one) contains all the code specific to the Delta app itself, such as storyboards, app-specific view controllers, database logic, etc.

[**DeltaCore**](https://github.com/rileytestut/DeltaCore)  
DeltaCore serves as the “middle-man” between the high-level app code and the specific emulation cores. By working with this framework, you have access to all the core Delta features, such as emulation, controller skins, save states, cheat codes, etc. Other potential emulator apps will use this framework extensively.

[**Roxas**](https://github.com/rileytestut/Roxas)    
Roxas is my own framework used across my projects, developed to simplify a variety of common tasks used in iOS development.

[**Harmony**](https://github.com/rileytestut/Harmony)   
Harmony is my personal syncing framework designed to sync Core Data databases. Harmony listens for changes to an app's persistent store, then syncs any changes with a remote file service (such as Google Drive or Dropbox).

**Delta Cores**  
Each system in Delta is implemented as its own "Delta Core", which serves as a standard emulation API Delta can understand regardless of the underlying core. For the most part, you don't interact directly with specific Delta Cores, but rather indirectly through `DeltaCore`.
- [NESDeltaCore](https://github.com/rileytestut/NESDeltaCore)
- [SNESDeltaCore](https://github.com/rileytestut/SNESDeltaCore)
- [N64DeltaCore](https://github.com/rileytestut/N64DeltaCore)
- [GBCDeltaCore](https://github.com/rileytestut/GBCDeltaCore)
- [GBADeltaCore](https://github.com/rileytestut/GBADeltaCore)
- [MelonDSDeltaCore](https://github.com/rileytestut/MelonDSDeltaCore)
- [GPGXDeltaCore](https://github.com/rileytestut/GPGXDeltaCore)

## Project Requirements
- Xcode 12
- Swift 5+
- iOS 12.2 or later

Why iOS 12.2 or later? Doing so allows me to distribute Delta without embedding Swift libraries inside. This helps me afford bandwidth costs by reducing download sizes by roughly 30%, but also noticeably improves how long it takes to install/refresh Delta with AltStore. If you're compiling Delta yourself, however, you should be able to lower the deployment target to iOS 12.0 without any issues.

## Compilation Instructions
1. Clone this repository by running the following command in Terminal*  
```bash
$ git clone https://github.com/rileytestut/Delta.git
```  

2. Update Git submodules
```bash
$ cd Delta
$ git submodule update --init --recursive
```  

3. Open `Delta.xcworkspace` and select the Delta project in the project navigator. 
4. Select "Delta" under targets, then click the `Signing & Capabilities` tab.
5. Change `Team` from `Yvette Testut` to your own account.
6. Change `Bundle Identifier` to something unique, such as by appending your GitHub username (ex: `com.rileytestut.Delta.MyGitHubUsername`).
7. Build + run app! 🎉

\* This will checkout the `main` branch by default, which is kept up-to-date with the latest public version. Ongoing development (including [Patreon betas](https://www.patreon.com/rileytestut)) is done on the `develop` branch, and is periodically merged into `main` whenever a new public version is released. If you'd prefer to compile the `develop` version instead, replace the `git clone` command in Step #1 with this one:
```bash
$ git clone -b develop https://github.com/rileytestut/Delta.git
```  

## Licensing
Due to the licensing of emulator cores used by Delta, I have no choice but to distribute Delta under the **AGPLv3 license**. That being said, I explicitly give permission for anyone to use, modify, and distribute all *my* original code for this project in any form, with or without attribution, without fear of legal consequences (dependencies remain under their original licenses, however).

## Contact Me

* Email: riley@rileytestut.com
* Twitter: [@rileytestut](https://twitter.com/rileytestut)
