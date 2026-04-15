# 🧪 أمثلة عملية للاختبار والتطوير

## 1️⃣ مثال عملي: طلب رحلة من الطالب

### الكود في Flutter:

```dart
// في RequestRideScreen - عند ضغط زر "تأكيد الطلب"
onConfirmRequest() async {
  try {
    // الحصول على TransitProvider
    final transit = context.read<TransitProvider>();
    
    // تنفيذ الطلب (يحفظ على Firestore تلقائيًا)
    final summary = await transit.executeImmediateRequest();
    
    // عرض رسالة النجاح
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ تم حفظ طلبك!\n'
            'منطقة: ${summary.area}\n'
            'عدد المنتظرين: ${summary.studentsWaiting}\n'
            'الحافلة: ${summary.busNumber ?? "لم تُحدد بعد"}'
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  } catch (e) {
    print('Error: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ حدث خطأ: $e')),
      );
    }
  }
}
```

### ما يحدث في الخلفية:

```dart
// TransitProvider.executeImmediateRequest() يقوم بـ:

1. تحديث الحالة المحلية:
   _hasActiveStudentRequest = true
   _activeRequestArea = "Medical Building"
   _activeRequestConfirmedAtMillis = DateTime.now().millisecondsSinceEpoch

2. حفظ على Firestore:
   await _syncActiveRequestToRemoteNow()
   
   // يكتب إلى: studentRequests/{uid}
   {
     "uid": "student-123",
     "email": "student@university.edu",
     "hasActiveRequest": true,
     "activeRequestArea": "Medical Building",
     "pickupArea": "Medical Building",
     "zoneId": "zone-med-building",
     "status": "pending",
     "confirmedAt": Timestamp.now(),
     "updatedAt": Timestamp.now()
   }

3. إرجاع ملخص الطلب:
   RequestExecutionSummary(
     area: "Medical Building",
     studentsWaiting: 5,
     busNumber: "BUS-12"
   )
```

---

## 2️⃣ مثال عملي: الطالب يفتح التطبيق مرة أخرى

### الكود في Flutter:

```dart
// في RequestRideScreen - بناء الواجهة
@override
Widget build(BuildContext context) {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  
  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: currentUser == null
        ? null
        : FirebaseFirestore.instance
            .collection('studentRequests')
            .doc(currentUser.uid)  // ← UID من Firebase
            .snapshots(),           // ← استماع حي
    builder: (context, snapshot) {
      // معالجة حالات التحميل والخطأ
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      
      if (snapshot.hasError) {
        return Center(child: Text('خطأ: ${snapshot.error}'));
      }
      
      // البيانات من Firestore
      final requestData = snapshot.data?.data();
      
      // إذا لم يكن هناك طلب
      if (requestData == null || requestData.isEmpty) {
        return _buildNoRequestWidget();
      }
      
      // هناك طلب! عرضه
      return _buildActiveRequestWidget(requestData);
    },
  );
}

Widget _buildActiveRequestWidget(Map<String, dynamic> data) {
  final String status = data['status'] ?? 'unknown';
  final String area = data['pickupArea'] ?? '';
  final bool hasActiveRequest = data['hasActiveRequest'] ?? false;
  
  if (!hasActiveRequest) {
    return _buildNoRequestWidget();
  }
  
  return Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.blue[50],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.blue),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'حالة طلبك',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المنطقة: $area'),
                Text('الحالة: $status'),
              ],
            ),
            _buildStatusBadge(status),
          ],
        ),
      ],
    ),
  );
}

Widget _buildStatusBadge(String status) {
  Color badgeColor;
  String badgeText;
  
  switch (status) {
    case 'pending':
      badgeColor = Colors.orange;
      badgeText = '⏳ قيد الانتظار';
      break;
    case 'accepted':
      badgeColor = Colors.green;
      badgeText = '✅ تم القبول';
      break;
    case 'rejected':
      badgeColor = Colors.red;
      badgeText = '❌ تم الرفض';
      break;
    case 'cancelled':
      badgeColor = Colors.grey;
      badgeText = '❌ ملغى';
      break;
    default:
      badgeColor = Colors.blue;
      badgeText = status;
  }
  
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: badgeColor,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      badgeText,
      style: TextStyle(color: Colors.white),
    ),
  );
}
```

### النتيجة:
✅ **الطالب يرى طلبه حتى بعد إغلاق التطبيق!**

---

## 3️⃣ مثال عملي: الليدر يقبل/يرفض الطلب

### الكود في الدashboard (JavaScript/TypeScript):

```javascript
// في لوحة التحكم - زر قبول الطلب
async function acceptRequest(studentUid, busId) {
  try {
    // تحديث الوثيقة مباشرة في Firestore
    await firebase.firestore()
      .collection('studentRequests')
      .doc(studentUid)
      .update({
        'status': 'accepted',
        'acceptedAt': firebase.firestore.FieldValue.serverTimestamp(),
        'assignedBusId': busId,
        'updatedAt': firebase.firestore.FieldValue.serverTimestamp(),
      });
    
    console.log('✅ تم قبول الطلب');
  } catch (error) {
    console.error('Error:', error);
  }
}

// زر رفض الطلب
async function rejectRequest(studentUid, reason) {
  try {
    await firebase.firestore()
      .collection('studentRequests')
      .doc(studentUid)
      .update({
        'status': 'rejected',
        'rejectedAt': firebase.firestore.FieldValue.serverTimestamp(),
        'rejectionReason': reason,
        'updatedAt': firebase.firestore.FieldValue.serverTimestamp(),
      });
    
    console.log('❌ تم رفض الطلب');
  } catch (error) {
    console.error('Error:', error);
  }
}
```

### الكود في Flutter:

```dart
// في المستودع - استخدام FirestoreDataService
Future<void> acceptRequest(String studentUid, String busId) async {
  final firestore = FirestoreDataService();
  
  await firestore.updateStudentRequestStatus(
    studentUid: studentUid,
    newStatus: 'accepted',
    assignedBusId: busId,
  );
}

Future<void> rejectRequest(String studentUid, String reason) async {
  final firestore = FirestoreDataService();
  
  await firestore.updateStudentRequestStatus(
    studentUid: studentUid,
    newStatus: 'rejected',
    rejectionReason: reason,
  );
}
```

### النتيجة:
✅ **الطالب يرى التحديث فوراً بدون تحديث يدوي!**

---

## 4️⃣ مثال عملي: الاستماع لتحديثات الطلب

### الكود في Flutter:

```dart
// الاستماع على جميع الطلبات في منطقة معينة
void listenToZoneRequests(String zoneId) {
  final firestore = FirestoreDataService();
  
  firestore.getPendingStudentRequestsByZone(zoneId).listen(
    (QuerySnapshot snapshot) {
      print('📨 عدد الطلبات: ${snapshot.docs.length}');
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final studentName = data['name'] ?? 'Unknown';
        final status = data['status'] ?? 'pending';
        final area = data['pickupArea'] ?? '';
        
        print('- $studentName (${area}) - $status');
      }
    },
    onError: (error) => print('❌ Error: $error'),
  );
}

// الاستماع على طلب طالب معين
void listenToStudentRequest(String studentUid) {
  final firestore = FirestoreDataService();
  
  firestore.getStudentActiveRequestStream(studentUid).listen(
    (DocumentSnapshot doc) {
      if (!doc.exists) {
        print('❌ الطلب غير موجود');
        return;
      }
      
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'];
      
      print('✅ حالة الطلب الحالية: $status');
      
      // يمكنك هنا تحديث الواجهة تلقائياً
      if (status == 'accepted') {
        print('🎉 تم قبول الطلب!');
      } else if (status == 'rejected') {
        print('😞 تم رفض الطلب');
      }
    },
    onError: (error) => print('❌ Error: $error'),
  );
}
```

---

## 5️⃣ مثال عملي: اختبار في Firebase Console

### الخطوات:

1. **افتح Firebase Console**
   - انتقل إلى: https://console.firebase.google.com/

2. **اختر مشروع wayfinder**

3. **انتقل إلى Firestore Database**

4. **أنشئ وثيقة تجريبية:**
   ```
   Collection: studentRequests
   Document ID: student-test-123
   
   Fields:
   - uid: "student-test-123"
   - email: "test@university.edu"
   - name: "أحمد التجريب"
   - status: "pending"
   - hasActiveRequest: true
   - pickupArea: "Medical Building"
   - confirmedAt: "2024-01-15T10:30:00Z"
   - updatedAt: "2024-01-15T10:30:00Z"
   ```

5. **غيّر الحالة إلى accepted:**
   ```
   - status: "accepted"
   - acceptedAt: "2024-01-15T10:35:00Z"
   - assignedBusId: "BUS-12"
   ```

6. **لاحظ التحديث فوراً في التطبيق!** ✅

---

## 6️⃣ مثال عملي: التحقق من القواعم

### اختبر القواعم في Firebase Console:

```javascript
// Rules Playground

// ✅ يجب أن ينجح: الطالب يقرأ طلبه
db.collection('studentRequests')
  .doc('student-123')
  .get()
  
// ✅ يجب أن ينجح: الطالب يحدّث طلبه
db.collection('studentRequests')
  .doc('student-123')
  .update({
    'status': 'cancelled'
  })

// ❌ يجب أن يفشل: الطالب يقرأ طلب آخر
db.collection('studentRequests')
  .doc('other-student')
  .get()

// ❌ يجب أن يفشل: الطالب يحذف الطلب
db.collection('studentRequests')
  .doc('student-123')
  .delete()
```

---

## 7️⃣ مثال عملي: اختبار التطبيق

### سيناريو اختبار شامل:

```
1. اختبر الإنشاء:
   ✅ الطالب يطلب رحلة
   ✅ البيانات تُحفظ على Firestore
   ✅ يظهر في لوحة التحكم

2. اختبر الاستمرارية:
   ✅ الطالب يغلق التطبيق
   ✅ الطالب يفتح التطبيق
   ✅ الطلب محفوظ ويظهر مباشرة

3. اختبر التحديث الحي:
   ✅ الليدر يقبل الطلب من Dashboard
   ✅ الطالب يرى التحديث فوراً (بدون تحديث يدوي)

4. اختبر الأمان:
   ✅ طالب لا يستطيع قراءة طلبات الآخرين
   ✅ طالب لا يستطيع حذف الطلب
   ✅ ليدر يستطيع تحديث جميع الطلبات
```

---

## 8️⃣ مثال عملي: رسائل الأخطاء الشائعة وحلولها

### الخطأ 1: "Permission denied"
```
السبب: القاعم رفضت الوصول
الحل: تحقق من:
  - أن المستخدم مسجل دخول
  - أن UID صحيح
  - أن القاعم مُنشرة بشكل صحيح
```

### الخطأ 2: "Document does not exist"
```
السبب: الوثيقة لا توجد على Firestore
الحل:
  - اعمل StreamBuilder يفحص وجود البيانات
  - أنشئ وثيقة فارغة عند تسجيل الدخول
```

### الخطأ 3: "Offline"
```
السبب: لا توجد اتصال بالإنترنت
الحل:
  - استخدم offline persistence
  - أظهر رسالة "جارٍ حفظ البيانات..."
```

---

## 🧪 أداة اختبار سريعة

```dart
// في main.dart أو app.dart - للاختبار السريع
void testFirestoreConnection() async {
  try {
    final firestore = FirebaseFirestore.instance;
    
    // اختبر الاتصال
    await firestore.collection('_test').doc('connection').set({
      'timestamp': FieldValue.serverTimestamp(),
    });
    
    print('✅ Firestore متصل بنجاح');
    
    // احذف الوثيقة التجريبية
    await firestore.collection('_test').doc('connection').delete();
  } catch (e) {
    print('❌ خطأ في الاتصال: $e');
  }
}
```

---

**الآن أنت جاهز للاختبار والتطوير! 🚀**
