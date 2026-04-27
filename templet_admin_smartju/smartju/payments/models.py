from django.db import models
from lawsuits.models import Lawsuit


class PaymentOrder(models.Model):
    """
    Payment Order Model - أوامر الدفع
    """
    lawsuit = models.ForeignKey(
        Lawsuit,
        on_delete=models.CASCADE,
        related_name='payment_orders',
        verbose_name='الدعوى'
    )
    
    amount = models.DecimalField(
        max_digits=18,
        decimal_places=2,
        verbose_name='المبلغ'
    )
    
    order_date = models.DateField(
        verbose_name='تاريخ الأمر'
    )
    
    # Order number (optional)
    order_number = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        unique=True,
        db_index=True,
        verbose_name='رقم الأمر'
    )
    
    # Description/notes
    description = models.TextField(
        blank=True,
        null=True,
        verbose_name='الوصف'
    )
    
    # Payment status
    STATUS_PENDING = 'pending'
    STATUS_PAID = 'paid'
    STATUS_PARTIAL = 'partial'
    STATUS_CANCELLED = 'cancelled'
    
    STATUS_CHOICES = [
        (STATUS_PENDING, 'قيد الانتظار'),
        (STATUS_PAID, 'مدفوع'),
        (STATUS_PARTIAL, 'مدفوع جزئياً'),
        (STATUS_CANCELLED, 'ملغي'),
    ]
    
    status = models.CharField(
        max_length=50,
        choices=STATUS_CHOICES,
        default=STATUS_PENDING,
        verbose_name='حالة الدفع'
    )
    
    # Paid amount (if partial payment)
    paid_amount = models.DecimalField(
        max_digits=18,
        decimal_places=2,
        default=0,
        verbose_name='المبلغ المدفوع'
    )
    
    # Payment date (if paid)
    payment_date = models.DateField(
        blank=True,
        null=True,
        verbose_name='تاريخ الدفع'
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
        verbose_name = 'أمر دفع'
        verbose_name_plural = 'أوامر الدفع'
        ordering = ['-order_date', '-created_at']
        indexes = [
            models.Index(fields=['lawsuit']),
            models.Index(fields=['order_date']),
            models.Index(fields=['status']),
            models.Index(fields=['order_number']),
        ]
    
    def __str__(self):
        return f'أمر دفع - {self.lawsuit.case_number} - {self.amount}'
    
    @property
    def remaining_amount(self):
        """Calculate remaining amount to be paid"""
        return self.amount - self.paid_amount

