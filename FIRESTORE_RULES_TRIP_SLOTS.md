# Firestore Trip Slots Permissions Fix

تمت إضافة الملفات التالية للمشروع:
- firebase.json
- firestore.rules
- firestore.indexes.json

## المطلوب الآن (مرة واحدة)

1. تثبيت Firebase CLI:

```powershell
npm install -g firebase-tools
```

2. تسجيل الدخول:

```powershell
firebase login
```

3. داخل مسار المشروع، نفّذ نشر القواعد والفهارس:

```powershell
firebase deploy --only firestore:rules,firestore:indexes
```

## لماذا ظهر الخطأ؟

الخطأ `Missing or insufficient permissions` يعني أن قواعد Firestore الحالية تمنع الكتابة على `tripSlots`.

القواعد الجديدة تسمح:
- القائد (موجود في `authorized_users/{uid}` و`active != false`) بإنشاء/تعديل/حذف `tripSlots`.
- الطالب بقراءة `tripSlots` وحجز `preBookings` الخاص به.

## ملاحظة مهمة

تأكد أن حساب القائد موجود كوثيقة في:

`authorized_users/<LEADER_UID>`

وبداخلها:

```json
{
  "active": true,
  "email": "leader@example.com"
}
```
