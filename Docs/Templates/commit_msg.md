# Commit Message Template

## Basic Structure
```
[Emoji] [Type]: [Module/Feature] [Component]

Description of the changes (wrap at 72 characters)
```

## Line Length Guidelines
- **Subject Line**: Maximum 50 characters for git tool compatibility
- **Body Text**: Wrap at 72 characters per line for terminal readability
- Use `git config --global core.editor "vim"` and `:set textwidth=72` for auto-wrapping

## Common Patterns
```
🚀 Release: Version 0.7 (Build 3)
🥼 ElevenLabs: [ConnectionManager] Dynamic Agent ID
🎨 SwiftUI: [Settings] Agent Selector
🧪 Test: MIDI System Test Suite Overhaul
♻️ Refactor: MIDI Command Base Class to Protocol
📝 Docs: VibeTools Guide & Rule Alignment
🐛 Fix: [FeatureFlagManager] Resolve permission timing
🎧 AudioKit: Enable Simultaneous MIDI and Voice Playback
⚙️ Config: Gemini 2.0 Flash and 2.5 Flash model guidance
```

## Detailed Format (for complex changes)
```
[Emoji] [Type]: [Module/Feature] [Component]

Key Changes
-----------
- [Emoji] [Specific change description]
- [Emoji] [Specific change description]

Implementation Details
--------------------
- [Emoji] [Specific change description]
- [Emoji] [Specific change description]

Testing & Validation
-------------------
- [Emoji] [Specific change description]
- [Emoji] [Specific change description]

Known Issues (if any)
-------------------
- [Emoji] [Specific change description]
```

## Examples

### Release Example
```
🚀 Release: Version 0.8 (Build 7)

Key Features
-----------
- 🔧 Configure push notification entitlements and provisioning
- ✨ Implement PushNotificationManager service architecture
- 🏗️ Create protocol-based notification system for testability

Implementation Details
--------------------
- ♻️ Refactor AppDelegate with notification handling delegation
- ✅ Complete permission flow and device token registration
- 📊 Add comprehensive logging for notification events

Testing & Documentation
----------------------
- 📄 Add implementation docs with push_notifications.md
- 🧪 Document testing approaches and workarounds
- 🔍 Add troubleshooting guide for common issues
```

### Feature Example
```
🎨 SwiftUI: [Settings] Agent Selector

Key Changes
-----------
- ✨ Implemented agent environment selector UI in AppSettingsView
- 🎨 Applied UI refinements for layout, style, accessibility
- 🚫 Hid settings gear in HeaderView during active calls

Testing & Validation
-------------------
- 🧪 Verify AppSettingsView UI & HeaderView conditional visibility
- ✅ Added comprehensive test coverage for both components
- ♿️ Improved VoiceOver support with descriptive labels
```

### Documentation Example
```
📝 Docs: [CoreMIDI] USB-C/Thunderbolt Output Plan

Plan Details
-----------
- 📝 Define architecture using ExternalMIDIService and MIDIRoutingCoordinator
- ✨ Centralize routing logic and Note Off timing
- 🎯 Focus MVP on MIDI 1.0 byte stream output (KIS approach)
- 🧹 Consolidate research files into feature-midi-external-output.md

Next Steps
----------
- ♻️ Update MIDIButtonSoundService to use MIDIRoutingCoordinator
- 🔧 Defer UI configuration to later implementation phase
```

## Common Emojis Reference

### Core Development
- 🚀 Release/Major milestone
- ⚡️ Feature/Enhancement
- ✨ New implementation
- ♻️ Refactor/Restructure
- 🐛 Bug fix
- 🚨 Fix warnings/Critical issues
- 🧹 Clean up/Remove code

### Mira-Specific Components
- 🥼 ElevenLabs integration
- 🎧 AudioKit/Audio processing
- 🎨 SwiftUI/UI components
- 🎵 MIDI/Music features
- ⚙️ Configuration/System setup
- 🔒 Security/Authentication
- 🚩 Feature flags

### Testing & Quality
- 🧪 Tests/Testing
- ✅ Success/Completion
- 💚 CI/Build fixes
- 🔍 Code review/Debug
- 📊 Analytics/Monitoring
- �� Logging/Debug info

### Documentation & Dependencies
- 📝 Documentation
- 📦 Dependencies/Packages
- 🔄 Updates/Sync
- 📱 Platform-specific (iOS/macOS)

### Accessibility & UX
- ♿️ Accessibility improvements
- 🌐 Localization
- 🎯 User experience enhancements

### Firebase-Specific Emojis
| Emoji | Purpose | Example |
|-------|---------|---------|
| 🚩 | Feature Flags | "Add remote feature flag support" |
| ⚙️ | Configuration | "Implement Firebase Remote Config setup" |
| 🔄 | Real-time Updates | "Add real-time config updates" |
| ✅ | Success Operations | "Implement successful fetch handling" |
| ❌ | Error Handling | "Add config fetch error handling" |
| ⚠️ | Warnings | "Add throttling warning logs" |
| 📊 | Status Reporting | "Implement feature flag status logging" |
| ⏱️ | Timing/Throttling | "Add fetch throttling prevention" |

## Best Practices

### Writing Style
1. Use imperative mood ("Add feature" not "Added feature")
2. Start with action verbs (Add, Fix, Update, Remove, etc.)
3. Be specific about what changed and why
4. Group related changes under clear sections

### Content Guidelines
5. Reference relevant documentation when applicable
6. Include test coverage for new features
7. Document accessibility considerations
8. Note any breaking changes clearly
9. Specify performance impact for significant changes
10. Include environment or deployment requirements

### Swift-Specific Notes
- Note protocol conformance additions
- Highlight property wrapper usage (@Published, @State, etc.)
- Document @MainActor changes for UI components
- Specify async/await implementations
- Note Sendable conformance for concurrency
- Highlight actor isolation changes
- Document SwiftData schema updates
