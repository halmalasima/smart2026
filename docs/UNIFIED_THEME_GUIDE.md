# SmartJudi Unified Theme Guide
# دليل الثيم الموحد

## نظرة عامة | Overview

تم توحيد نظام التصميم بين Flutter و Django لضمان تناسق تجربة المستخدم عبر جميع منصات التطبيق.

---

## 🎨 نظام الألوان الموحد | Unified Color System

### Brand Identity | هوية العلامة

| اللون | Flutter | Django/CSS |
|-------|---------|------------|
| **Brand Primary** | `AppColors.brand` | `--sj-brand: #1B5E3B` |
| **Brand Light** | `AppColors.brandLight` | `--sj-brand-light: #2D8B57` |
| **Brand Dark** | `AppColors.brandDark` | `--sj-brand-dark: #0D3B23` |
| **Gold** | `AppColors.gold` | `--sj-gold: #D4A940` |
| **Gold Light** | `AppColors.goldLight` | `--sj-gold-light: #E8C667` |
| **Gold Dark** | `AppColors.goldDark` | `--sj-gold-dark: #B08C2A` |

### Light Mode | الوضع الفاتح

| العنصر | Flutter | Django/CSS |
|--------|---------|------------|
| Background | `AppColors.lightBackground` | `--sj-light-bg: #F7F8FA` |
| Surface | `AppColors.lightSurface` | `--sj-light-surface: #FFFFFF` |
| Card | `AppColors.lightCard` | `--sj-light-card: #FFFFFF` |
| Text Primary | `AppColors.lightTextPrimary` | `--sj-light-text-primary: #1A2138` |
| Text Secondary | `AppColors.lightTextSecondary` | `--sj-light-text-secondary: #5A6478` |
| Border | `AppColors.lightBorder` | `--sj-light-border: #DDE1E8` |

### Dark Mode | الوضع الداكن

| العنصر | Flutter | Django/CSS |
|--------|---------|------------|
| Background | `AppColors.darkBackground` | `--sj-dark-bg: #0F1117` |
| Surface | `AppColors.darkSurface` | `--sj-dark-surface: #1A1D27` |
| Card | `AppColors.darkCard` | `--sj-dark-card: #1E2130` |
| Text Primary | `AppColors.darkTextPrimary` | `--sj-dark-text-primary: #F0F1F5` |
| Text Secondary | `AppColors.darkTextSecondary` | `--sj-dark-text-secondary: #B0B6C5` |
| Border | `AppColors.darkBorder` | `--sj-dark-border: #2D3245` |

### Semantic Colors | الألوان الدلالية

| الحالة | Flutter | Django/CSS |
|--------|---------|------------|
| Success | `AppColors.success` | `--sj-success: #22C55E` |
| Warning | `AppColors.warning` | `--sj-warning: #F59E0B` |
| Error | `AppColors.error` | `--sj-error: #EF4444` |
| Info | `AppColors.info` | `--sj-info: #3B82F6` |

---

## 📁 ملفات الثيم | Theme Files

### Flutter
```
lib/theme/
├── app_colors.dart      # تعريفات الألوان
├── app_theme.dart       # ThemeData للثيم الفاتح والداكن
└── app_spacing.dart     # نظام التباعد
```

### Django
```
smartju/static/
├── css/
│   └── smartjudi-theme.css    # CSS Variables & Utilities
└── js/
    └── theme-config.js        # Tailwind Config
```

---

## 🔧 استخدام الثيم | Usage

### Flutter Usage

```dart
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'theme/app_spacing.dart';

// استخدام الألوان
Container(
  color: AppColors.brand,
  child: Text('Hello', style: TextStyle(color: AppColors.gold)),
)

// استخدام التباعد
Padding(padding: EdgeInsets.all(AppSpacing.md))

// استخدام الثيم من السياق
Theme.of(context).colorScheme.primary
```

### Django Usage

```html
{% load static %}
<!DOCTYPE html>
<html>
<head>
    <link rel="stylesheet" href="{% static 'css/smartjudi-theme.css' %}">
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="{% static 'js/theme-config.js' %}"></script>
    <script>
        tailwind.config = smartjudiTheme;
    </script>
</head>
<body class="bg-background text-foreground">
    <!-- استخدام ألوان Tailwind -->
    <button class="bg-brand text-white">
        زر الماركة
    </button>
    
    <!-- استخدام CSS Variables -->
    <div style="color: var(--sj-gold);">
        نص ذهبي
    </div>
</body>
</html>
```

---

## 🎯 Tailwind Classes | فئات Tailwind

| الفئة | الوصف |
|-------|-------|
| `bg-brand` | خلفية الماركة الخضراء |
| `bg-gold` | خلفية ذهبية |
| `text-brand` | نص أخضر |
| `text-gold` | نص ذهبي |
| `border-brand` | حدود خضراء |
| `shadow-sj-gold` | ظل ذهبي متوهج |

---

## 🌙 Dark Mode | الوضع الداكن

### Flutter
```dart
MaterialApp(
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: ThemeMode.system, // or ThemeMode.dark
)
```

### Django
```html
<html class="dark">
<!-- أو -->
<html data-theme="dark">
```

---

## 📝 ملاحظات هامة | Important Notes

1. **لا تستخدم ألواناً ثابتة** - استخدم دائماً الثيم الموحد
2. **تجنب التكرار** - لا تُعِّرف ألواناً جديدة في الملفات الفردية
3. **التوثيق** - عند إضافة لون جديد، أضفه في جميع الملفات (Flutter + Django)

---

## ✅ قائمة التحقق | Checklist

- [ ] جميع الشاشات تستخدم `AppColors`
- [ ] قوالب Django تستخدم `smartjudi-theme.css`
- [ ] لا توجد ألوان مُعرفة مباشرة (Hardcoded)
- [ ] الثيم الفاتح والداكن متوافقان
