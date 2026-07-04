# DylibForge

تطبيق iOS SwiftUI لفحص ملفات `.dylib` وتعديل النصوص والروابط الموجودة داخلها بدون تغيير بنية الملف.

## الوظيفة

- استيراد ملف `.dylib` من تطبيق الملفات.
- استخراج الروابط `http/https/ftp/itms-services`.
- استخراج النصوص العربية الموجودة داخل الديلب.
- استخراج endpoints والكلمات المهمة مثل API / token / plist / install / download / server.
- عرض offset لكل عنصر بصيغة Hex.
- تعديل النص أو الرابط.
- إنشاء ملف `.dylib` جديد بعد التعديل.
- مشاركة أو حفظ الديلب الجديد من داخل التطبيق.

## شرط التعديل المهم

التعديل داخل binary لازم يكون:

- نفس طول النص الأصلي بالـ bytes، أو
- أقصر من النص الأصلي.

إذا كان النص الجديد أقصر، التطبيق يملأ الفرق تلقائياً بـ `0x00` حتى لا تتغير offsets وبنية الديلب.

> الحروف العربية UTF-8 تأخذ أكثر من byte واحد، لذلك التطبيق يحسب الحجم بالـ bytes وليس بعدد الحروف.

## المتطلبات

- iOS 16.0 أو أحدث.
- Xcode 15 أو أحدث إذا تريد تبنيه محلياً.
- المشروع يستخدم XcodeGen لتوليد ملف Xcode project من `project.yml`.

## البناء عبر GitHub Actions

1. ارفع محتويات هذا المشروع إلى GitHub.
2. افتح تبويب **Actions**.
3. شغل workflow باسم **Build IPA**.
4. بعد انتهاء البناء، حمل artifact باسم `DylibForge-unsigned-ipa`.
5. الملف الناتج يكون `DylibForge-unsigned.ipa`.

ملاحظة: الـ IPA الناتج غير موقّع. وقّعه بشهادتك أو بأداة التوقيع التي تستخدمها قبل التثبيت على iPhone.

## البناء محلياً على Mac

```bash
brew install xcodegen
xcodegen generate
open DylibForge.xcodeproj
```

بعد فتح المشروع في Xcode، اختر Team وحسابك، ثم Build/Archive.

## هيكل المشروع

```text
DylibForge/
├─ project.yml
├─ .github/workflows/build-ipa.yml
├─ DylibForge/
│  ├─ DylibForgeApp.swift
│  ├─ Core/
│  │  ├─ BinaryScanner.swift
│  │  ├─ BinaryPatcher.swift
│  │  └─ DylibFileStore.swift
│  ├─ Models/
│  │  └─ PatchItem.swift
│  ├─ ViewModels/
│  │  └─ AppViewModel.swift
│  ├─ Views/
│  │  ├─ Components.swift
│  │  ├─ ContentView.swift
│  │  └─ PatchDetailView.swift
│  └─ Resources/Assets.xcassets
└─ README.md
```

## ملاحظات استخدام

- التطبيق لا يغيّر حجم ملف الديلب عشوائياً.
- لا تستخدم نصاً أطول من الأصلي، لأن هذا قد يخرب الملف.
- التطبيق مخصص لفحص وتعديل ملفاتك أو الملفات التي تملك حق تعديلها.
