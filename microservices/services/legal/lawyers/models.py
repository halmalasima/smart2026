from django.db import models
from django.contrib.auth.models import User


class Lawyer(models.Model):
    """
    Lawyer Model - represents lawyers/attorneys
    """
    
    # Link to User account (optional - for registered lawyers)
    user = models.OneToOneField(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        verbose_name='حساب المستخدم',
        related_name='lawyer_profile'
    )
    
    # Registration/ID number
    registration_number = models.CharField(
        max_length=50,
        unique=True,
        verbose_name='رقم القيد'
    )
    
    # Full name
    name = models.CharField(
        max_length=200,
        verbose_name='الاسم'
    )
    
    # Grade (عليا, وسطى, أولى, etc.)
    grade = models.CharField(
        max_length=50,
        verbose_name='الدرجة'
    )
    
    # Branch/Office
    branch = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        verbose_name='الفرع'
    )
    
    # Phone number
    phone = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        verbose_name='رقم الهاتف'
    )
    
    # Governorate
    governorate = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        verbose_name='المحافظة'
    )
    
    # Directorate
    directorate = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        verbose_name='المديرية'
    )
    
    # Neighborhood/District
    neighborhood = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        verbose_name='الحي'
    )
    
    # Address details
    address_details = models.TextField(
        blank=True,
        null=True,
        verbose_name='تفاصيل العنوان'
    )
    
    # Office type
    office_type = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        verbose_name='نوع المكتب'
    )
    
    # Notes
    notes = models.TextField(
        blank=True,
        null=True,
        verbose_name='ملاحظة'
    )
    
    # Timestamps
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='تاريخ الإنشاء'
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name='تاريخ التحديث'
    )
    
    class Meta:
        verbose_name = 'محامي'
        verbose_name_plural = 'المحامين'
        ordering = ['registration_number']
        indexes = [
            models.Index(fields=['name']),
            models.Index(fields=['governorate']),
            models.Index(fields=['grade']),
        ]

    def __str__(self):
        return f"{self.name} - {self.registration_number}"


class LawyerFilterOptions(models.Model):
    """Model to store filter options (branches and grades) permanently"""
    option_type = models.CharField(
        max_length=50,
        verbose_name='نوع الفلتر'
    )  # 'branch' or 'grade'
    option_value = models.CharField(
        max_length=100,
        verbose_name='قيمة الفلتر'
    )
    display_name = models.CharField(
        max_length=100,
        verbose_name='الاسم المعروض'
    )
    is_active = models.BooleanField(
        default=True,
        verbose_name='نشط'
    )
    sort_order = models.IntegerField(
        default=0,
        verbose_name='ترتيب'
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
        verbose_name = 'خيار فلتر المحامين'
        verbose_name_plural = 'خيارات فلتر المحامين'
        ordering = ['option_type', 'sort_order', 'display_name']
        unique_together = ['option_type', 'option_value']

    def __str__(self):
        return f"{self.option_type}: {self.display_name}"
