# Phase 1: Setup & Dependencies - Detailed Implementation Plan
## Delta YouTube Streaming Integration

**Duration**: 2 days  
**Scope**: Dependencies, project configuration, and YouTube API setup  
**Prerequisites**: Delta project builds successfully, Xcode 15.0+, iOS 14.0+

---

## 📋 Task Tracking Table

| Task | Type | Status | Duration | Dependencies | Notes |
|------|------|--------|----------|--------------|-------|
| **Day 1 Setup** | | | | | |
| 1.1 Create feature branch | Human | ⏳ | 5 min | Git access | Use terminal |
| 1.2 Backup current state | Human | ⏳ | 5 min | File access | Safety measure |
| 1.3 Open Delta workspace | Human | ⏳ | 2 min | Xcode installed | Delta.xcworkspace |
| 1.4 Add GoogleSignIn package | Human | ⏳ | 10 min | Internet access | Via Xcode SPM |
| 1.5 Add Google REST API package | Human | ⏳ | 10 min | Internet access | Via Xcode SPM |
| 1.6 Verify package integration | Human/AI | ⏳ | 5 min | Packages added | Build test |
| 1.7 Update Info.plist permissions | AI | ✅ | 5 min | File access | Camera/mic usage |
| 1.8 Add URL scheme to Info.plist | AI | ✅ | 5 min | Google credentials | OAuth callback |
| 1.9 Update entitlements | AI | ✅ | 5 min | File access | Keychain access |
| 1.10 Test build | Human | ⏳ | 3 min | All above complete | Verify no errors |
| **Day 2 API Setup** | | | | | |
| 2.1 Access Google Cloud Console | Human | ⏳ | 5 min | Google account | Browser required |
| 2.2 Create/select project | Human | ⏳ | 10 min | Cloud console access | "Delta Streaming" |
| 2.3 Enable YouTube Data API v3 | Human | ⏳ | 5 min | Project created | API Library |
| 2.4 Enable YouTube Live API | Human | ⏳ | 5 min | Project created | API Library |
| 2.5 Create OAuth 2.0 credentials | Human | ⏳ | 15 min | APIs enabled | iOS type |
| 2.6 Configure OAuth consent | Human | ⏳ | 10 min | Credentials created | Scopes & info |
| 2.7 Download GoogleService-Info.plist | Human | ⏳ | 2 min | OAuth configured | Replace existing |
| 2.8 Replace plist in Xcode | Human | ⏳ | 5 min | File downloaded | Backup old file |
| 2.9 Final build verification | Human | ⏳ | 5 min | All setup complete | End-to-end test |
| 2.10 Commit Phase 1 changes | Human | ⏳ | 5 min | Everything working | Git commit |

**Legend**: ⏳ Pending | ✅ Complete | ❌ Failed | 🔄 In Progress

---

## 🚀 Day 1: Dependencies & Project Configuration

### Step 1.1: Create Feature Branch
**👤 Human Task** | **Duration**: 5 minutes

1. **Open Terminal** and navigate to Delta project:
   ```bash
   cd /Users/jordancassady/git/Delta
   ```

2. **Create and switch to feature branch**:
   ```bash
   git checkout -b feature/youtube-streaming
   git push -u origin feature/youtube-streaming
   ```

3. **Verify branch creation**:
   ```bash
   git branch --show-current
   # Should output: feature/youtube-streaming
   ```

**✅ Success Criteria**: Terminal shows you're on `feature/youtube-streaming` branch

---

### Step 1.2: Backup Current State
**👤 Human Task** | **Duration**: 5 minutes

1. **Backup Podfile.lock**:
   ```bash
   cp Podfile.lock Podfile.lock.backup
   ```

2. **Backup current GoogleService-Info.plist**:
   ```bash
   cp "Delta/Supporting Files/GoogleService-Info.plist" "Delta/Supporting Files/GoogleService-Info.plist.backup"
   ```

3. **Verify backups exist**:
   ```bash
   ls -la *.backup
   ls -la "Delta/Supporting Files/"*.backup
   ```

**✅ Success Criteria**: Both backup files exist and show current date

---

### Step 1.3: Open Delta Workspace
**👤 Human Task** | **Duration**: 2 minutes

1. **Launch Xcode**
2. **Open workspace**: File → Open → Navigate to `/Users/jordancassady/git/Delta/Delta.xcworkspace`
3. **Wait for indexing** to complete
4. **Verify current scheme**: Should show "Delta" as active scheme

**✅ Success Criteria**: Xcode shows Delta workspace with all projects visible in navigator

---

### Step 1.4: Add GoogleSignIn Package
**👤 Human Task** | **Duration**: 10 minutes

1. **In Xcode**: File → Add Package Dependencies...

2. **Enter package URL**:
   ```
   https://github.com/google/GoogleSignIn-iOS
   ```

3. **Dependency Rule**: Select "Up to Next Major Version" with "7.0.0"

4. **Add to Target**: 
   - ✅ Check "Delta" 
   - ❌ Uncheck "DeltaPreviews"

5. **Click "Add Package"** and wait for resolution

6. **Verify installation**: 
   - Check Package Dependencies in Project Navigator
   - Should see "googlesignin-ios" listed

**📋 Package Details**:
- **Repository**: https://github.com/google/GoogleSignIn-iOS
- **Version**: 7.0.0 or later
- **License**: Apache 2.0

**✅ Success Criteria**: Package appears in Project Navigator under "Package Dependencies"

---

### Step 1.5: Add Google REST API Package
**👤 Human Task** | **Duration**: 10 minutes

1. **In Xcode**: File → Add Package Dependencies...

2. **Enter package URL**:
   ```
   https://github.com/googleapis/google-api-objectivec-client-for-rest
   ```

3. **Dependency Rule**: Select "Up to Next Major Version" with "3.0.0"

4. **Select Products to Add**:
   - ✅ Check "GoogleAPIClientForREST_YouTube"
   - ✅ Check "GoogleAPIClientForREST_Core"
   - ❌ Uncheck other products

5. **Add to Target**: 
   - ✅ Check "Delta"
   - ❌ Uncheck "DeltaPreviews"

6. **Click "Add Package"** and wait for resolution

**📋 Package Details**:
- **Repository**: https://github.com/googleapis/google-api-objectivec-client-for-rest
- **Version**: 3.0.0 or later
- **License**: Apache 2.0

**✅ Success Criteria**: Both packages appear in Package Dependencies section

---

### Step 1.6: Verify Package Integration
**👤 Human Task + 🤖 AI Task** | **Duration**: 5 minutes

1. **Human**: Press `Cmd+B` to build the project
2. **Wait for build completion**
3. **Human**: Report any build errors to AI
4. **AI**: Will help resolve any dependency conflicts if they occur

**Expected Result**: Build succeeds with no errors

**🚨 If Build Fails**: 
- Copy exact error messages
- AI will provide specific resolution steps
- May need to clean build folder (Shift+Cmd+K)

**✅ Success Criteria**: Project builds successfully with no errors or warnings related to packages

---

### Step 1.7: Update Info.plist Permissions
**🤖 AI Task** | **Duration**: 5 minutes

I'll update the Info.plist to add necessary permissions for camera and microphone access.

---

### Step 1.8: Add OAuth URL Scheme
**🤖 AI Task** | **Duration**: 5 minutes

I'll add the OAuth callback URL scheme to Info.plist. This will be updated with the actual client ID from Google Cloud Console on Day 2.

---

### Step 1.9: Update Entitlements
**🤖 AI Task** | **Duration**: 5 minutes

I'll update the entitlements file to add keychain access groups needed for secure token storage.

---

### Step 1.10: Test Build
**👤 Human Task** | **Duration**: 3 minutes

1. **Clean build folder**: Shift+Cmd+K
2. **Build project**: Cmd+B
3. **Verify no errors**
4. **Optional**: Run on simulator to verify app launches

**✅ Success Criteria**: Project builds and runs without errors

---

## 🌐 Day 2: YouTube API Setup

### Step 2.1: Access Google Cloud Console
**👤 Human Task** | **Duration**: 5 minutes

1. **Open browser** and navigate to:
   ```
   https://console.cloud.google.com/
   ```

2. **Sign in** with your Google account

3. **Verify access** to Google Cloud Console dashboard

**📋 Required Account**: Google account with Cloud Console access (free tier sufficient)

**✅ Success Criteria**: You see the Google Cloud Console dashboard

---

### Step 2.2: Create/Select Project
**👤 Human Task** | **Duration**: 10 minutes

**Option A: Create New Project**
1. **Click project dropdown** (top left, next to "Google Cloud")
2. **Click "New Project"**
3. **Project name**: `Delta Streaming`
4. **Organization**: Leave default or select your organization
5. **Click "Create"**
6. **Wait for project creation** (30-60 seconds)

**Option B: Use Existing Project**
1. **Click project dropdown**
2. **Select existing project** that has Google APIs enabled
3. **Verify project is selected** (name appears in top bar)

**📋 Project Requirements**:
- Billing enabled (required for YouTube APIs)
- Owner or Editor permissions
- APIs & Services access

**✅ Success Criteria**: Project name appears in top navigation bar

---

### Step 2.3: Enable YouTube Data API v3
**👤 Human Task** | **Duration**: 5 minutes

1. **Navigate to APIs & Services**:
   - Left menu → APIs & Services → Library
   - Or direct URL: `https://console.cloud.google.com/apis/library`

2. **Search for "YouTube Data API v3"**:
   - Type in search box: `YouTube Data API v3`
   - Click on the result

3. **Enable the API**:
   - Click "Enable" button
   - Wait for activation (10-30 seconds)

4. **Verify enablement**:
   - Should show "API Enabled" status
   - Green checkmark indicator

**📋 API Details**:
- **Full Name**: YouTube Data API v3
- **Purpose**: Access YouTube channel data and create broadcasts
- **Quota**: 10,000 units per day (free tier)

**✅ Success Criteria**: YouTube Data API v3 shows "Enabled" status in APIs list

---

### Step 2.4: Enable YouTube Live Streaming API
**👤 Human Task** | **Duration**: 5 minutes

1. **From APIs & Services Library**:
   - Search: `YouTube Live Streaming API`
   - Click on the result

2. **Enable the API**:
   - Click "Enable" button
   - Wait for activation

3. **Verify both APIs enabled**:
   - Navigate to: APIs & Services → Enabled APIs
   - Should see both YouTube APIs listed

**📋 API Details**:
- **Full Name**: YouTube Live Streaming API
- **Purpose**: Create and manage live streams
- **Quota**: Shared with YouTube Data API v3

**✅ Success Criteria**: Both YouTube APIs appear in "Enabled APIs" list

---

### Step 2.5: Create OAuth 2.0 Credentials
**👤 Human Task** | **Duration**: 15 minutes

1. **Navigate to Credentials**:
   - Left menu → APIs & Services → Credentials
   - Or: `https://console.cloud.google.com/apis/credentials`

2. **Create Credentials**:
   - Click "+ Create Credentials"
   - Select "OAuth client ID"

3. **Configure Application Type**:
   - Application type: **iOS**
   - Name: `Delta iOS App`

4. **Bundle ID Configuration**:
   - Bundle ID: `com.rileytestut.Delta` *(exact match required)*

5. **Create and Download**:
   - Click "Create"
   - **Download the configuration file** (GoogleService-Info.plist)
   - Save to Downloads folder

6. **Note the Client ID**:
   - Copy the "Client ID" value from the credentials page
   - Format: `xxxxx-yyyyy.apps.googleusercontent.com`
   - You'll need this for Info.plist

**📋 Credential Requirements**:
- **Type**: OAuth 2.0 Client ID
- **Application Type**: iOS
- **Bundle ID**: Must match Xcode project exactly
- **Authorized Domains**: Not needed for iOS

**✅ Success Criteria**: GoogleService-Info.plist file downloaded and Client ID copied

---

### Step 2.6: Configure OAuth Consent Screen
**👤 Human Task** | **Duration**: 10 minutes

1. **Navigate to OAuth Consent Screen**:
   - Left menu → APIs & Services → OAuth consent screen
   - Or: `https://console.cloud.google.com/apis/credentials/consent`

2. **User Type Selection**:
   - Choose **"External"** (for public app)
   - Click "Create"

3. **App Information**:
   - **App name**: `Delta Emulator`
   - **User support email**: Your email
   - **Developer contact email**: Your email
   - **App domain**: Leave blank for now
   - **App logo**: Skip for now

4. **Scopes Configuration**:
   - Click "Add or Remove Scopes"
   - Search and add these scopes:
     - `https://www.googleapis.com/auth/youtube.readonly`
     - `https://www.googleapis.com/auth/youtube`
   - Click "Update"

5. **Test Users** (for development):
   - Add your Google account email
   - Click "Add Users"

6. **Review and Submit**:
   - Review all information
   - Click "Back to Dashboard"

**📋 Required Scopes**:
- **youtube.readonly**: Read YouTube channel data
- **youtube**: Manage YouTube live streams and broadcasts

**✅ Success Criteria**: OAuth consent screen configured with required scopes

---

### Step 2.7: Download GoogleService-Info.plist
**👤 Human Task** | **Duration**: 2 minutes

1. **Return to Credentials page**
2. **Find your iOS OAuth client**
3. **Download GoogleService-Info.plist**:
   - Click download icon next to your iOS client
   - Save to easily accessible location

4. **Verify file contents**:
   - Open in text editor
   - Confirm CLIENT_ID and REVERSED_CLIENT_ID are present
   - Bundle ID should match `com.rileytestut.Delta`

**📋 File Location**: Usually downloads to `~/Downloads/GoogleService-Info.plist`

**✅ Success Criteria**: Valid GoogleService-Info.plist file ready for Xcode

---

### Step 2.8: Replace GoogleService-Info.plist in Xcode
**👤 Human Task** | **Duration**: 5 minutes

1. **In Xcode Navigator**:
   - Navigate to Delta → Supporting Files
   - Find existing `GoogleService-Info.plist`

2. **Replace the file**:
   - Right-click existing GoogleService-Info.plist
   - Choose "Delete" → "Move to Trash"
   - Drag new GoogleService-Info.plist from Downloads into Supporting Files folder
   - Verify "Add to target: Delta" is checked
   - Click "Add"

3. **Update Info.plist URL Scheme**:
   - Open Delta → Supporting Files → Info.plist
   - Find CFBundleURLSchemes array
   - Update the Google URL scheme with your REVERSED_CLIENT_ID from GoogleService-Info.plist

**🚨 Critical**: The URL scheme in Info.plist must match REVERSED_CLIENT_ID exactly

**✅ Success Criteria**: New GoogleService-Info.plist in project with correct CLIENT_ID

---

### Step 2.9: Final Build Verification
**👤 Human Task** | **Duration**: 5 minutes

1. **Clean Build Folder**: Shift+Cmd+K
2. **Build Project**: Cmd+B
3. **Check for Errors**:
   - Should build successfully
   - No missing import errors
   - No configuration errors

4. **Test Run** (Optional):
   - Run on simulator: Cmd+R
   - Verify app launches normally
   - Check that new packages don't cause crashes

**Expected Warnings**: You may see warnings about unused imports - this is normal

**✅ Success Criteria**: Project builds and runs without errors

---

### Step 2.10: Commit Phase 1 Changes
**👤 Human Task** | **Duration**: 5 minutes

1. **Check status**:
   ```bash
   git status
   ```

2. **Add changes**:
   ```bash
   git add .
   ```

3. **Commit with descriptive message**:
   ```bash
   git commit -m "Phase 1: Add YouTube streaming dependencies and API setup

   - Added GoogleSignIn-iOS and Google REST API packages via SPM
   - Updated Info.plist with camera/microphone permissions
   - Added OAuth URL scheme for YouTube authentication
   - Updated entitlements for keychain access
   - Replaced GoogleService-Info.plist with YouTube API credentials
   - Enabled YouTube Data API v3 and Live Streaming API in Google Cloud Console"
   ```

4. **Push to remote**:
   ```bash
   git push origin feature/youtube-streaming
   ```

**✅ Success Criteria**: Changes committed and pushed to feature branch

---

## 🔧 Troubleshooting Guide

### Build Errors
**Problem**: Package resolution fails
**Solution**: 
```bash
# Clear Xcode caches
rm -rf ~/Library/Developer/Xcode/DerivedData
# Reset package caches
File → Packages → Reset Package Caches (in Xcode)
```

**Problem**: Duplicate symbol errors
**Solution**: Check for conflicting CocoaPods dependencies, may need to exclude certain pods

### Google Cloud Console Issues
**Problem**: "Billing account required"
**Solution**: Enable billing in Google Cloud Console (free tier available)

**Problem**: "API not enabled"
**Solution**: Double-check both YouTube APIs are enabled in APIs & Services

### OAuth Configuration
**Problem**: Invalid client ID
**Solution**: Ensure Bundle ID in Google Cloud matches Xcode project exactly

**Problem**: Redirect URI mismatch
**Solution**: Verify REVERSED_CLIENT_ID in Info.plist matches Google Cloud credentials

---

## 📊 Phase 1 Completion Checklist

### Day 1 Deliverables
- [ ] Feature branch created and active
- [ ] GoogleSignIn-iOS package integrated
- [ ] Google REST API package integrated
- [ ] Info.plist updated with permissions
- [ ] Entitlements updated
- [ ] Project builds successfully

### Day 2 Deliverables
- [ ] Google Cloud Console project configured
- [ ] YouTube Data API v3 enabled
- [ ] YouTube Live Streaming API enabled
- [ ] OAuth 2.0 credentials created
- [ ] OAuth consent screen configured
- [ ] GoogleService-Info.plist replaced
- [ ] Final build verification passed
- [ ] Changes committed to feature branch

### Success Metrics
- ✅ Zero build errors
- ✅ All required APIs enabled
- ✅ OAuth flow configured (not yet tested)
- ✅ Project ready for Phase 2 implementation

---

**🎯 Phase 1 Complete!** Ready to proceed to Phase 2: Core Implementation

**Next Phase Preview**: We'll implement the StreamingManager, YouTubeStreamingClient, and core architecture components.
