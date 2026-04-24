# smartjudiflutter - نظام الخدمات القضائية الذكية

نظام متكامل للخدمات القضائية اليمنية يجمع بين تطبيقات Flutter و Django backend.

## فهرس المحتويات

### 🚀 البداية
- [البدء السريع](docs/QUICK_START.md)
- [إعداد Flutter](docs/FLUTTER_SETUP.md)

### 🤖 الذكاء الاصطناعي
- [إعداد مساعد AI](docs/SETUP_AI_ASSISTANT.md)
- [إعداد Groq/OpenRouter](docs/GROQ_SETUP.md)

### ☁️ النشر
- [نشر Flutter Web على Render](docs/DEPLOY_FLUTTER_WEB_RENDER.md)
- [دليل Render السريع](docs/RENDER_QUICK_START.md)
- [نشر مجاني على Render](docs/RENDER_FREE_PLAN_GUIDE.md)

### 📱 تطبيقات الهاتف
- [دليل بناء iOS](docs/IOS_BUILD_GUIDE.md)
- [بناء iOS للاختبار](docs/BUILD_IOS_FOR_TESTING.md)
- [حلول مشاكل iOS](docs/SOLUTION_IOS_BUILD.md)

### 🖥️ الخادم
- [إعداد خادم Django](docs/DJANGO_SERVER_INSTRUCTIONS.md)
- [إعداد قاعدة البيانات](docs/RENDER_DATABASE_SETUP.md)
- [إنشاء مستخدم مدير](docs/RENDER_CREATE_SUPERUSER.md)

### 📚 الوثائق
- [ملخص تكامل API](docs/API_INTEGRATION_SUMMARY.md)
- [ملخص شاشات Flutter](docs/FLUTTER_SCREENS_SUMMARY.md)
- [حل مشاكل الاتصال](docs/CONNECTION_TROUBLESHOOTING.md)
- [حل مشاكل تسجيل الدخول](docs/TROUBLESHOOTING_LOGIN.md)

---

## المتطلبات

- Flutter 3.x
- Python 3.8+
- Django 4.x
- PostgreSQL

## التثبيت

```bash
# استنساخ المشروع
git clone https://github.com/halmalasima/smart2026.git
cd smart2026

# إعداد Python
python -m venv venv
source venv/bin/activate  # Linux/Mac
venv\Scripts\activate     # Windows
pip install -r requirements.txt

# تشغيل الخادم
python manage.py runserver
```

## المساهمة

مرحباً بالمساهمات! يرجى قراءة [خطوات المساهمة](docs/NEXT_STEPS.md).
