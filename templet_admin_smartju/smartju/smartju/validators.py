"""
Shared file upload validators for the SmartJudi project.
"""
from django.core.exceptions import ValidationError


# 20 MB max file size
MAX_FILE_SIZE = 20 * 1024 * 1024

ALLOWED_EXTENSIONS = [
    'pdf', 'doc', 'docx', 'xls', 'xlsx',
    'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp',
    'txt', 'rtf', 'odt', 'ods',
    'zip', 'rar',
]

BLOCKED_EXTENSIONS = [
    'exe', 'bat', 'cmd', 'sh', 'ps1', 'vbs', 'js',
    'msi', 'dll', 'com', 'scr', 'pif', 'hta',
    'cpl', 'msc', 'inf', 'reg', 'rgs',
    'php', 'py', 'rb', 'pl', 'cgi',
]


def validate_file_size(value):
    """Reject files larger than MAX_FILE_SIZE."""
    if value.size > MAX_FILE_SIZE:
        size_mb = MAX_FILE_SIZE // (1024 * 1024)
        raise ValidationError(
            f'حجم الملف كبير جداً. الحد الأقصى المسموح: {size_mb} ميغابايت.'
        )


def validate_file_extension(value):
    """Reject files with dangerous extensions."""
    import os
    ext = os.path.splitext(value.name)[1].lower().lstrip('.')
    if ext in BLOCKED_EXTENSIONS:
        raise ValidationError(
            f'نوع الملف (.{ext}) غير مسموح به لأسباب أمنية.'
        )
    if ext and ext not in ALLOWED_EXTENSIONS:
        raise ValidationError(
            f'نوع الملف (.{ext}) غير مدعوم. الأنواع المسموحة: {", ".join(ALLOWED_EXTENSIONS)}'
        )
