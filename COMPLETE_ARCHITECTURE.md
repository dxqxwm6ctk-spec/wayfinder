# 🚀 Wayfinder - حل شامل لإدارة طلبات الرحلات

## نظرة عامة على الحل

تم تطبيق حل احترافي يضمن الحفاظ على بيانات طلب الطالب على السيرفر (Firebase Firestore) بدلاً من التخزين المحلي فقط. هذا يعني أن الطلب سيبقى محفوظًا حتى لو حذف الطالب التطبيق أو سجّل الخروج.

---

## 📋 التصميم المعماري (Architecture)

### البنية الكاملة:

```
┌─────────────────────────────────────────────────────────────────┐
│                         Frontend (Flutter)                       │
│  - RequestRideScreen (Student)                                   │
│  - StatusScreen (Student Status)                                 │
│  - LeaderWebScreen / Dashboard (Leader)                          │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────┐
        │   Firebase Authentication    │
        │   (Firebase Auth)            │
        │   - Student Login            │
        │   - UID as Key               │
        └──────────────────┬───────────┘
                           │
                           ▼
        ┌──────────────────────────────┐
        │    Cloud Firestore (DB)      │
        │                              │
        │  Collections:                │
        │  ├─ users/{uid}              │
        │  ├─ zones/                   │
        │  ├─ buses/                   │
        │  └─ studentRequests/{uid}    │
        │     (الطلبات الرئيسية)       │
        └──────────────────────────────┘
                           ▲
                           │
                           ▼
        ┌──────────────────────────────┐
        │   Firestore Security Rules   │
        │   (Permissions & Access)     │
        └──────────────────────────────┘
```

---

## 🗄️ تصميم قاعدة البيانات

### 1️⃣ مجموعة `studentRequests` - الطلبات الطلابية

**المسار:** `studentRequests/{uid}`
- `uid`: معرّف فريد للطالب (من Firebase Auth)

**الحقول:**

```json
{
  "uid": "student-uid-123",
  "userId": "student-uid-123",
  "studentId": "student-uid-123",
  "email": "student@university.edu",
  "name": "أحمد محمد",
  "status": "pending",          // pending | accepted | rejected | cancelled
  "hasActiveRequest": true,
  "pickupArea": "Medical Building",
  "activeRequestArea": "Medical Building",
  "zoneId": "zone-med-building",
  "photoUrl": "https://...",
  "confirmedAt": "2024-01-15T10:30:00Z",
  "acceptedAt": null,           // يُملأ عند قبول الطلب
  "rejectedAt": null,           // يُملأ عند رفض الطلب
  "cancelledAt": null,          // يُملأ عند إلغاء الطلب
  "rejectionReason": null,      // سبب الرفض إن وُجد
  "assignedBusId": null,        // معرّف الحافلة المخصصة
  "updatedAt": "2024-01-15T10:30:00Z"
}
```

### 2️⃣ مجموعة `users` - ملفات الطلاب

```json
{
  "uid": "student-uid-123",
  "email": "student@university.edu",
  "name": "أحمد محمد",
  "role": "student",
  "photoUrl": "https://...",
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-15T10:30:00Z"
}
```

### 3️⃣ مجموعة `zones` - المناطق

```json
{
  "id": "zone-med-building",
  "name": "Medical Building",
  "location": "Campus A",
  "studentsWaiting": 5,
  "assignedBus": "BUS-12",
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-15T10:30:00Z"
}
```

---

## 🔄 تدفق الطلب (Request Flow)

### 1. الطالب يطلب رحلة (Student Submits Request)

```
الطالب يختار منطقة الالتقاء ويضغط "تأكيد الطلب"
         ↓
TransitProvider.executeImmediateRequest()
         ↓
يتم تحديث الحالة المحلية في الـ Provider
         ↓
_syncActiveRequestToRemoteNow() ← هذا هو المفتاح!
         ↓
FirestoreDataService.saveStudentActiveRequest()
         ↓
كتابة الوثيقة إلى: studentRequests/{uid}
{
  hasActiveRequest: true,
  status: "pending",
  pickupArea: "Medical Building",
  confirmedAt: server-timestamp
}
```

### 2. الطالب يُغلق التطبيق ثم يفتحه مرة أخرى

```
الطالب فتح التطبيق
         ↓
تسجيل الدخول (Firebase Auth)
         ↓
RequestRideScreen يبدأ
         ↓
StreamBuilder<DocumentSnapshot>
.collection('studentRequests')
.doc(currentUser.uid)
.snapshots() ← استماع مباشر من Firestore
         ↓
يقرأ الوثيقة من السيرفر:
{
  hasActiveRequest: true,
  status: "pending",
  pickupArea: "Medical Building",
  confirmedAt: "...",
  updatedAt: "..."
}
         ↓
تعرض الواجهة الطلب كما لو كان الطالب لم يُغلق التطبيق
```

### 3. الليدر يقبل/يرفض الطلب (Leader Accepts/Rejects)

```
الليدر يفتح لوحة التحكم (Dashboard)
         ↓
يرى قائمة الطلبات من: studentRequests (status: pending)
         ↓
يضغط "قبول الطلب" على طلب الطالب
         ↓
يتم استدعاء:
FirestoreDataService.updateStudentRequestStatus(
  studentUid: "student-uid-123",
  newStatus: "accepted",
  assignedBusId: "BUS-12"
)
         ↓
تحديث الوثيقة في Firestore:
{
  status: "accepted",
  acceptedAt: server-timestamp,
  assignedBusId: "BUS-12",
  updatedAt: server-timestamp
}
         ↓
RequestRideScreen يستقبل التحديث تلقائيًا عبر StreamBuilder
         ↓
تعرض الواجهة: "✅ تم قبول طلبك! الحافلة #12"
```

---

## 💻 أمثلة الكود

### 1️⃣ مثال: الطالب يطلب رحلة (Flutter)

```dart
// في RequestRideScreen - عند ضغط زر "تأكيد الطلب"
void onConfirmButtonPressed() async {
  final TransitProvider transit = context.read<TransitProvider>();
  
  // تنفيذ الطلب (يحفظ على Firestore)
  final RequestExecutionSummary summary = 
    await transit.executeImmediateRequest();
  
  // الآن الطلب محفوظ على السيرفر! ✅
  print('Request saved to server for area: ${summary.area}');
  
  // عرض رسالة نجاح
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(
      'تم حفظ طلبك! '
      'عدد الطلاب المنتظرين: ${summary.studentsWaiting}'
    ))
  );
}
```

### 2️⃣ مثال: جلب الطلب عند تسجيل الدخول (Flutter)

```dart
// في RequestRideScreen - بناء الواجهة
@override
Widget build(BuildContext context) {
  final User? currentUser = _auth.currentUser;

  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: currentUser == null
        ? null
        : _firestore
            .collection('studentRequests')
            .doc(currentUser.uid)  // ← UID محدد من Firebase Auth
            .snapshots(),           // ← استماع حي على التحديثات
    builder: (context, snapshot) {
      final Map<String, dynamic>? requestData = snapshot.data?.data();
      
      // إذا لم يكن هناك طلب
      if (!snapshot.hasData || requestData == null) {
        return Text('لا يوجد طلب نشط');
      }
      
      // الطلب موجود
      final String status = requestData['status'] ?? 'pending';
      final String area = requestData['pickupArea'] ?? '';
      
      return Column(
        children: [
          Text('حالة الطلب: $status'),
          Text('منطقة الالتقاء: $area'),
          if (status == 'accepted')
            Text('✅ تم قبول طلبك!'),
          if (status == 'rejected')
            Text('❌ تم رفض طلبك'),
          if (status == 'pending')
            Text('⏳ الطلب قيد الانتظار...'),
        ],
      );
    },
  );
}
```

### 3️⃣ مثال: الليدر يقبل الطلب

```dart
// في لوحة التحكم - عند ضغط زر "قبول الطلب"
Future<void> acceptStudentRequest({
  required String studentUid,
  required String busId,
}) async {
  final FirestoreDataService firestore = FirestoreDataService();
  
  // تحديث حالة الطلب على Firestore
  await firestore.updateStudentRequestStatus(
    studentUid: studentUid,
    newStatus: 'accepted',
    assignedBusId: busId,
  );
  
  // الطالب سيرى التحديث فوراً بدون تحديث يدوي! ✅
  print('Request accepted for student: $studentUid');
}
```

### 4️⃣ مثال: الليدر يرفض الطلب

```dart
Future<void> rejectStudentRequest({
  required String studentUid,
  required String reason,
}) async {
  final FirestoreDataService firestore = FirestoreDataService();
  
  await firestore.updateStudentRequestStatus(
    studentUid: studentUid,
    newStatus: 'rejected',
    rejectionReason: reason,
  );
  
  print('Request rejected for student: $studentUid');
}
```

---

## 🔐 قواعم الأمان (Firestore Security Rules)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // مجموعة الطلبات الطلابية
    match /studentRequests/{uid} {
      // ✅ الطالب يقرأ طلبه الخاص فقط
      allow read: if request.auth.uid == uid;
      
      // ✅ الطالب ينشئ/يحدّث طلبه الخاص فقط
      allow create, update: if request.auth.uid == uid;
      
      // ❌ الطالب لا يستطيع حذف الطلب
      allow delete: if false;
      
      // ✅ الليدر يقرأ ويعدّل كل الطلبات
      allow read, update: if request.auth != null 
        && get(/databases/$(database)/documents/users/$(request.auth.uid))
           .data.role in ['leader', 'admin'];
    }
    
    // مجموعة المناطق
    match /zones/{zoneId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null 
        && get(/databases/$(database)/documents/users/$(request.auth.uid))
           .data.role in ['leader', 'admin'];
    }
  }
}
```

---

## ✅ أفضل الممارسات لتجنب فقدان البيانات

### 1. **لا تعتمد على التخزين المحلي كمصدر الحقيقة الوحيد**
```dart
❌ غلط:
String status = _localStorage.getString('requestStatus') ?? 'pending';

✅ صحيح:
// اقرأ من Firestore مباشرة
final doc = await _firestore.collection('studentRequests').doc(uid).get();
String status = doc.data()?['status'] ?? 'pending';
```

### 2. **استخدم Streams للاستماع الحي**
```dart
✅ الطريقة الصحيحة:
StreamBuilder<DocumentSnapshot>(
  stream: _firestore
    .collection('studentRequests')
    .doc(uid)
    .snapshots(),  // ← استماع حي!
  builder: (context, snapshot) {
    // يتحدّث تلقائيًا عند تغيير البيانات
  }
)
```

### 3. **استخدم Server Timestamps**
```dart
✅ دائماً استخدم FieldValue.serverTimestamp():
await _firestore.collection('studentRequests').doc(uid).set({
  'confirmedAt': FieldValue.serverTimestamp(),  // ← السيرفر يحدد الوقت
  'updatedAt': FieldValue.serverTimestamp(),
});
```

### 4. **اجعل كل طالب وثيقة ثابتة واحدة**
```dart
✅ بدلاً من إنشاء وثائق جديدة في كل مرة:
// استخدم UID كـ document ID
studentRequests/{uid}  // ← وثيقة ثابتة واحدة فقط
```

### 5. **تحقق من الصلاحيات في Security Rules**
```dart
❌ لا تعتمد على الفحص في الكود فقط
✅ استخدم Security Rules للتحكم الصارم
```

### 6. **أضف رقم نسخة للبيانات (Version Control)**
```dart
await _firestore.collection('studentRequests').doc(uid).set({
  'version': 1,
  'status': 'pending',
  'dataVersion': DateTime.now().millisecondsSinceEpoch,
}, SetOptions(merge: true));
```

---

## 📊 مثال على دورة حياة الطلب (Request Lifecycle)

```
1. الطالب يطلب:           status = "pending"
                         confirmedAt = 2024-01-15T10:30:00Z

2. الليدر يقبل:          status = "accepted"
                         acceptedAt = 2024-01-15T10:35:00Z
                         assignedBusId = "BUS-12"

3. الحافلة تصل:          status = "arrived"
                         arrivedAt = 2024-01-15T10:40:00Z

4. الطالب يركب:          status = "boarded"
                         boardedAt = 2024-01-15T10:41:00Z

5. الرحلة انتهت:         status = "completed"
                         completedAt = 2024-01-15T11:00:00Z
```

---

## 🔄 تطبيق تحديثات Status من Firestore Console

في Firebase Console، يمكنك تحديث حالة الطلب مباشرة:

```json
// قبل:
{
  "status": "pending",
  "confirmedAt": "2024-01-15T10:30:00Z"
}

// بعد (يتم تحديثه من Dashboard):
{
  "status": "accepted",
  "confirmedAt": "2024-01-15T10:30:00Z",
  "acceptedAt": "2024-01-15T10:35:00Z",
  "assignedBusId": "BUS-12"
}
```

الطالب سيرى التحديث فوراً! ✅

---

## 🚀 الخطوات التالية

1. **نشر القواعم:**
   ```bash
   firebase deploy --only firestore:rules
   ```

2. **اختبار من Firebase Console:**
   - أنشئ وثيقة تجريبية في `studentRequests`
   - تأكد من أن الطالب يراها مباشرة

3. **مراقبة الأخطاء:**
   - استخدم Firebase Console لمراجعة السجلات
   - تحقق من Security Rules في التطبيق

---

## 📞 ملخص الحل

| المشكلة | الحل |
|--------|------|
| فقدان البيانات عند حذف التطبيق | ✅ حفظ على Firestore بدل التخزين المحلي |
| التحديثات غير الفورية | ✅ استخدام Streams للاستماع الحي |
| عدم التزامن بين الطالب والليدر | ✅ مصدر حقيقة واحد (Firestore) |
| ضعف الأمان | ✅ قواعم أمان قوية في Firestore |

---

**تم! ✅ الحل الكامل الآن جاهز للاستخدام**
