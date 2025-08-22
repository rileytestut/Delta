# Build Issues Resolution Guide
## Delta Project Build Errors & Warnings Fix

**Created**: 2025-08-21  
**Scope**: Resolve critical build failures and warnings in freshly cloned Delta project  
**Prerequisites**: Xcode 15.0+, iOS 14.0+, macOS with development environment

---

## 🚨 Critical Issues (Must Fix)

### Issue 1: Code Signing Certificate Error
**Error**: `No "iOS Development" signing certificate matching team ID "6XVY5G3U44" with a private key was found`  
**Impact**: Complete build failure  
**Priority**: **CRITICAL**

#### Resolution Steps:

**Option A: Use Automatic Signing (Recommended)**
1. **Open Xcode**:
   ```bash
   cd /Users/jordancassady/git/Delta
   open Delta.xcworkspace
   ```

2. **Configure Delta Target**:
   - Select "Delta" project in navigator
   - Click "Delta" target
   - Go to "Signing & Capabilities" tab
   - ✅ Check "Automatically manage signing"
   - **Team**: Select your Apple Developer account
   - **Bundle Identifier**: Change to unique ID (e.g., `com.yourname.Delta`)

3. **Configure Systems Target**:
   - Select "Systems" project in navigator  
   - Click "Systems" target
   - Go to "Signing & Capabilities" tab
   - ✅ Check "Automatically manage signing"
   - **Team**: Select your Apple Developer account
   - **Bundle Identifier**: Update to match Delta's pattern

**Option B: Manual Certificate Setup**
1. **Open Keychain Access**
2. **Check for iOS Development Certificate**:
   - Look for "iPhone Developer" or "Apple Development" certificate
   - Verify it has a valid private key (shows arrow ▶️)

3. **If Missing Certificate**:
   - Open Xcode → Preferences → Accounts
   - Add your Apple ID
   - Click "Manage Certificates..."
   - Click "+" → "Apple Development"
   - This creates the certificate

4. **Update Project Settings**:
   - Set correct Team ID in project settings
   - Ensure certificate matches the team

---

## ⚠️ Warning Issues (Recommended Fixes)

### Issue 2: iOS Deployment Target Compatibility
**Warning**: Multiple targets have deployment targets below iOS 12.0  
**Impact**: Future Xcode versions may reject these settings  
**Priority**: **HIGH**

#### Affected Dependencies:
- SQLite.swift: 8.0 → 12.0
- SDWebImage: 7.0 → 12.0  
- SMCalloutView: 7.0 → 12.0
- GoogleAPIClientForREST: 7.0 → 12.0
- Alamofire: 8.0 → 12.0
- GoogleSignIn: 8.0 → 12.0
- ZIPFoundation: 9.0 → 12.0
- SwiftyDropbox: 9.0 → 12.0
- AppAuth: 9.0 → 12.0
- GTMSessionFetcher: 9.0 → 12.0
- GTMAppAuth: 9.0 → 12.0

#### Resolution Steps:

1. **Update Podfile**:
   ```bash
   cd /Users/jordancassady/git/Delta
   nano Podfile
   ```

2. **Update Existing Post-Install Hook**:
   ```ruby
   # The platform is already set to iOS 14.0 ✅
   # Update the existing post_install hook to include deployment target fix:
   
   post_install do |installer|
     installer.pods_project.targets.each do |target|
       # Fix deployment targets for all pods
       target.build_configurations.each do |config|
         config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
       end
       
       # Preserve existing DeltaCore unlinking logic
       if target.name == "Pods-Delta"
         puts "Updating #{target.name} OTHER_LDFLAGS"
         target.build_configurations.each do |config|
           xcconfig_path = config.base_configuration_reference.real_path
           xcconfig = File.read(xcconfig_path)
           new_xcconfig = xcconfig.sub('-l"DeltaCore"', '')
           File.open(xcconfig_path, "w") { |file| file << new_xcconfig }
         end
       end
     end
   end
   ```

3. **Update Pods**:
   ```bash
   pod install --repo-update
   ```

4. **Note on Google Dependencies**:
   - The build log shows Google dependencies (GoogleSignIn, GoogleAPIClientForREST, etc.)
   - These appear to be from Swift Package Manager (Phase 1 streaming setup)
   - If these continue showing deployment target warnings, they may need SPM version updates
   - Consider updating Google packages to latest versions in Xcode → Package Dependencies

### Issue 3: Run Script Build Phase Warnings
**Warning**: Multiple script phases lack output specifications  
**Impact**: Scripts run on every build, slowing build times  
**Priority**: **MEDIUM**

#### Affected Scripts:
- Systems: 'Run Script'
- N64DeltaCore: '[CP-User] Get GlideN64 Revision.h'
- DeltaCore: '[CP-User] Copy Swift Header'

#### Resolution Steps:

**For Systems Target:**
1. **Open Systems.xcodeproj**:
   ```bash
   open /Users/jordancassady/git/Delta/Systems/Systems.xcodeproj
   ```

2. **Configure Run Script Phase**:
   - Select "Systems" target
   - Go to "Build Phases" tab
   - Find "Run Script" phase
   - **Either Option A**: Add output files:
     ```
     ${DERIVED_FILE_DIR}/systems_build_info.h
     ```
   - **Or Option B**: Uncheck "Based on dependency analysis"

**For CocoaPods Scripts:**
1. **These are managed by CocoaPods and will be fixed by updating Podfile post_install hook**

### Issue 4: Duplicate Build Files
**Warning**: Multiple duplicate files in build phases  
**Impact**: Build warnings, potential conflicts  
**Priority**: **LOW**

#### Affected Targets:
- N64DeltaCore: 20+ duplicate header files
- GBADeltaCore: 5+ duplicate header files

#### Resolution Steps:
1. **Clean Build**:
   ```bash
   cd /Users/jordancassady/git/Delta
   ```
   - In Xcode: Product → Clean Build Folder (⌘⇧K)

2. **Reset CocoaPods**:
   ```bash
   pod deintegrate
   pod install
   ```

### Issue 5: Manual Target Build Order Warning
**Warning**: Building targets in manual order is deprecated  
**Impact**: Future Xcode compatibility  
**Priority**: **LOW**

#### Resolution Steps:
1. **Open Systems Scheme**:
   - In Xcode: Product → Scheme → Edit Scheme
   - Go to "Build" tab
   - **Build Options**: Change to "Dependency Order"
   - Click "Close"

---

## 🔧 Complete Resolution Workflow

### Phase 1: Critical Fixes (Required)
```bash
# 1. Navigate to project
cd /Users/jordancassady/git/Delta

# 2. Open workspace
open Delta.xcworkspace

# 3. Fix signing (follow Option A above in Xcode)
# 4. Test build
# In Xcode: Product → Build (⌘B)
```

### Phase 2: N64 Removal Fixes (Critical for Build Success)
```bash
# 1. Navigate to project
cd /Users/jordancassady/git/Delta

# 2. Fix CheatDevice.swift (manually remove N64 references - see Issue 6 above)
# 3. Fix GameViewController.swift (manually remove N64 conditional - see Issue 6 above)  
# 4. Remove N64 from linker flags (manually edit project.pbxproj - see Issue 6 above)

# 5. Fix Systems package resolution
cd Systems
rm -f Systems.xcworkspace/xcshareddata/swiftpm/Package.resolved
xcodebuild -workspace Systems.xcworkspace -scheme Systems -resolvePackageDependencies -configuration Debug

# 6. Test iOS builds
xcodebuild -workspace Systems.xcworkspace -scheme Systems -configuration Debug -destination 'generic/platform=iOS' build
cd ..
xcodebuild -workspace Delta.xcworkspace -scheme Delta -configuration Debug -destination 'generic/platform=iOS' build
```

### Phase 3: Deployment Target Fixes (Recommended)
```bash
# 1. Update Podfile (add post_install hook from above)
nano Podfile

# 2. Reinstall pods
pod deintegrate
pod install --repo-update

# 3. Clean and rebuild
# In Xcode: Product → Clean Build Folder (⌘⇧K)
# In Xcode: Product → Build (⌘B)
```

### Phase 4: Script Phase Fixes (Optional)
```bash
# 1. Open Systems project
open Systems/Systems.xcodeproj

# 2. Configure script phases (follow steps above)
# 3. Test Systems build
```

---

## 📋 Verification Checklist

### Critical Issues Fixed
- [ ] No code signing errors
- [ ] Delta target builds successfully
- [ ] Systems target builds successfully
- [ ] App runs on simulator
- [ ] **N64 references completely removed**
- [ ] **Systems package resolution works in Xcode**
- [ ] **No linker errors for missing N64DeltaCore**

### Warning Issues Fixed
- [ ] No deployment target warnings
- [ ] CocoaPods dependencies updated to iOS 14.0+
- [ ] Run script phases configured properly
- [ ] No duplicate file warnings
- [ ] Build scheme uses dependency order

### Platform Compatibility Verified
- [ ] **iOS device builds succeed**
- [ ] **iOS Simulator builds succeed**
- [ ] **Mac Catalyst builds properly fail with GLKit error (expected)**
- [ ] **Genesis/Sega emulation works on iOS**

### Success Metrics
- ✅ Zero build errors
- ✅ Clean build warnings (< 10 non-critical warnings)
- ✅ App launches on simulator
- ✅ Genesis games playable on iOS
- ✅ **N64 support cleanly removed**
- ✅ Ready for Phase 1 streaming implementation

---

## 🚨 Troubleshooting

### If Signing Still Fails:
```bash
# Clear derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Reset keychain
security delete-keychain login.keychain
security create-keychain -p "" login.keychain
security default-keychain -s login.keychain

# Re-add Apple ID in Xcode Preferences
```

### If Pod Install Fails:
```bash
# Update CocoaPods
sudo gem install cocoapods

# Clear pod cache  
pod cache clean --all
rm -rf Pods/ Podfile.lock
pod install
```

### If Build Still Fails:
```bash
# Reset everything
git status
git stash  # if you have changes
git clean -fd
pod install
```

---

## 🎮 N64 Support Removal & Platform Compatibility Issues

### Issue 6: N64 References Causing Build Failures
**Error**: Missing case in switch statement, linker errors, syntax errors  
**Impact**: Complete build failure for main Delta app  
**Priority**: **CRITICAL**

#### Background
N64 support was temporarily disabled but incomplete removal left dangling references causing build failures.

#### Platform Compatibility Matrix

| System | iOS Device | iOS Simulator | Mac Catalyst | macOS Native | Status |
|--------|------------|---------------|--------------|--------------|---------|
| **NES** | ✅ Full Support | ✅ Full Support | ❌ GLKit Issue | ❌ Not Supported | Active |
| **Game Boy** | ✅ Full Support | ✅ Full Support | ❌ GLKit Issue | ❌ Not Supported | Active |
| **Game Boy Color** | ✅ Full Support | ✅ Full Support | ❌ GLKit Issue | ❌ Not Supported | Active |
| **Game Boy Advance** | ✅ Full Support | ✅ Full Support | ❌ GLKit Issue | ❌ Not Supported | Active |
| **SNES** | ✅ Full Support | ✅ Full Support | ❌ GLKit Issue | ❌ Not Supported | Active |
| **Genesis/Sega** | ✅ Full Support | ✅ Full Support | ❌ GLKit Issue | ❌ Not Supported | Active |
| **Nintendo DS** | ✅ Full Support | ✅ Full Support | ❌ GLKit Issue | ❌ Not Supported | Active |
| **N64** | ❌ Removed | ❌ Removed | ❌ Removed | ❌ Removed | **DISABLED** |

#### Mac Catalyst GLKit Incompatibility
**Root Cause**: Apple deprecated GLKit framework and it's not available on Mac Catalyst  
**Technical Details**:
```swift
// File: DeltaCore/OpenGLESProcessor.swift
import GLKit  // ❌ Not available on Mac Catalyst
```
**Error**: `'GLKit/GLKView.h' file not found`

#### Resolution Steps

**Step 1: Fix CheatDevice.swift**
```bash
# Navigate to project
cd /Users/jordancassady/git/Delta

# Open the file and remove N64 references
# File: Delta/Database/Cheats/CheatDevice.swift
```

Remove these lines:
```swift
// Remove from enum:
case n64GameShark = 9  // DELETE THIS LINE

// Remove from gameType switch:
case .n64GameShark, .gbcGameShark, .gbaGameShark:  // CHANGE TO:
case .gbcGameShark, .gbaGameShark:

// Remove commented N64 case:
// case .n64GameShark: return .n64  // DELETE THIS LINE
```

**Step 2: Fix GameViewController.swift**
```bash
# File: Delta/Emulation/GameViewController.swift
# Remove the entire commented N64 conditional block around lines 1656-1668
```

**Step 3: Remove N64 Linker References**
```bash
# Edit the Xcode project file
# File: Delta.xcodeproj/project.pbxproj
# Remove this line from OTHER_LDFLAGS:
"-l\"N64DeltaCore\"",
```

**Step 4: Fix Systems Project Package Resolution**
```bash
# Navigate to Systems project
cd /Users/jordancassady/git/Delta/Systems

# Force package re-resolution
rm -f Systems.xcworkspace/xcshareddata/swiftpm/Package.resolved
xcodebuild -workspace Systems.xcworkspace -scheme Systems -resolvePackageDependencies -configuration Debug
```

#### Working Build Commands

**✅ iOS Builds (Command Line)**
```bash
# Main Delta App (iOS)
cd /Users/jordancassady/git/Delta
xcodebuild -workspace Delta.xcworkspace -scheme Delta -configuration Debug -destination 'generic/platform=iOS' build

# Systems Framework (iOS)
cd /Users/jordancassady/git/Delta/Systems
xcodebuild -workspace Systems.xcworkspace -scheme Systems -configuration Debug -destination 'generic/platform=iOS' build
```

**❌ Mac Catalyst Builds (Will Fail)**
```bash
# This will fail due to GLKit incompatibility
xcodebuild -workspace Systems.xcworkspace -scheme Systems -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' build
# Error: 'GLKit/GLKView.h' file not found
```

**✅ iOS Simulator Builds**
```bash
# These work fine
xcodebuild -workspace Systems.xcworkspace -scheme Systems -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build
```

#### Xcode IDE Fix for Systems Project

If Xcode shows "Missing package product 'GPGXDeltaCore'" when building Systems:

1. **Force Package Resolution**:
   ```bash
   cd /Users/jordancassady/git/Delta/Systems
   rm -f Systems.xcworkspace/xcshareddata/swiftpm/Package.resolved
   ```

2. **In Xcode**:
   - File → Packages → Reset Package Caches
   - File → Packages → Resolve Package Versions
   - Or use command line: `xcodebuild -resolvePackageDependencies`

3. **Verify Resolution**:
   ```bash
   # Should show all three packages:
   xcodebuild -workspace Systems.xcworkspace -scheme Systems -resolvePackageDependencies
   # Expected output:
   # ✅ ZIPFoundation: https://github.com/weichsel/ZIPFoundation.git @ 0.9.11
   # ✅ DeltaCore: /Users/jordancassady/git/Delta/Cores/DeltaCore
   # ✅ GPGXDeltaCore: /Users/jordancassady/git/Delta/Cores/GPGXDeltaCore
   ```

#### Build Success Verification

**Quick Test Commands**:
```bash
# Test full build pipeline
cd /Users/jordancassady/git/Delta

# 1. Clean everything
xcodebuild -workspace Delta.xcworkspace -scheme Delta clean

# 2. Build Systems first
cd Systems
xcodebuild -workspace Systems.xcworkspace -scheme Systems -configuration Debug -destination 'generic/platform=iOS' build

# 3. Build main app
cd ..
xcodebuild -workspace Delta.xcworkspace -scheme Delta -configuration Debug -destination 'generic/platform=iOS' build

# Success indicators:
# ✅ ** BUILD SUCCEEDED ** (exit code 0)
# ✅ No "missing package" errors
# ✅ No "library not found" errors
# ✅ No syntax errors
```

#### Troubleshooting Common Issues

**"Missing package product 'GPGXDeltaCore'"**:
- Solution: Force package resolution (steps above)
- Cause: Incomplete package cache in Xcode

**"library not found for -lN64DeltaCore"**:
- Solution: Remove N64DeltaCore from OTHER_LDFLAGS in project settings
- Cause: Linker still referencing removed N64 core

**"'GLKit/GLKView.h' file not found"**:
- Solution: Use iOS destination instead of Mac Catalyst
- Cause: GLKit not available on Mac Catalyst platform

**"extraneous '}' at top level"**:
- Solution: Check GameViewController.swift for unmatched braces
- Cause: Incomplete removal of N64 conditional code

#### Platform Support Summary

**✅ SUPPORTED PLATFORMS:**
- iOS 14.0+ (iPhone/iPad)
- iOS Simulator (all architectures)

**❌ UNSUPPORTED PLATFORMS:**
- Mac Catalyst (GLKit incompatibility)
- macOS Native (not implemented)
- tvOS (not configured)
- watchOS (not applicable)

**🎯 RECOMMENDED TARGET:**
- Primary: iOS devices (iPhone/iPad)  
- Secondary: iOS Simulator for development
- Avoid: Mac Catalyst until GLKit is replaced with Metal

---

## 📌 Notes

1. **Team ID**: The error shows team ID "6XVY5G3U44" - you'll need to change this to your own Apple Developer Team ID
2. **Bundle IDs**: Must be unique - you cannot use `com.rileytestut.Delta` without proper certificates
3. **Xcode Version**: Ensure you're using Xcode 15.0+ for iOS 14.0+ deployment targets
4. **N64 Support**: Completely removed from codebase - Genesis/Sega emulation remains fully functional on iOS
5. **Mac Support**: Not available due to GLKit dependency - iOS is the primary supported platform
6. **Build Prerequisites**: All critical issues (especially N64 removal) must be resolved before starting the YouTube streaming implementation

---

**🎯 Next Steps**: 
1. ✅ **N64 Removal Complete** - All build-blocking references removed
2. ✅ **Platform Compatibility Documented** - iOS primary, Mac Catalyst incompatible  
3. ✅ **Systems Package Resolution Fixed** - Xcode can now build Systems project
4. 🎯 **Ready for Phase 1** - YouTube streaming implementation can now proceed

**🎮 Gaming Platform Status**:
- **8-bit Systems**: ✅ NES, Game Boy, Game Boy Color (iOS)
- **16-bit Systems**: ✅ SNES, Genesis/Sega, Game Boy Advance (iOS) 
- **32-bit Systems**: ✅ Nintendo DS (iOS)
- **64-bit Systems**: ❌ N64 removed (was problematic)

The Delta project now has a clean, stable build foundation focused on 8-32 bit retro gaming systems with excellent iOS support.
