# TvOSTextViewer
[![Twitter: @dcordero](https://img.shields.io/badge/contact-@dcordero-blue.svg?style=flat)](https://twitter.com/dcordero)
![License MIT](https://img.shields.io/badge/license-MIT-green.svg)
![Swift 5.0](https://img.shields.io/badge/Swift-5.0-orange.svg)
[![Build Status](https://travis-ci.org/dcordero/TvOSTextViewer.svg?branch=master)](https://travis-ci.org/dcordero/TvOSTextViewer)

Light and scrollable view controller for tvOS to present blocks of text

![](preview.gif)

## Description

TvOSTextViewer is a view controller to present blocks of text on the same way native Apps do it on tvOS.

Customizable properties:

- text: The block of text to be presented
- textEdgeInsets: Margins for the text
- backgroundBlurEffectStyle: .dark by default
- textAttributes: Custom fonts/sizes, text colors, alignment, etc... via [NSAttributedText](https://developer.apple.com/documentation/uikit/uilabel/1620542-attributedtext)

## Requirements

- tvOS 9.0+
- Xcode 11

## Installation

### Cocoapods

[CocoaPods](https://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```
$ gem install cocoapods
```

To integrate TvOSTextViewer into your Xcode project using CocoaPods, specify it in your Podfile:


```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :tvos, '9.0'
use_frameworks!

target '<Your Target Name>' do
    pod 'TvOSTextViewer', '~> 1.3.0'
end
```

Then, run the following command:

```
$ pod install
```

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with Homebrew using the following command:

```
$ brew update
$ brew install carthage
```

To integrate TvOSTextViewer into your Xcode project using Carthage, specify it in your Cartfile:

```
github "dcordero/TvOSTextViewer" ~> 1.2.0
```

Run `carthage update` to build the framework and drag the built TvOSTextViewer.framework into your Xcode project.

## Usage

All you need is to create an instance of TvOSTextViewerViewController and present it on the screen:

```swift
let viewController = TvOSTextViewerViewController()
viewController.text = "Hello World"
present(viewController, animated: true, completion: nil)
```

If you would like to show this fullscreen view comming from an awesome button cropping the text on the same way Apple does, you can use it in combination with [TvOSMoreButton](https://github.com/cgoldsby/TvOSMoreButton) by [cgoldsby](https://twitter.com/GoldsbyChris)

