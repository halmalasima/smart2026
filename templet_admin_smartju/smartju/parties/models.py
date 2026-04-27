from django.db import models
from lawsuits.models import Lawsuit


class Plaintiff(models.Model):
    """
    Plaintiff Model - represents the plaintiff (المدعي) in a lawsuit
    """
    
    # Gender choices
    GENDER_MALE = 'male'
    GENDER_FEMALE = 'female'
    
    GENDER_CHOICES = [
        (GENDER_MALE, 'ذكر'),
        (GENDER_FEMALE, 'أنثى'),
    ]
    
    # ForeignKey to Lawsuit
    lawsuit = models.ForeignKey(
        Lawsuit,
        on_delete=models.CASCADE,
        related_name='plaintiffs',
        verbose_name='الدعوى'
    )
    
    # Name
    name = models.CharField(
        max_length=200,
        verbose_name='الاسم'
    )
    
    # Gender
    gender = models.CharField(
        max_length=10,
        choices=GENDER_CHOICES,
        verbose_name='الجنس'
    )
    
    # Nationality
    nationality = models.CharField(
        max_length=100,
        verbose_name='الجنسية'
    )
    
    # Occupation
    occupation = models.CharField(
        max_length=200,
        blank=True,
        null=True,
        verbose_name='المهنة'
    )
    
    # Address
    address = models.TextField(
        verbose_name='العنوان'
    )
    
    # Phone
    phone = models.CharField(
        max_length=20,
        blank=True,
        null=True,
        verbose_name='الهاتف'
    )
    
    # Attorney/Agent (optional)
    attorney_name = models.CharField(
        max_length=200,
        blank=True,
        null=True,
        verbose_name='اسم الوكيل'
    )
    
    attorney_phone = models.CharField(
        max_length=20,
        blank=True,
        null=True,
        verbose_name='هاتف الوكيل'
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
        verbose_name = 'مدعي'
        verbose_name_plural = 'مدعون'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['lawsuit']),
            models.Index(fields=['name']),
        ]
    
    def __str__(self):
        return f'{self.name} - {self.lawsuit.case_number}'


class Defendant(models.Model):
    """
    Defendant Model - represents the defendant (المدعى عليه) in a lawsuit
    """
    
    # Gender choices
    GENDER_MALE = 'male'
    GENDER_FEMALE = 'female'
    
    GENDER_CHOICES = [
        (GENDER_MALE, 'ذكر'),
        (GENDER_FEMALE, 'أنثى'),
    ]
    
    # ForeignKey to Lawsuit
    lawsuit = models.ForeignKey(
        Lawsuit,
        on_delete=models.CASCADE,
        related_name='defendants',
        verbose_name='الدعوى'
    )
    
    # Name
    name = models.CharField(
        max_length=200,
        verbose_name='الاسم'
    )
    
    # Gender
    gender = models.CharField(
        max_length=10,
        choices=GENDER_CHOICES,
        verbose_name='الجنس'
    )
    
    # Nationality
    nationality = models.CharField(
        max_length=100,
        verbose_name='الجنسية'
    )
    
    # Occupation
    occupation = models.CharField(
        max_length=200,
        blank=True,
        null=True,
        verbose_name='المهنة'
    )
    
    # Address
    address = models.TextField(
        verbose_name='العنوان'
    )
    
    # Phone
    phone = models.CharField(
        max_length=20,
        blank=True,
        null=True,
        verbose_name='الهاتف'
    )
    
    # Attorney/Agent (optional)
    attorney_name = models.CharField(
        max_length=200,
        blank=True,
        null=True,
        verbose_name='اسم الوكيل'
    )
    
    attorney_phone = models.CharField(
        max_length=20,
        blank=True,
        null=True,
        verbose_name='هاتف الوكيل'
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
        verbose_name = 'مدعى عليه'
        verbose_name_plural = 'مدعى عليهم'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['lawsuit']),
            models.Index(fields=['name']),
        ]
    
    def __str__(self):
        return f'{self.name} - {self.lawsuit.case_number}'
