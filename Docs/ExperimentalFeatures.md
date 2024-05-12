# Overview

Features contributed to Delta by third-party developers are considered "experimental", and are available for testing in the beta version of Delta. Once a feature has been sufficiently tested, we may choose to "graduate" it into an official Delta feature, at which point it will become available to all users.

Every Experimental Feature can be thought of as a binary flag: it's either enabled or disabled. When disabled, a feature should have no impact on the rest of the app. This allows us to accept contributions freely without affecting the overall stability of Delta.

If a feature requires more state than binary On/Off, you can define as many "options" as needed. Options store additional data required by your feature's implementation. Options can be "hidden" (the default), but can also be automatically exposed in Delta's settings where they can be changed directly by users.

# Guidelines For Experimental Features

Keep the following in mind when contributing new Experimental Features:

* When a feature is disabled, it should have *no* noticeable impact on the rest of the app.
* Avoid touching the core emulation logic.
* Isolate your changes as much as possible from the rest of the app, preferably in separate files. We recommend using Swift extensions to add functionality to existing types (e.g. `GameViewController+ExperimentalFastForward.swift`)
* If your change requires modifying `DeltaCore` or specific cores, make sure the naming and "shape" of any public API follows existing conventions as much as possible. In general, Experimental Features that require modifying cores have a higher bar for acceptance.

# Adding a New Experimental Feature

1. Open `Delta/Experimental Features/ExperimentalFeatures.swift`
2. Add a new property to the `ExperimentalFeatures` struct, annotated with the `@Feature` property wrapper. You do not need to define the property's type as it will be inferred by @Feature.
  
> The property name (e.g. `variableFastForward`) will be used internally as the `UserDefaults` key for persisting data.

3. Pass in the name of your feature to `@Feature`'s initializer, and optionally a description.

Once you've defined your feature, you can check whether or not it's enabled at runtime via `ExperimentalFeatures.shared.[feature].isEnabled`.

Here's a complete implementation for a new Experimental Feature called "Show Status Bar":

```swift
// ExperimentalFeatures.swift
struct ExperimentalFeatures
{
    @Feature(name: "Show Status Bar", description: "Show the Status Bar during gameplay.")
    var showStatusBar
}

// GameViewController+ShowStatusBar.swift
extension GameViewController
{
    override var prefersStatusBarHidden: Bool {
        return !ExperimentalFeatures.shared.showStatusBar.isEnabled
    }
}
```

# Adding Options to a Feature
Some features require additional configuration beyond being enabled or disabled. These are referred to as "options", and you can define as many options for a feature as necessary. Whenever an option's value changes, it is automatically persisted to `UserDefaults`.

The option’s underlying type must conform to `OptionValue`. Automatic conformance is provided for all standard property list types, but if you want to use your own type, it must either:
* Conform to `RawRepresentable`, where its raw type is a valid property list type (e.g. enums with string backing), or
* Conform to `Codable`

To declare a feature with options:

1. Create a new Swift file in `Delta/Experimental Features/Features` and name it after your feature (e.g. `VariableFastForward.swift`)
2. Define a new struct named `[FeatureName]Options` (e.g. `VariableFastForwardOptions`)
3. For each configurable value, define a new property on your Options struct with `@Options` property wrapper.
> The property name (e.g. `speed`) will be combined with the feature's property name and used internally as the `UserDefaults` key for persisting data.
4. **If the option represents a non-optional value, you must provide an initial value**. This will be used as the default value if the option has not been configured by user.
5. Follow the above instructions for declaring a feature, but pass in an instance of your `Options` struct to the `options:` parameter in the `@Feature` initializer.

Heres's an example feature "Game Gestures" that shows an instruction alert the first time it is enabled. It uses an `@Option` to store whether the alert has already been shown or not.

```swift
// GameGestures.swift
struct GameGesturesOptions
{
    @Option // No parameters = "Hidden" option
    var didShowGestureAlert: Bool = false
}

// ExperimentalFeatures.swift
struct ExperimentalFeatures
{
    @Feature(name: "Game Gestures", options: GameGesturesOptions())
    var gameGestures
}
```

# User-Facing Options
By default, Options are hidden, which means their values can only be changed programmatically.

However, options can also be user-facing, which we generally recommend. User-facing options will automatically appear in the `Experimental Features` section of Delta's settings, where they can be configured manually by users. To define a user-facing option, pass in a value for `name` in the `@Option` initializer, and optionally a `description`.

Because user-facing options are meant to be seen by users, the underlying type must conform to `LocalizedOptionValue`. This protocol refines `OptionValue` with two new methods:
* `localizedDescription`, used to display the value in a human-readable manner.
* `localizedNilDescription`, used to represent the `nil` value in a human-readable manner. The default implementation returns "None".

Heres's an example feature "Game Screenshots" that defines options so users can choose whether to save screenshots to the Photo Library, the Files app, or both. Unlike the above "Game Gestures" example, "Save to Files" and "Save to Photos" will be exposed in the `Experimental Features` section of Delta's settings, where they will appear as switches that the user can toggle.

```swift
// GameScreenshots.swift
struct GameScreenshotsOptions
{
    @Option(name: "Save to Files", description: "Save the screenshot to the app's directory in Files.")
    var saveToFiles: Bool = true

    @Option(name: "Save to Photos", description: "Save the screenshot to the Photo Library.")
    var saveToPhotos: Bool = false
}

// ExperimentalFeatures.swift
struct ExperimentalFeatures
{
    @Feature(name: "Game Screenshots", options: GameScreenshotsOptions())
    var gameScreenshots
}
```

## Types of User-Facing Options

Delta supports 3 types of user-facing options:
* Bool options
* "Picker" options (e.g. array of values)
* Custom options (any other type)

Here's an example feature "VariableFastForward" that uses all 3 types of user-facing options:

```swift
// VariableFastForward.swift
enum FastForwardSpeed: Double, CaseIterable, CustomStringConvertible
{
    case x2 = 2
    case x3 = 3
    case x4 = 4
    case x8 = 8
    
    var description: String {
        return "\(self.rawValue)x"
    }
}

extension FastForwardSpeed: LocalizedOptionValue
{
    var localizedDescription: Text {
        Text(self.description)
    }
    
    static var localizedNilDescription: Text {
        Text("Maximum")
    }
}

struct VariableFastForwardOptions
{
    // Bool option (will appear as inline UISwitch)
    @Option(name: "Allow Unrestricted Speeds", description: "Allow speeds that exceed the maximum speed of a system.")
    var allowUnrestrictedSpeeds: Bool = false

    // "Custom" option (will appear as full-screen view with text field) 
    @Option(name:  "Maximum Speed", description: "Change the maximum fast forward speed across all systems.", detailView: { 
        TextField("", value: $0, formatter: NumberFormatter())
          .keyboardType(.numberPad)
    })
    var maxSpeed: Int?
    
    // "Picker" options (will appear as standard UIMenu picker)
    @Option(name: "Nintendo Entertainment System", values: FastForwardSpeed.allCases)
    var nes: FastForwardSpeed?

    @Option(name: "Super Nintendo", values: FastForwardSpeed.allCases)
    var snes: FastForwardSpeed?

    @Option(name: "Nintendo 64", values: FastForwardSpeed.allCases)
    var n64: FastForwardSpeed?

    // Etc.
}
```

Each type of user-facing option has slightly different requirements, which are detailed below:

### Bool Option
If the property annotated with @Option is a `Bool`, there is nothing more you need to do. Delta will automatically show a toggle on the feature's detail page that can be used by user to update this value.

Example:
```swift
@Option(name: "showStatusBar")
var showStatusBar: Bool = false
```

### "Picker" Option
If there is a known, finite number of supported values for your option, you can pass a `Collection` of them to the `values:` parameter in the `@Option` initializer. Delta will automatically show an inline picker on the feature's detail page that will allow users to select from the preset values.

>
> If the option is an optional type, the picker will automatically include a `nil` option in the picker. You can customize the name used to represent the `nil` option by overriding `LocalizedOptionValue.localizedNilDescription`.
>

Example:
```swift
enum Planet: String { mercury, venus, earth, ... }

extension Planet: LocalizedOptionValue
{
    static var localizedNilDescription: Text {
        Text("No Favorite Planet")
    }
}

@Option(name: "Current Planet", values: Planet.allCases)
var currentPlanet: Planet = .earth

@Option(name: "Favorite Planet", values: Planet.allCases)
var favoritePlanet: Planet? // Optional, so Delta will include `nil` option in picker, displayed as "No Favorite Planet".
```

### "Custom" Option
Every user-facing `@Option` requires some UI in order to be configured by users in Delta's settings. If your option is not one of the ones listed above, you'll need to provide your own `SwiftUI` view. This can be as simple as just an inline `TextField` (e.g. for `String` options), or a completely custom full screen SwiftUI view with access to the entire SwiftUI API (e.g. a full color picker for `Color` options).

To provide your own SwiftUI view, pass in a closure that returns your custom `View` to the `detailView:` parameter in `@Option`'s  initializer. The closure passes in a `Binding` to the option's underlying value, which can then be passed into any SwiftUI control that takes a `Binding` (e.g. `Picker`, `Toggle`, `TextField`, etc.) to automatically update the option's value. However this is just a convenience, and you are welcome to update your `@Option` value from your custom view however works best.

By default, custom options will present their SwiftUI views full-screen when tapped. However, if you want your custom view to appear inline (like Bool and "picker" options), you can apply the `displayInline()` modifier to your view.

Example:
```swift
// Inline text field
@Option(name:  "Custom Nickname", detailView: { 
    TextField("", text: $0)
        .displayInline()
})
var nickname: String
```

## Using Features

All Experimental Features can be selectively enabled or disabled by the user in the "Experimental Features" section of Delta's settings. To check whether a feature is enabled at runtime, call `ExperimentalFeatures.shared.[feature].isEnabled`. **Your feature implementation must respect this flag and have no noticeable effect on the rest of the app when disabled.**

You can access individual feature options via `ExperimentalFeatures.shared.[feature].[option]`. To access `@Option`-specific properties, such as its `settingsKey`, use the `@Option`'s projected value by prepending the property with a `$` (e.g. `ExperimentalFeatures.shared.[feature].$[option].settingsName`).

Delta will automatically post a `Settings.didChangeNotification` notification whenever a feature is enabled, disabled, or one of its options changes. The `userInfo` dictionary will contain either `Feature.settingsName` or `Option.settingsName` under the `SettingsUserInfoKey.name` key, as well as the new value under the `SettingsUserInfoKey.value` key.

Example:

```swift
// Handler for Settings.didChangeNotification
func settingsDidChange(_ notification: Notification)
{
    guard let name = notification.userInfo?[SettingsUserInfoKey.name] as? Settings.Name else { return }

    switch name
    {
    case ExperimentalFeatures.shared.showStatusBar.settingsKey:
        // Update status bar
        self.setNeedsStatusBarAppearanceUpdate()
        
    case ExperimentalFeatures.shared.customTintColor.settingsKey: fallthrough
    case ExperimentalFeatures.shared.customTintColor.$color.settingsKey:
        // Update tint color if feature itself is enabled/disabled OR tint color changes.
        self.updateTintColor()
        
    default: break
    }
}
```
