# كربيتو البلحوسي

تطبيق Flutter لإدخال إشارات الفيوتشرز مع تحقق من مستويات LONG/SHORT، وحاسبة
للمخاطر وحجم المركز، وتأكيد الفريمات الفنية وقراءات IQRAA Sniper وIQRAA Flow
Engine.

## الإعداد والتشغيل

يتطلب Flutter SDK وAndroid SDK. بعد تثبيتهما شغّل من مجلد المشروع:

```powershell
flutter create --platforms=android .
flutter pub get
flutter run
```

الحزمة Android هي `com.karbitu.albalhousi.admin_app` واسم العرض
`كربيتو البلحوسي`.

## نشر الإشارات

يرسل زر النشر طلب `POST` بصيغة JSON إلى
`http://freehosting.dev/backend/create_signal.php`. الحقول الأساسية المرسلة
هي `symbol`, `direction`, `entry_price`, `target_1`, `target_2`, `target_3`,
`stop_loss`, `leverage`, و`risk_percent`، مع بيانات حاسبة المخاطر والتأكيدات
الفنية وقراءات السيولة والزخم.

الاتصال الحالي يستخدم HTTP غير مشفر حسب عنوان الخادم المقدم، والسماح به على
Android مقيد بنطاق `freehosting.dev`. استخدم HTTPS على الخادم قبل نقل بيانات
حساسة أو تشغيل التطبيق على نطاق أوسع.
