# Firebase & Microsoft Entra Integration Guide for Wayfinder

## Overview

Wayfinder now supports multiple authentication methods:
1. **Microsoft Entra (Azure AD)** - For university email-based authentication
2. **Firebase Authentication** - Email/password and Google Sign-In
3. **Mock Mode** - For development/testing

This guide will walk you through setting up both systems.

---

## Part 1: Firebase Setup

### Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click **"Create a project"**
3. Enter project name: `Wayfinder` (or your choice)
4. Select region and agree to terms
5. Click **"Create project"**

### Step 2: Add Flutter App to Firebase

1. In Firebase Console, click **"Add app"** → **"Flutter"**
2. Enter package name: `com.example.wayfinder`
3. Click **"Register app"**
4. Follow the download instructions:
   - **For Android**: Download `google-services.json` and place in `android/app/`
   - **For iOS**: Download `GoogleService-Info.plist` and add to Xcode project
   - **For Web**: Copy the Firebase config (we'll use this if adding web support)

### Step 3: Enable Authentication Methods

In Firebase Console → **Authentication** → **Sign-in method**:

1. **Email/Password**:
   - Click **Email/Password**
   - Enable **"Email/Password"**
   - Enable **"Email link (passwordless sign-in)"** (optional)
   - Save

2. **Google Sign-In**:
   - Click **Google**
   - Enable it
   - Add support email
   - Save

### Step 4: Create Firestore Database

In Firebase Console → **Firestore Database**:

1. Click **"Create database"**
2. Choose **"Start in test mode"** (for development)
   - ⚠️ Later, setup security rules for production
3. Select region closest to your users
4. Click **"Create"**

### Step 5: Setup Firestore Collections

Create these collections:

```
Collection: users
Document: {uid}
Fields:
  - email: string
  - name: string
  - role: string ("student" or "leader")
  - authMethod: string ("firebase", "microsoft", "google")
  - createdAt: timestamp
  - updatedAt: timestamp

Collection: zones
Document: {zoneId}
Fields:
  - name: string
  - location: geo_point
  - studentsWaiting: array
  - busAssignment: string (busId)
  - createdAt: timestamp
  - updatedAt: timestamp

Collection: buses
Document: {busId}
Fields:
  - number: string
  - zoneId: string
  - capacity: number
  - currentStudents: array
  - status: string ("idle", "assigned", "in_transit")
  - createdAt: timestamp
  - updatedAt: timestamp

Collection: rideRequests
Document: {requestId}
Fields:
  - studentId: string
  - zoneId: string
  - busId: string (after assignment)
  - status: string ("pending", "assigned", "completed", "cancelled")
  - createdAt: timestamp
  - updatedAt: timestamp
  - completedAt: timestamp (optional)

Collection: activityLogs
Document: auto-generated
Fields:
  - userId: string
  - action: string
  - timestamp: timestamp
  - additionalData: map

Collection: tripLogs
Document: auto-generated
Fields:
  - studentId: string
  - zoneId: string
  - busId: string
  - durationSeconds: number
  - completedAt: timestamp
```

### Step 6: Setup Firestore Security Rules

Go to **Firestore** → **Rules** and replace with:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
      allow read: if request.auth.uid != null; // Leaders can read other users
    }
    
    // Allow students to read zones and create requests
    match /zones/{zoneId} {
      allow read: if request.auth.uid != null;
      allow write: if request.auth.token.role == 'leader';
    }
    
    // Allow buses to be read by authenticated users
    match /buses/{busId} {
      allow read: if request.auth.uid != null;
      allow write: if request.auth.token.role == 'leader';
    }
    
    // Allow students to create ride requests
    match /rideRequests/{requestId} {
      allow create: if request.auth.uid == request.resource.data.studentId;
      allow read: if request.auth.uid == resource.data.studentId || request.auth.token.role == 'leader';
      allow update: if request.auth.token.role == 'leader';
    }
    
    // Activity logs
    match /activityLogs/{docId} {
      allow create: if request.auth.uid != null;
      allow read: if request.auth.token.role == 'leader';
    }
    
    // Trip logs
    match /tripLogs/{docId} {
      allow create: if request.auth.uid != null;
      allow read: if request.auth.token.role == 'leader';
    }
  }
}
```

---

## Part 2: Microsoft Entra Setup

### Step 1: Register Application in Azure Portal

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** → **App registrations**
3. Click **"New registration"**
4. Fill in:
   - **Name**: `Wayfinder Mobile`
   - **Supported account types**: `Accounts in this organizational directory only`
   - **Redirect URI**: 
     - Platform: **Mobile and desktop applications**
     - URI: `com.example.wayfinder://auth`
5. Click **"Register"**

### Step 2: Get Client ID & Tenant ID

1. In the app registration, copy:
   - **Application (client) ID** - Save as `CLIENT_ID`
   - **Directory (tenant) ID** - Save as `TENANT_ID`

### Step 3: Create Client Secret (Optional, for server-to-server auth)

1. Go to **Certificates & secrets**
2. Click **"New client secret"**
3. Set expiration and create
4. Copy the secret immediately (won't be visible again)
5. Save as `CLIENT_SECRET`

### Step 4: Configure API Permissions

1. Go to **API permissions**
2. Click **"Add a permission"**
3. Select **Microsoft Graph**
4. Choose **Delegated permissions**
5. Search and add:
   - `openid`
   - `profile`
   - `email`
   - `offline_access`
   - `User.Read`
6. Click **"Grant admin consent"**

### Step 5: Configure Authentication Settings (Mobile)

1. Go to **Authentication**
2. Under **Platform configurations**, click **"Add a platform"**
3. Select **"Mobile and desktop applications"**
4. Add redirect URI: `com.example.wayfinder://auth`
5. Under **Advanced settings**, enable:
   - **Allow public client flows**: `Yes`
6. Click **"Configure"**

### Step 6: Pass Microsoft values at runtime

Run the app with `--dart-define` values (no code edit required):

```bash
flutter run \
  --dart-define=MICROSOFT_CLIENT_ID=YOUR_CLIENT_ID \
  --dart-define=MICROSOFT_TENANT_ID=YOUR_TENANT_ID \
  --dart-define=MICROSOFT_REDIRECT_URL=com.example.wayfinder://auth
```

---

## Part 3: Implementation in Code

### Using Firebase Services

```dart
// In any screen or widget
final firebaseService = FirebaseService();

// Sign up with email
final credential = await firebaseService.signUpWithEmail(
  email: 'student@iu.edu.co',
  password: 'password123'
);

// Sign in with Google
final googleCredential = await firebaseService.signInWithGoogle();

// Save user to Firestore
await firebaseService.saveUserData(uid, {
  'email': 'student@iu.edu.co',
  'role': 'student',
});
```

### Using Microsoft Services

```dart
// In any screen
final microsoftService = MicrosoftAuthService();

// Sign in with Microsoft
final result = await microsoftService.signInWithMicrosoft();

if (result != null) {
  print('User: ${result.email}');
  print('Access Token: ${result.accessToken}');
  print('Refresh Token: ${result.refreshToken}');
}
```

### Using Firestore Services

```dart
// In any screen or provider
final firestoreService = FirestoreDataService();

// Get all zones
final zones = await firestoreService.getZones();

// Stream of real-time updates
firestoreService.getZonesStream().listen((snapshot) {
  print('Zones updated: ${snapshot.docs.length}');
});

// Create ride request
final requestId = await firestoreService.createRideRequest(
  studentId: userId,
  zoneId: 'zone123',
  requestData: {
    'pickupLocation': 'Building A',
    'destination': 'Campus Gate',
  },
);
```

### Using UnifiedAuthProvider in Widgets

```dart
// In any widget
final auth = Provider.of<UnifiedAuthProvider>(context);

// Check if user is authenticated
if (auth.isAuthenticated) {
  print('Logged in as: ${auth.currentEmail}');
}

// Sign in with email
final result = await auth.signInWithFirebase(email, password);

// Sign in with Microsoft
final msResult = await auth.signInWithMicrosoft();

// Sign out
await auth.signOut();

// Access allowed email domains
print('Allowed domains: ${auth.allowedDomains}');
```

---

## Part 4: Configuration via Environment Variables

### Run with Firebase

```bash
# Android/iOS
flutter run

# Or with specific build configuration
flutter run --flavor dev
```

### Run with Microsoft Entra

Set your credentials:

```bash
flutter run \
  --dart-define=API_BASE_URL=https://your-api.com \
  --dart-define=USE_MOCK=false
```

### Run with Mock (Development)

```bash
flutter run \
  --dart-define=USE_MOCK=true
```

---

## Part 5: Testing Accounts

### For Development

**Firebase Email/Password:**
- Email: `student@iu.edu.co`
- Password: `demo1234` (must be 6+ chars)

**Microsoft/Google:**
- Use your actual Microsoft or Google account

**Mock Login:**
- Any email matching allowed domains (default: `university.edu`, `iu.edu.co`)
- Password: any 6+ character string

---

## Part 6: Troubleshooting

### Firebase Issues

**Error: "Firebase not initialized"**
- Ensure `FirebaseService().initialize()` is called in `main()` before runApp()

**Error: "Permission denied" in Firestore**
- Check Firestore security rules
- Ensure user is authenticated

**Error: "Invalid email domain"**
- Update `ALLOWED_STUDENT_EMAIL_DOMAINS` dart-define
- Or modify `EmailDomainPolicy.dart`

### Microsoft Entra Issues

**Error: "Authorization cancelled"**
- User closed the Microsoft login dialog
- Ensure Azure app is properly configured

**Error: "Invalid redirect_uri"**
- Check redirect URI in Azure matches Flutter app configuration
- Format should be: `com.example.wayfinder://auth`

**Error: "AADSTS50105: The app needs to perform an action"**
- Often means the app registration needs tenant-specific configuration
- Go to Azure Portal → Manifest and check `signInAudience` is set to `AzureADMyOrg`

### Common Issues

| Error | Solution |
|-------|----------|
| Firestore timeout | Check internet connection, verify rules |
| Microsoft auth loop | Clear app cache, re-authenticate |
| Email validation fails | Check allowed domains in EmailDomainPolicy |
| FCM tokens not received | Ensure permissions granted, check Firebase setup |

---

## Part 7: Production Checklist

- [ ] Update `ALLOWED_STUDENT_EMAIL_DOMAINS` with actual university domains
- [ ] Update Microsoft Azure credentials with production client IDs
- [ ] Setup Firestore security rules for production (not test mode)
- [ ] Enable multi-factor authentication (MFA) in Azure
- [ ] Setup Cloud Functions for backend logic
- [ ] Configure Firebase Cloud Messaging for credentials
- [ ] Test all authentication flows on real devices
- [ ] Setup error monitoring and logging
- [ ] Configure database backups and recovery
- [ ] Implement rate limiting on API endpoints

---

## Part 8: Next Steps

1. **Setup Cloud Functions** for server-side logic
2. **Implement FCM** for push notifications
3. **Configure Analytics** for usage tracking
4. **Setup Monitoring** with Firebase Crashlytics
5. **Integrate with Isla Backend** via Cloud Functions

---

## Quick Reference

| Component | File | Purpose |
|-----------|------|---------|
| Firebase | `lib/core/services/firebase_service.dart` | Firebase initialization & auth |
| Microsoft | `lib/core/services/microsoft_auth_service.dart` | Microsoft Entra OAuth2 |
| Firestore | `lib/core/services/firestore_data_service.dart` | Database operations |
| Unified Auth | `lib/presentation/providers/unified_auth_provider.dart` | Combined auth provider |
| Auth Selection | `lib/presentation/screens/auth_method_selection_screen.dart` | Auth method chooser |
| Firebase Login | `lib/presentation/screens/firebase_login_screen.dart` | Email/password UI |
| Microsoft Login | `lib/presentation/screens/microsoft_login_screen.dart` | Microsoft Entra UI |

---

**Last Updated**: March 2026
**Version**: 1.0.0
