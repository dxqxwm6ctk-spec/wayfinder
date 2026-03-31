# 🚀 Quick Setup Checklist - Firebase & Microsoft Entra

## Android Quick Setup (5 minutes)

1. **Download google-services.json**
   ```
   Firebase Console → Project Settings → Google-services.json
   ↓ Place in: android/app/google-services.json
   ```

2. **Gradle files** ✅ (Already updated)
   - ✅ `android/build.gradle.kts` - Added Google Services classpath
   - ✅ `android/app/build.gradle.kts` - Added Google Services plugin
   - ✅ `android/app/src/main/AndroidManifest.xml` - Added permissions & Microsoft redirect

3. **Azure Configuration**
   - Azure Portal → App registrations → Wayfinder Mobile
   - Authentication → Add platform → Android
   - Enter package: `com.example.wayfinder`
   - Get signature hash from: `cd android && ./gradlew signingReport`
   - Copy SHA1 hash to Azure

4. **Test**
   ```bash
   flutter clean && flutter pub get
   flutter build apk
   ```

---

## iOS Quick Setup (10 minutes)

1. **Download GoogleService-Info.plist**
   ```
   Firebase Console → Project Settings → GoogleService-Info.plist
   ↓ Add to Xcode project:
     - Open: ios/Runner.xcworkspace (not .xcodeproj)
     - Drag GoogleService-Info.plist into Xcode
     - Check "Copy items" & "Add to targets: Runner"
   ```

2. **Install Pods** ✅ (Podfile already created)
   ```bash
   cd ios
   pod install --repo-update
   cd ..
   ```

3. **Configuration Files Updated** ✅
   - ✅ `ios/Podfile` - Created with Firebase & MSAL pods
   - ✅ `ios/Runner/Info.plist` - Added URL schemes & privacy descriptions

4. **Xcode Project Setup**
   - Open: `ios/Runner.xcworkspace`
   - Select Runner target
   - Signing & Capabilities tab:
     - Set Team (required)
     - Add Capability: **Push Notifications**
     - Add Capability: **Background Modes** → Remote notifications

5. **Azure Configuration**
   - Azure Portal → App registrations → Wayfinder Mobile
   - Authentication → Add platform → iOS/macOS
   - Bundle ID: `com.example.wayfinder`
   - Redirect URI: `msauth.com.example.wayfinder://auth`

6. **Test**
   ```bash
   flutter clean && flutter pub get
   open ios/Runner.xcworkspace
   # Build & run in Xcode, or:
   flutter run
   ```

---

## Configuration Values Needed

| Item | Where to Get | Where to Put |
|------|-------------|-------------|
| Azure Client ID | Azure Portal → App registrations → Overview | `lib/core/services/microsoft_auth_service.dart` line 16 |
| Azure Tenant ID | Azure Portal → App registrations → Overview | `lib/core/services/microsoft_auth_service.dart` line 17 |
| Android Package Name | `android/app/build.gradle.kts` | Firebase & Azure Console |
| iOS Bundle ID | `ios/Runner/Info.plist` CFBundleIdentifier | Firebase & Azure Console |
| Android Signature SHA1 | `./gradlew signingReport` | Azure Portal |

---

## Files Modified/Created

✅ **Android Files**
- `android/build.gradle.kts` - Updated
- `android/app/build.gradle.kts` - Updated
- `android/app/src/main/AndroidManifest.xml` - Updated
- `android/app/google-services.json` - TO ADD (from Firebase)

✅ **iOS Files**
- `ios/Podfile` - Created
- `ios/Runner/Info.plist` - Updated
- `ios/Runner/GoogleService-Info.plist` - TO ADD (from Firebase)

✅ **Documentation**
- `PLATFORM_SETUP_ANDROID_IOS.md` - Complete guide (you're reading part of it)
- `FIREBASE_MICROSOFT_SETUP.md` - Backend setup guide

---

## Testing Sequence

```bash
# 1. Clean everything
flutter clean
rm -rf ios/Pods ios/Podfile.lock
flutter pub get

# 2. Build & test
flutter run                    # Test on device/emulator

# 3. Verify logs
# Android: Android Studio Logcat (watch for Firebase init)
# iOS: Xcode Console (watch for pod warnings)

# 4. Quick test on real devices
# - Sign in with Email/Firebase
# - Sign in with Microsoft
# - Check Firestore console for user data
```

---

## Troubleshooting Quick Fixes

**"google-services.json not found" (Android)**
```bash
# Verify file location
ls -la android/app/google-services.json

# Should exist ✓
```

**"Pod not found" (iOS)**
```bash
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
cd ..
```

**"Firebase not initialized" (Both)**
- Verify google-services.json / GoogleService-Info.plist in project
- Check package names match Firebase project
- Restart app fully (not hot reload)

**Microsoft auth redirect fails**
- Verify signature hash (Android) matches Azure
- Verify Bundle ID (iOS) matches Azure
- Check redirect URI format: `scheme://host`

---

## Keys Configuration (Update These)

### After downloading credentials, update:

Use `--dart-define` values at run/build time (no code edit required):

```bash
flutter run \
   --dart-define=MICROSOFT_CLIENT_ID=REPLACE_WITH_AZURE_CLIENT_ID \
   --dart-define=MICROSOFT_TENANT_ID=REPLACE_WITH_AZURE_TENANT_ID \
   --dart-define=MICROSOFT_REDIRECT_URL=com.example.wayfinder://auth
```

---

## Final Checklist Before Testing

- [ ] `android/app/google-services.json` exists
- [ ] `ios/Pods` directory exists (after `pod install`)
- [ ] `ios/Runner/GoogleService-Info.plist` in Xcode
- [ ] Microsoft credentials updated in code
- [ ] Package names match Firebase & Azure
- [ ] Email domains configured (`EmailDomainPolicy`)
- [ ] Internet permission granted (Android)
- [ ] Signing configured (Xcode)

---

## Ready? 🚀

```bash
flutter run
# Tap "Student" → Choose auth method → Test!
```

**Next**: [Cloud Functions Setup](CLOUD_FUNCTIONS_SETUP.md) (optional)
