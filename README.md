Delta
===========

Hello! This README is serving as a placeholder for now, but will be updated as soon as I finally get some sleep. Until then, this should serve as a basic guide to Delta and its multiple repos.

One of the driving factors behind Delta from the beginning was to develop a generic emulation framework that *anyone* could use to develop their own iOS emulator. Because of this, the “core” emulation logic used by Delta has been separated from this main repository into several other repos.

Here’s a brief overview of how the Delta app is broken down internally:

[**Delta** ](https://github.com/rileytestut/Delta)   
The Delta app repo (aka this one) contains all the code specific to the app itself, such as storyboards, app-specific view controllers, database logic, etc.

[**DeltaCore**](https://github.com/rileytestut/DeltaCore)  
DeltaCore serves as the “middle-man” between the high-level app code and the specific emulation cores. By working with this framework, you have access to all the core Delta features, such as emulation, controller skins, save states, cheat codes, etc. Other potential emulator apps will use this framework extensively.

[**NESDeltaCore**](https://github.com/rileytestut/NESDeltaCore)  
NESDeltaCore essentially wraps up the Nestopia emulator core into something that can be understood by DeltaCore. For the most part, you don’t need to interact directly with this framework.

[**SNESDeltaCore**](https://github.com/rileytestut/SNESDeltaCore)  
Just like with NESDeltaCore, SNESDeltaCore wraps the SNES emulator core (Snes9x) into a framework understood by DeltaCore. Again, you shouldn’t need to use this framework directly that often.

[**N64DeltaCore**](https://github.com/rileytestut/N64DeltaCore)  
N64DeltaCore is a Nintendo 64 core based off of mupen64plus.

[**GBCDeltaCore**](https://github.com/rileytestut/GBCDeltaCore)  
GBCDeltaCore is a Game Boy Color core based off of Gambatte.

[**GBADeltaCore**](https://github.com/rileytestut/GBADeltaCore)  
GBADeltaCore is a Game Boy Advance core based off of VisualBoyAdvance-M.

[**DSDeltaCore**](https://github.com/rileytestut/DSDeltaCore)  
DSDeltaCore is a Nintendo DS core based off of DeSmuME.

[**Roxas**](https://github.com/rileytestut/Roxas)    
Roxas is my own framework used across my projects, developed to simplify a variety of common tasks used in iOS development.

Compilation Instructions
=============
- Clone this repository by running the following command in Terminal:  
```bash
$ git clone git@github.com:rileytestut/Delta.git
```  

- Update Git submodules
```bash
$ cd Delta
$ git submodule update --init --recursive
```  

- Open `Delta.xcworkspace`, and run!
