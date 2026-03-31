# Android & iOS Platform Setup Guide

This guide covers platform-specific configuration for Firebase and Microsoft Entra integration.

---

## ANDROID SETUP

### Step 1: Download google-services.json from Firebase

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your **Wayfinder** project
3. Go to **Project Settings** (gear icon)
4. Click **"Google-services.json"** button
5. Download the file
6. **IMPORTANT**: Place the file at: `android/app/google-services.json`

```
wayfinder/
├── android/
│   ├── app/
│   │   ├── build.gradle.kts ✓ (updated)
│   │   ├── google-services.json ← PASTE HERE
│   │   └── src/
│   │       └── main/
│   │           └── AndroidManifest.xml ✓ (updated)
│   ├── build.gradle.kts ✓ (updated)
│   └── ...
```

### Step 2: Configure Android Package Name

**If you changed the package name from `com.example.wayfinder`:**

1. In Firebase Console → **Project Settings** → **General**
2. Find your Android app
3. Click the menu (⋯) → **Edit**
4. Update the **Android package name** to match your actual package
5. Re-download `google-services.json`

### Step 3: Microsoft Entra Configuration

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** → **App registrations**
3. Select your **Wayfinder Mobile** app
4. Go to **Authentication** → **Add a platform**
5. Select **Android**
6. Enter:
   - **Package name**: `com.example.wayfinder` (or your actual package)
   - **Signature hash**: Get from below
   - **Redirect URI**: Will be auto-generated
7. Click **Configure**

#### Get Android Signature Hash:

**Option A - Using keytool (Recommended):**
```bash
# For debug key
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Look for "SHA1" line, copy it
# The format is like: AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12
```

**Option B - Using Android Studio:**
1. Open Android Studio
2. Open **Gradle** pane (right side)
3. Run: `android/gradlew signingReport`
4. Look for `theDebugSigningConfig`
5. Copy the SHA1 value

**Option C - Using Flutter (Easiest):**
```bash
cd android
./gradlew signingReport
```

### Step 4: Verify Gradle Configuration

The following files have been updated:

**android/build.gradle.kts** ✓
```gradle
buildscript {
    dependencies {
        classpath("com.google.gms:google-services:4.4.0")
        classpath("com.google.firebase:firebase-crashlytics-gradle:2.9.9")
    }
}
```

**android/app/build.gradle.kts** ✓
```gradle
plugins {
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}
```

### Step 5: AndroidManifest.xml Configuration

**Already Updated** ✓
- ✅ Required permissions: INTERNET, ACCESS_NETWORK_STATE, POST_NOTIFICATIONS, LOCATION
- ✅ Microsoft Entra redirect scheme: `com.example.wayfinder://auth`
- ✅ Intent filters configured

### Step 6: Test Android Build

```bash
# Clean build
flutter clean
flutter pub get

# Build APK
flutter build apk

# Or run on device
flutter run
```

### Step 7: Troubleshooting Android

| Issue | Solution |
|-------|----------|
| `google-services.json not found` | Verify file is in `android/app/` |
| Gradle sync fails | Run `flutter pub get` then sync in Android Studio |
| Firebase crash at startup | Check google-services.json package name matches |
| Microsoft auth redirect fails | Verify signature hash in Azure matches your build |
| `Could not determine the dependencies` | Run `flutter clean && flutter pub get` |

---

## iOS SETUP

### Step 1: Download GoogleService-Info.plist from Firebase

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your **Wayfinder** project
3. Go to **Project Settings** (gear icon)
4. Click on your **iOS app**
5. Click **"GoogleService-Info.plist"** button
6. Download the file
7. **IMPORTANT**: 
   - Open **Xcode** workspace: `ios/Runner.xcworkspace`
   - Drag `GoogleService-Info.plist` into Xcode
   - ✅ Check **"Copy items if needed"**
   - ✅ Check **"Add to targets: Runner"**
   - Click **"Finish"**

```
wayfinder/
├── ios/
│   ├── Runner/
│   │   ├── GoogleService-Info.plist ← PASTE IN XCODE
│   │   ├── Info.plist ✓ (updated)
│   │   └── Assets.xcassets/
│   ├── Runner.xcworkspace/ ← OPEN THIS (not .xcodeproj)
│   ├── Podfile ✓ (created)
│   └── ...
```

### Step 2: Update Podfile

**Already Created** ✓

The `Podfile` includes:
- Firebase/Core, Firebase/Auth, Firebase/Firestore
- Firebase/Messaging, Firebase/Analytics, Firebase/Crashlytics
- MSAL (Microsoft Entra)
- GoogleSignIn

### Step 3: Install Pods

```bash
cd ios
pod install --repo-update
cd ..
```

This will install all Firebase and Microsoft dependencies.

### Step 4: Extract Firebase Credentials

From `GoogleService-Info.plist`, you'll need:

1. Open `GoogleService-Info.plist` in Xcode or text editor
2. Find these keys (you may need them for custom setup):
   - `GOOGLE_APP_ID`
   - `CLIENT_ID`
   - `BUNDLE_ID` (should match your app bundle)
   - `REVERSED_CLIENT_ID` (used for URL schemes)

### Step 5: Update Info.plist

**Already Updated** ✓

Google credentials automatically added to URL schemes from `GoogleService-Info.plist`.

The following has been configured:
```xml
<!-- Microsoft Entra URL Scheme -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>msauth.com.example.wayfinder</string>
        </array>
    </dict>
</array>

<!-- Privacy Descriptions -->
<key>NSLocationWhenInUseUsageDescription</key>
<key>NSCameraUsageDescription</key>
<key>NSMicrophoneUsageDescription</key>
<key>NSContactsUsageDescription</key>
```

### Step 6: Microsoft Entra Configuration

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** → **App registrations**
3. Select your **Wayfinder Mobile** app
4. Go to **Authentication** → **Add a platform**
5. Select **iOS/macOS**
6. Enter:
   - **Bundle ID**: Match your iOS app bundle (usually `com.example.wayfinder`)
   - **Redirect URI**: `msauth.{bundleId}://auth`
   
   Example: `msauth.com.example.wayfinder://auth`

7. Click **Configure**

### Step 7: Configure Xcode Project

**Open in Xcode workspace (not .xcodeproj):**
```bash
open ios/Runner.xcworkspace
```

#### In Signing & Capabilities:

1. Select **Runner** project (left sidebar)
2. Select **Runner** target
3. Go to **"Signing & Capabilities"** tab
4. Ensure **Team** is set (required for development)
5. Set **Bundle Identifier** if needed

#### Add Capabilities:

1. Click **"+ Capability"** button
2. Search and add:
   - ✅ **Push Notifications** (for FCM)
   - ✅ **Background Modes**
     - Select: "Remote notifications"
   - ✅ **Sign in with Apple** (optional, for SSO)

### Step 8: Update AppDelegate.swift (Optional)

The default Flutter AppDelegate is sufficient, but you can add Firebase configuration:

```swift
import Flutter
import FirebaseCore
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Initialize Firebase
    if #available(iOS 11.0, *) {
      FirebaseApp.configure()
    }
    
    // Request notification permissions
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .sound, .badge]
    ) { granted, error in
      DispatchQueue.main.async {
        UIApplication.shared.registerForRemoteNotifications()
      }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### Step 9: Test iOS Build

```bash
# Clean build
flutter clean
flutter pub get

# Run on simulator
flutter run

# Or build for device
flutter build ios --release
```

### Step 10: Troubleshooting iOS

| Issue | Solution |
|-------|----------|
| `Podfile error` | Run `cd ios && pod install --repo-update && cd ..` |
| `GoogleService-Info.plist not found` | Verify file is in Xcode project and Build Phases includes it |
| Pod conflicts (especially Firebase) | Delete `iOS/Pods`, `iOS/Podfile.lock`, run `pod install --repo-update` |
| Missing "Sign in with Apple" | Add capability in Xcode → Signing & Capabilities |
| Missing symbols (`_OBJC_CLASS_$_Firebase...`) | Ensure all Pods are properly linked in Build Phases |
| App crashes on launch | Check Console for Firebase initialization errors |
| Microsoft auth fails | Verify Bundle ID matches Azure configuration |

---

## COMMON SETUP VERIFICATION CHECKLIST

### Android ✓
- [ ] `google-services.json` placed in `android/app/`
- [ ] `build.gradle.kts` files updated with Google Services plugin
- [ ] `AndroidManifest.xml` has permissions and Microsoft redirect scheme
- [ ] Package name matches Firebase and Azure configurations
- [ ] Run `flutter build apk` successfully

### iOS ✓
- [ ] `GoogleService-Info.plist` added to Xcode project
- [ ] `Podfile` created and pods installed (`pod install`)
- [ ] `Info.plist` updated with URL schemes and privacy descriptions
- [ ] Xcode project has signing configured
- [ ] Capabilities added: Push Notifications + Background Modes
- [ ] Bundle ID matches Firebase and Azure configurations
- [ ] Run `flutter build ios --release` successfully

### Both Platforms
- [ ] Firebase Credentials:
  - [ ] Client ID stored
  - [ ] API key stored
- [ ] Microsoft Entra Credentials:
  - [ ] Client ID stored
  - [ ] Tenant ID stored
  - [ ] Redirect URIs registered in Azure
- [ ] Email Domain Policy:
  - [ ] `iu.edu.co` configured as allowed domain
  - [ ] Any other university domains added

---

## ENVIRONMENT VARIABLES & CONFIGURATION

### Set via flutter run

```bash
# Development
flutter run \
  --dart-define=ALLOWED_STUDENT_EMAIL_DOMAINS="iu.edu.co,university.edu" \
  --dart-define=USE_MOCK=false

# Production
flutter run --release \
  --dart-define=ALLOWED_STUDENT_EMAIL_DOMAINS="iu.edu.co" \
  --dart-define=API_BASE_URL=https://api.wayfinder.com
```

### Update Microsoft Credentials

In `lib/core/services/microsoft_auth_service.dart`:

```dart
static const String _clientId = 'YOUR_AZURE_CLIENT_ID';
static const String _tenantId = 'YOUR_AZURE_TENANT_ID';
static const String _redirectUrl = 'com.example.wayfinder://auth'; // iOS & Android
```

In `lib/main.dart`:

```dart
MicrosoftAuthService.configure(
  clientId: 'YOUR_AZURE_CLIENT_ID',
  redirectUrl: 'com.example.wayfinder://auth',
  tenantId: 'YOUR_AZURE_TENANT_ID',
);
```

---

## NEXT STEPS

1. ✅ Complete Android setup (google-services.json)
2. ✅ Complete iOS setup (GoogleService-Info.plist + Pods)
3. → Test authentication flows on real devices
4. → Setup Cloud Functions for backend logic
5. → Implement FCM push notifications
6. → Deploy to production

---

## RESOURCES

- [Firebase Flutter Documentation](https://firebase.flutter.dev/)
- [Firebase Console](https://console.firebase.google.com)
- [Azure AD / Microsoft Entra](https://portal.azure.com)
- [Flutter App Signing Guide](https://flutter.dev/docs/deployment/android#signing)
- [iOS Deployment & Signing](https://flutter.dev/docs/deployment/ios#signing)

---

**Last Updated**: March 2026  
**Version**: 1.0.0
