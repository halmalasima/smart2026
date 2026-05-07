from django.db import models


class Governorate(models.Model):
    """
    Governorate Model - المحافظات
    """
    name = models.CharField(
        max_length=150,
        unique=True,
        verbose_name='اسم المحافظة'
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
        verbose_name = 'محافظة'
        verbose_name_plural = 'محافظات'
        ordering = ['name']
        indexes = [
            models.Index(fields=['name']),
        ]
    
    def __str__(self):
        return self.name


class District(models.Model):
    """
    District Model - الأحياء/المناطق
    """
    governorate = models.ForeignKey(
        Governorate,
        on_delete=models.CASCADE,
        related_name='districts',
        verbose_name='المحافظة'
    )
    
    name = models.CharField(
        max_length=150,
        verbose_name='اسم الحي/المنطقة'
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
        verbose_name = 'حي/منطقة'
        verbose_name_plural = 'أحياء/مناطق'
        ordering = ['governorate', 'name']
        indexes = [
            models.Index(fields=['governorate']),
            models.Index(fields=['name']),
        ]
        unique_together = [['governorate', 'name']]
    
    def __str__(self):
        return f'{self.governorate.name} - {self.name}'


class CourtType(models.Model):
    """
    Court Type Model - أنواع المحاكم
    """
    JUDICIAL_LEVEL_PRIMARY = 'primary'
    JUDICIAL_LEVEL_APPEAL = 'appeal'
    JUDICIAL_LEVEL_CASSATION = 'cassation'
    JUDICIAL_LEVEL_CONSTITUTIONAL = 'constitutional'
    JUDICIAL_LEVEL_OTHER = 'other'
    
    JUDICIAL_LEVEL_CHOICES = [
        (JUDICIAL_LEVEL_PRIMARY, 'ابتدائي'),
        (JUDICIAL_LEVEL_APPEAL, 'استئناف'),
        (JUDICIAL_LEVEL_CASSATION, 'تمييز'),
        (JUDICIAL_LEVEL_CONSTITUTIONAL, 'دستوري'),
        (JUDICIAL_LEVEL_OTHER, 'أخرى'),
    ]
    
    name = models.CharField(
        max_length=150,
        verbose_name='نوع المحكمة'
    )
    
    judicial_level = models.CharField(
        max_length=50,
        choices=JUDICIAL_LEVEL_CHOICES,
        default=JUDICIAL_LEVEL_PRIMARY,
        verbose_name='المستوى القضائي'
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
        verbose_name = 'نوع محكمة'
        verbose_name_plural = 'أنواع المحاكم'
        ordering = ['judicial_level', 'name']
        indexes = [
            models.Index(fields=['judicial_level']),
            models.Index(fields=['name']),
        ]
    
    def __str__(self):
        return f'{self.get_judicial_level_display()} - {self.name}'


class CourtSpecialization(models.Model):
    """
    Court Specialization Model - تخصصات المحاكم
    """
    name = models.CharField(
        max_length=150,
        unique=True,
        verbose_name='اسم التخصص'
    )
    
    description = models.TextField(
        blank=True,
        null=True,
        verbose_name='الوصف'
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
        verbose_name = 'تخصص محكمة'
        verbose_name_plural = 'تخصصات المحاكم'
        ordering = ['name']
        indexes = [
            models.Index(fields=['name']),
        ]
    
    def __str__(self):
        return self.name


class Court(models.Model):
    """
    Court Model - المحاكم
    """
    name = models.CharField(
        max_length=200,
        verbose_name='اسم المحكمة'
    )
    
    court_type = models.ForeignKey(
        CourtType,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='courts',
        verbose_name='نوع المحكمة'
    )
    
    governorate = models.ForeignKey(
        Governorate,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='courts',
        verbose_name='المحافظة'
    )
    
    district = models.ForeignKey(
        District,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='courts',
        verbose_name='الحي/المنطقة'
    )
    
    address = models.TextField(
        blank=True,
        null=True,
        verbose_name='العنوان'
    )
    
    location_url = models.URLField(
        blank=True,
        null=True,
        max_length=500,
        verbose_name='رابط الموقع'
    )
    
    latitude = models.DecimalField(
        max_digits=10,
        decimal_places=7,
        blank=True,
        null=True,
        verbose_name='خط العرض'
    )
    
    longitude = models.DecimalField(
        max_digits=10,
        decimal_places=7,
        blank=True,
        null=True,
        verbose_name='خط الطول'
    )
    
    is_active = models.BooleanField(
        default=True,
        verbose_name='نشط'
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='تاريخ الإنشاء'
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name='تاريخ التحديث'
    )
    
    # Many-to-Many relationship with specializations
    specializations = models.ManyToManyField(
        CourtSpecialization,
        related_name='courts',
        blank=True,
        verbose_name='التخصصات'
    )
    
    class Meta:
        verbose_name = 'محكمة'
        verbose_name_plural = 'محاكم'
        ordering = ['governorate', 'name']
        indexes = [
            models.Index(fields=['court_type']),
            models.Index(fields=['governorate']),
            models.Index(fields=['district']),
            models.Index(fields=['is_active']),
        ]
    
    def __str__(self):
        location = f' - {self.governorate.name}' if self.governorate else ''
        return f'{self.name}{location}'

