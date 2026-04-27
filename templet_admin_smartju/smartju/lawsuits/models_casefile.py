"""
Case File Item Model - عنصر ملف القضية
يمثل أي مستند أو عنصر مرتبط بملف القضية
"""
from django.db import models
from django.contrib.auth.models import User
from .models import Lawsuit
from smartju.validators import validate_file_size, validate_file_extension


class CaseFileItem(models.Model):
    """
    CaseFileItem - يربط أي نوع مستند أو عنصر بملف القضية الرئيسي
    هذا الجدول يعمل كفهرس مركزي لجميع محتويات ملف القضية
    """
    
    # أنواع العناصر
    TYPE_DOCUMENT = 'document'       # مستند عادي (صور، PDF، إلخ)
    TYPE_LAWSUIT = 'lawsuit'         # دعوى فرعية
    TYPE_APPEAL = 'appeal'           # طعن
    TYPE_PAYMENT_ORDER = 'payment_order'  # أمر أداء
    TYPE_JUDGMENT = 'judgment'       # حكم
    TYPE_HEARING_RECORD = 'hearing_record'  # محضر جلسة
    TYPE_RESPONSE = 'response'       # مذكرة / رد
    TYPE_CONTRACT = 'contract'       # عقد
    TYPE_EVIDENCE = 'evidence'       # دليل
    TYPE_OTHER = 'other'             # أخرى
    
    ITEM_TYPE_CHOICES = [
        (TYPE_DOCUMENT, 'مستند'),
        (TYPE_LAWSUIT, 'دعوى'),
        (TYPE_APPEAL, 'طعن'),
        (TYPE_PAYMENT_ORDER, 'أمر أداء'),
        (TYPE_JUDGMENT, 'حكم'),
        (TYPE_HEARING_RECORD, 'محضر جلسة'),
        (TYPE_RESPONSE, 'مذكرة / رد'),
        (TYPE_CONTRACT, 'عقد'),
        (TYPE_EVIDENCE, 'دليل'),
        (TYPE_OTHER, 'أخرى'),
    ]
    
    # القضية الأم
    lawsuit = models.ForeignKey(
        Lawsuit,
        on_delete=models.CASCADE,
        related_name='case_file_items',
        verbose_name='القضية'
    )
    
    # نوع العنصر
    item_type = models.CharField(
        max_length=30,
        choices=ITEM_TYPE_CHOICES,
        default=TYPE_DOCUMENT,
        verbose_name='نوع العنصر'
    )
    
    # اسم العنصر (يظهر في قائمة الملفات)
    title = models.CharField(
        max_length=255,
        verbose_name='عنوان العنصر'
    )
    
    # وصف اختياري
    description = models.TextField(
        blank=True,
        default='',
        verbose_name='الوصف'
    )
    
    # الملف المرفق (اختياري - قد يكون العنصر مجرد إشارة لكيان آخر)
    file = models.FileField(
        upload_to='case_files/lawsuit_%s/' % 'id',
        blank=True,
        null=True,
        verbose_name='الملف',
        validators=[validate_file_size, validate_file_extension],
    )
    
    # اسم الملف الأصلي
    original_filename = models.CharField(
        max_length=255,
        blank=True,
        default='',
        verbose_name='اسم الملف الأصلي'
    )
    
    # حجم الملف
    file_size = models.PositiveIntegerField(
        blank=True,
        null=True,
        verbose_name='حجم الملف'
    )
    
    # معرف الكيان المرتبط (attachment_id, appeal_id, etc.)
    related_object_id = models.PositiveIntegerField(
        blank=True,
        null=True,
        verbose_name='معرف الكيان المرتبط'
    )
    
    # نوع الكيان المرتبط (للربط العام مع أي جدول)
    related_object_type = models.CharField(
        max_length=50,
        blank=True,
        default='',
        verbose_name='نوع الكيان المرتبط'
    )
    
    # من أضاف هذا العنصر
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='created_case_file_items',
        verbose_name='أنشأ بواسطة'
    )
    
    # ترتيب العرض
    sort_order = models.PositiveIntegerField(
        default=0,
        verbose_name='ترتيب العرض'
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='تاريخ الإنشاء'
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name='تاريخ التحديث'
    )
    
    class Meta:
        verbose_name = 'عنصر ملف القضية'
        verbose_name_plural = 'عناصر ملف القضية'
        ordering = ['sort_order', '-created_at']
        indexes = [
            models.Index(fields=['lawsuit']),
            models.Index(fields=['item_type']),
            models.Index(fields=['related_object_id', 'related_object_type']),
            models.Index(fields=['created_at']),
        ]
    
    def __str__(self):
        return f'{self.get_item_type_display()} - {self.title}'
    
    def save(self, *args, **kwargs):
        """حفظ معلومات الملف تلقائياً"""
        if self.file:
            import os
            if hasattr(self.file, 'name') and not self.original_filename:
                self.original_filename = os.path.basename(self.file.name)
            try:
                if hasattr(self.file, 'size'):
                    self.file_size = self.file.size
            except (ValueError, AttributeError, OSError):
                pass
        super().save(*args, **kwargs)
    
    def get_file_size_display(self):
        """حجم الملف بصيغة مقروءة"""
        if not self.file_size:
            return '-'
        size = float(self.file_size)
        for unit in ['B', 'KB', 'MB', 'GB']:
            if size < 1024.0:
                return f'{size:.1f} {unit}'
            size /= 1024.0
        return f'{size:.1f} TB'


def case_file_upload_path(instance, filename):
    """Generate upload path for case file items"""
    import os
    from django.utils import timezone
    ext = filename.split('.')[-1]
    timestamp = timezone.now().strftime('%Y%m%d_%H%M%S')
    safe_name = f"{timestamp}_{instance.item_type}.{ext}"
    return os.path.join('case_files', f'lawsuit_{instance.lawsuit_id}', safe_name)
