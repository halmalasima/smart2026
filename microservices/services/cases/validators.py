"""Local file validators for cases-service."""
from django.core.exceptions import ValidationError

MAX_FILE_SIZE = 20 * 1024 * 1024

ALLOWED_EXTENSIONS = [
    'pdf', 'doc', 'docx', 'xls', 'xlsx',
    'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp',
    'txt', 'rtf', 'odt', 'ods', 'zip', 'rar',
]
BLOCKED_EXTENSIONS = [
    'exe', 'bat', 'cmd', 'sh', 'ps1', 'vbs', 'js',
    'msi', 'dll', 'com', 'scr', 'pif', 'hta',
    'cpl', 'msc', 'inf', 'reg', 'rgs',
    'php', 'py', 'rb', 'pl', 'cgi',
]


def validate_file_size(value):
    if value.size > MAX_FILE_SIZE:
        raise ValidationError(f'حجم الملف كبير جداً. الحد الأقصى: {MAX_FILE_SIZE // (1024*1024)} MB.')


def validate_file_extension(value):
    import os
    ext = os.path.splitext(value.name)[1].lower().lstrip('.')
    if ext in BLOCKED_EXTENSIONS:
        raise ValidationError(f'نوع الملف (.{ext}) غير مسموح به.')
    if ext and ext not in ALLOWED_EXTENSIONS:
        raise ValidationError(f'نوع الملف (.{ext}) غير مدعوم.')
