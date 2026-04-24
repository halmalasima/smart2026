# Generated migration for OTPCode model

from django.db import migrations, models
import django.utils.timezone


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0005_userprofile_subscription_fields'),
    ]

    operations = [
        migrations.CreateModel(
            name='OTPCode',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('code', models.CharField(max_length=6, verbose_name='رمز التحقق')),
                ('purpose', models.CharField(max_length=20, choices=[('verify_email', 'تفعيل البريد الإلكتروني'), ('reset_password', 'استعادة كلمة المرور')])),
                ('is_used', models.BooleanField(default=False)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('expires_at', models.DateTimeField()),
                ('user', models.ForeignKey(on_delete=models.deletion.CASCADE, related_name='otp_codes', to='auth.user')),
            ],
            options={
                'verbose_name': 'رمز تحقق',
                'verbose_name_plural': 'رموز التحقق',
                'ordering': ['-created_at'],
            },
        ),
    ]
