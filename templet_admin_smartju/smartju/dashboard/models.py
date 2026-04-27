from django.db import models
from django.contrib.auth.models import User

class SubscriptionPlan(models.Model):
    name = models.CharField(max_length=100, verbose_name='اسم الباقة')
    price = models.DecimalField(max_digits=10, decimal_places=2, verbose_name='السعر')
    duration_days = models.PositiveIntegerField(default=30, verbose_name='المدة بالايام')
    features = models.JSONField(default=dict, verbose_name='المميزات')
    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name = 'باقة اشتراك'
        verbose_name_plural = 'باقات الاشتراكات'

    def __str__(self):
        return f"{self.name} - {self.price}"

class UserSubscription(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='subscription')
    plan = models.ForeignKey(SubscriptionPlan, on_delete=models.SET_NULL, null=True)
    start_date = models.DateTimeField(auto_now_add=True)
    end_date = models.DateTimeField()
    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name = 'اشتراك مستخدم'
        verbose_name_plural = 'اشتراكات المستخدمين'

    def __str__(self):
        return f"{self.user.username} - {self.plan.name}"
